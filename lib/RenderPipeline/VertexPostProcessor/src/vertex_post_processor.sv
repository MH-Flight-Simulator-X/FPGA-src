// This module takes in clip space vertices and transforms them first to
// normalized device coordinates (ndc), and then to screen space where it will
// later be processed by the rasterizer and turned into pixels on the scrren.
//
// The output format of the vertices will be two integers screen.x and
// screen.y, as well as a fixed-point z-value in the format Q1.OUTPUT_DEPTH_FRACBITS. This
// means that the z-value will be in the range [-1:1].
//
// clip space to ndc is as follows:
//      ndc.x = clip.x / clip.w
//      ndc.y = clip.y / clip.w
//      ndc.z = clip.z / clip.w
//
// ndc to screen space transform is as follows:
//      screen.x = SCREEN_WDITH * (1 + ndc.x) / 2
//      screen.y = SCREEN_HEIGHT * (1 - ndc.y) / 2
//      screen.z = ndc.z


`timescale 1ns / 1ps

typedef enum logic [1:0] {
    VPP_IDLE,
    VPP_PERSPECTIVE_DIVIDE,
    VPP_SCREEN_SPACE_TRANSFORM,
    VPP_ERROR_STATE
} vertex_post_processor_state_t;

/* verilator lint_off UNUSED */
module vertex_post_processor #(
        parameter unsigned INPUT_VERTEX_DATAWIDTH = 24,     // Data width of the incomming data
        parameter unsigned INPUT_VERTEX_FRACBITS = 13,      // Num of fractional bits for incomming data

        parameter unsigned OUTPUT_VERTEX_DATAWIDTH = 12,    // Data width of outgoing pixel coordinates
        parameter unsigned OUTPUT_DEPTH_FRACBITS = 11,      // Num of fracbits used for outgoing z-value
                                                            //  - Format will be Q1.OUTPUT_DEPTH_FRACBITS

        parameter logic signed [INPUT_VERTEX_DATAWIDTH-1:0] SCREEN_WIDTH = 320,
        parameter logic signed [INPUT_VERTEX_DATAWIDTH-1:0] SCREEN_HEIGHT = 320,

        parameter real ZFAR = 100.0,
        parameter real ZNEAR = 0.1
    ) (
        input logic clk,
        input logic rstn,

        input logic signed [INPUT_VERTEX_DATAWIDTH-1:0] i_vertex[4],         // Vertex after vertex shader
        input logic i_vertex_dv,

        output logic signed [OUTPUT_VERTEX_DATAWIDTH-1:0] o_vertex_pixel[2],  // Output pixel coordinates of vertex
        output logic signed [OUTPUT_DEPTH_FRACBITS:0] o_vertex_z,               // Z-value of the output pixel [-1:1]
        output logic o_vertex_dv,
        output logic o_invalid,                                   // If outside clip-space

        output logic ready
    );

    localparam signed [INPUT_VERTEX_DATAWIDTH-1:0] FPOne = (1 <<< INPUT_VERTEX_FRACBITS);
    localparam signed [INPUT_VERTEX_DATAWIDTH-1:0] WidthFP = (SCREEN_WIDTH << INPUT_VERTEX_FRACBITS);
    localparam signed [INPUT_VERTEX_DATAWIDTH-1:0] HeightFP = (SCREEN_HEIGHT << INPUT_VERTEX_FRACBITS);

    localparam unsigned OutPixIndStart = 2 * INPUT_VERTEX_FRACBITS;
    localparam unsigned OutPixIndEnd = OUTPUT_VERTEX_DATAWIDTH + 2 * INPUT_VERTEX_FRACBITS - 2;

    // State
    vertex_post_processor_state_t current_state = VPP_IDLE, next_state = VPP_IDLE;

    // Register input vertex data
    logic signed [INPUT_VERTEX_DATAWIDTH-1:0] r_clip_x;
    logic signed [INPUT_VERTEX_DATAWIDTH-1:0] r_clip_y;
    logic signed [INPUT_VERTEX_DATAWIDTH-1:0] r_clip_z;
    logic signed [INPUT_VERTEX_DATAWIDTH-1:0] r_clip_w;

    // CLIP-NDC Signals
    logic signed [INPUT_VERTEX_DATAWIDTH-1:0] w_ndc_x;
    logic signed [INPUT_VERTEX_DATAWIDTH-1:0] w_ndc_y;
    logic signed [INPUT_VERTEX_DATAWIDTH-1:0] w_ndc_z;

    logic w_ndc_x_valid;
    logic w_ndc_x_busy;
    logic w_ndc_x_done;

    logic w_ndc_y_valid;
    logic w_ndc_y_busy;
    logic w_ndc_y_done;

    logic w_ndc_z_valid;
    logic w_ndc_z_busy;
    logic w_ndc_z_done;

    logic w_ndc_x_dbz;
    logic w_ndc_x_ovf;

    logic w_ndc_y_dbz;
    logic w_ndc_y_ovf;

    logic w_ndc_z_dbz;
    logic w_ndc_z_ovf;

    logic ndc_divide_start;

    // NDC-SCREEN Signals
    logic signed [2 * INPUT_VERTEX_DATAWIDTH:0] w_screen_x_inter;
    logic signed [2 * INPUT_VERTEX_DATAWIDTH:0] w_screen_y_inter;

    // Start signal for perspective divide
    always_comb begin
        ndc_divide_start = (current_state == VPP_PERSPECTIVE_DIVIDE)
                           && ~(w_ndc_x_busy || w_ndc_x_done)
                           && ~(w_ndc_y_busy || w_ndc_y_done)
                           && ~(w_ndc_z_busy || w_ndc_z_done);
    end

    // Clip to ndc dividers
    fixed_point_divide #(
        .WIDTH(INPUT_VERTEX_DATAWIDTH),
        .FRACBITS(INPUT_VERTEX_FRACBITS)
    ) ndc_divide_x_inst (
        .clk(clk),
        .rstn(rstn),

        .start(ndc_divide_start),
        .busy(w_ndc_x_busy),
        .done(w_ndc_x_done),
        .valid(w_ndc_x_valid),

        .dbz(w_ndc_x_dbz),
        .ovf(w_ndc_x_ovf),

        .A(r_clip_x),
        .B(r_clip_w),

        .Q(w_ndc_x)
    );

    fixed_point_divide #(
        .WIDTH(INPUT_VERTEX_DATAWIDTH),
        .FRACBITS(INPUT_VERTEX_FRACBITS)
    ) ndc_divide_y_inst (
        .clk(clk),
        .rstn(rstn),

        .start(ndc_divide_start),
        .busy(w_ndc_y_busy),
        .done(w_ndc_y_done),
        .valid(w_ndc_y_valid),

        .dbz(w_ndc_y_dbz),
        .ovf(w_ndc_y_ovf),

        .A(r_clip_y),
        .B(r_clip_w),

        .Q(w_ndc_y)
    );

    fixed_point_divide #(
        .WIDTH(INPUT_VERTEX_DATAWIDTH),
        .FRACBITS(INPUT_VERTEX_FRACBITS)
    ) ndc_divide_z_inst (
        .clk(clk),
        .rstn(rstn),

        .start(ndc_divide_start),
        .busy(w_ndc_z_busy),
        .done(w_ndc_z_done),
        .valid(w_ndc_z_valid),

        .dbz(w_ndc_z_dbz),
        .ovf(w_ndc_z_ovf),

        .A(r_clip_z),
        .B(r_clip_w),

        .Q(w_ndc_z)
    );

    // NDC-SCREEN
    always_comb begin
        w_screen_x_inter = w_ndc_x * WidthFP + FPOne * WidthFP;
        w_screen_y_inter = (FPOne * HeightFP) - (w_ndc_y * HeightFP);
    end

    // State logic
    always_ff @(posedge clk) begin
        if (~rstn) begin
            current_state <= VPP_IDLE;

            r_clip_x <= '0;
            r_clip_y <= '0;
            r_clip_z <= '0;
            r_clip_w <= '0;

            o_vertex_pixel[0] <= '0;
            o_vertex_pixel[1] <= '0;
            o_vertex_z <= '0;
            o_vertex_dv <= 0;
        end else begin
            current_state <= next_state;

            if (i_vertex_dv) begin
                r_clip_x <= i_vertex[0];
                r_clip_y <= i_vertex[1];
                r_clip_z <= i_vertex[2];
                r_clip_w <= i_vertex[3];
            end

            if (current_state == VPP_SCREEN_SPACE_TRANSFORM) begin
                // o_vertex_pixel.x = w_screen_x_inter / 2
                // o_vertex_pixel.y = w_screen_y_inter / 2
                // o_vertex_z = w_ndc_z -- but with different OUTPUT_DEPTH_FRACBITS fracbits

                o_vertex_pixel[0] <= {w_screen_x_inter[2 * INPUT_VERTEX_DATAWIDTH - 1],
                                      w_screen_x_inter[OutPixIndEnd + 1:OutPixIndStart + 1]};

                o_vertex_pixel[1] <= {w_screen_y_inter[2 * INPUT_VERTEX_DATAWIDTH - 1],
                                      w_screen_y_inter[OutPixIndEnd+1:OutPixIndStart+1]};
                o_vertex_z <= {w_ndc_z[INPUT_VERTEX_DATAWIDTH-1], w_ndc_z[INPUT_VERTEX_FRACBITS-1:INPUT_VERTEX_FRACBITS-OUTPUT_DEPTH_FRACBITS]};
                o_vertex_dv <= 1;
            end else begin
                o_vertex_dv <= 0;
            end
        end
    end

    always_comb begin
        next_state = current_state;

        // Control signals
        ready = 1;
        o_invalid = 0;

        case (current_state)
            VPP_IDLE: begin
                if (i_vertex_dv) begin
                    next_state = VPP_PERSPECTIVE_DIVIDE;
                    ready = 0;
                end
            end

            VPP_PERSPECTIVE_DIVIDE: begin
                if (w_ndc_x_done && w_ndc_y_done && w_ndc_z_done) begin
                    if (w_ndc_x_valid & w_ndc_y_valid & w_ndc_z_valid) begin
                        next_state = VPP_SCREEN_SPACE_TRANSFORM;
                    end else begin
                        // Something went wrong in the division, i.e. dbz or ovf
                        next_state = VPP_ERROR_STATE;
                    end
                end

                ready = 0;
            end

            VPP_SCREEN_SPACE_TRANSFORM: begin
                ready = 0;
                next_state = VPP_IDLE;
            end

            VPP_ERROR_STATE: begin
                o_invalid = 1;
                ready = 0;
            end

            default:
                next_state = VPP_IDLE;
        endcase
    end
endmodule
/* verilator lint_on UNUSED */
