// This modules does a simple vertex clipping test and does perspective divide
// The clipping test sets invalid = 1 if not
//      0 < ndc.z < ndc.w
// If clipping failes, invalid will be 1

`timescale 1ns / 1ps

typedef enum logic [2:0] {
    VPP_IDLE,
    VPP_CLIP,
    VPP_PERSPECTIVE_DIVIDE,
    VPP_SCREEN_SPACE_TRANSFORM,
    VPP_ERROR_STATE
} vertex_post_processor_state_t;

module vertex_post_processor #(
        parameter unsigned IV_DATAWIDTH = 24,
        parameter unsigned IV_FRACBITS = 13,

        parameter unsigned OV_DATAWIDTH = 12,

        logic signed [IV_DATAWIDTH-1:0] WIDTH = 320,
        logic signed [IV_DATAWIDTH-1:0] HEIGHT = 320,

        parameter real ZFAR = 100.0,
        parameter real ZNEAR = 0.1
    ) (
        input logic clk,
        input logic rstn,
        output logic ready,

        input logic signed [IV_DATAWIDTH-1:0] i_vertex[4],
        input logic i_vertex_dv,

        output logic signed [OV_DATAWIDTH-1:0] o_vertex_pixel[3],
        output logic done,
        output logic invalid
    );

    localparam logic signed [IV_DATAWIDTH-1:0] FP_One = (1 << IV_FRACBITS);
    localparam logic signed [IV_DATAWIDTH-1:0] WIDTH_FP = (WIDTH << IV_FRACBITS);
    localparam logic signed [IV_DATAWIDTH-1:0] HEIGHT_FP = (HEIGHT << IV_FRACBITS);
    localparam logic signed [2 * IV_DATAWIDTH:0] WIDTH_FP_D = WIDTH_FP * FP_One;
    localparam logic signed [2 * IV_DATAWIDTH:0] HEIGHT_FP_D = HEIGHT_FP * FP_One;

    localparam unsigned OutPixIndStart = 2 * IV_FRACBITS;
    localparam unsigned OutPixIndEnd = OV_DATAWIDTH + 2 * IV_FRACBITS - 2;

    // State
    vertex_post_processor_state_t current_state = VPP_IDLE, next_state = VPP_IDLE;

    // Register input vertex data
    logic signed [IV_DATAWIDTH-1:0] r_clip_x;
    logic signed [IV_DATAWIDTH-1:0] r_clip_y;
    logic signed [IV_DATAWIDTH-1:0] r_clip_z;
    logic signed [IV_DATAWIDTH-1:0] r_clip_w;

    // NDC Data
    /* verilator lint_off UNUSED */         // Some bits are not used
    logic signed [IV_DATAWIDTH-1:0] w_ndc_x;
    logic signed [IV_DATAWIDTH-1:0] w_ndc_y;
    logic signed [IV_DATAWIDTH-1:0] w_ndc_z;
    /* verilator lint_on UNUSED */          // Some bits are not used

    // Screen-Space Data
    logic signed [2 * IV_DATAWIDTH:0] w_ss_x_inter;
    logic signed [2 * IV_DATAWIDTH:0] w_ss_y_inter;

    // CLIP-NDC Signals
    logic w_ndc_x_valid, w_ndc_y_valid, w_ndc_z_valid;
    logic w_ndc_x_busy, w_ndc_z_busy, w_ndc_y_busy;
    logic w_ndc_x_done, w_ndc_y_done, w_ndc_z_done;

    /* verilator lint_off UNUSED */         // May be used later
    logic w_ndc_x_dbz, w_ndc_y_dbz, w_ndc_z_dbz;
    logic w_ndc_x_ovf, w_ndc_y_ovf, w_ndc_z_ovf;
    /* verilator lint_off UNUSED */         // May be used later

    // Start signal for perspective divide
    logic ndc_divide_start;
    always_comb begin
        ndc_divide_start = (current_state == VPP_PERSPECTIVE_DIVIDE)
                           && ~(w_ndc_x_busy || w_ndc_x_done)
                           && ~(w_ndc_y_busy || w_ndc_y_done)
                           && ~(w_ndc_z_busy || w_ndc_z_done);
    end

    // Check z clipping
    logic z_invalid;
    always_comb begin
        z_invalid = ((r_clip_z <= 0) || (r_clip_w <= r_clip_z)) & (current_state == VPP_CLIP);
    end

    // NDC-Screen Transform
    always_comb begin
        w_ss_x_inter = w_ndc_x * WIDTH_FP + WIDTH_FP_D;
        w_ss_y_inter = HEIGHT_FP_D - w_ndc_y * HEIGHT_FP;
    end

    // Clip to ndc dividers
    fixed_point_divide #(
        .WIDTH(IV_DATAWIDTH),
        .FRACBITS(IV_FRACBITS)
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
        .WIDTH(IV_DATAWIDTH),
        .FRACBITS(IV_FRACBITS)
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
        .WIDTH(IV_DATAWIDTH),
        .FRACBITS(IV_FRACBITS)
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

    // Register input data
    always_ff @(posedge clk) begin
        if (~rstn) begin
            r_clip_x <= '0;
            r_clip_y <= '0;
            r_clip_z <= '0;
            r_clip_w <= '0;

        end else begin
            if (i_vertex_dv) begin
                r_clip_x <= i_vertex[0];
                r_clip_y <= i_vertex[1];
                r_clip_z <= i_vertex[2];
                r_clip_w <= i_vertex[3];
            end
        end
    end

    // Set output data and signals
    always_ff @(posedge clk) begin
        if (~rstn) begin
            foreach (o_vertex_pixel[i]) o_vertex_pixel[i] <= '0;
            o_vertex_z <= '0;
            done <= '0;
            invalid <= '0;
        end else begin
            case (current_state)
                VPP_SCREEN_SPACE_TRANSFORM: begin
                    o_vertex_pixel[0] <= {w_ss_x_inter[2 * IV_DATAWIDTH - 1], w_ss_x_inter[OutPixIndEnd + 1:OutPixIndStart + 1]};
                    o_vertex_pixel[1] <= {w_ss_y_inter[2 * IV_DATAWIDTH - 1], w_ss_y_inter[OutPixIndEnd+1:OutPixIndStart+1]};
                    o_vertex_pixel[2] <= w_ndc_z[IV_FRACBITS-1:IV_FRACBITS-O_DEPTH_FRACBITS];
                    done <= '1;
                end

                VPP_ERROR_STATE: begin
                    done <= '1;
                    invalid <= '1;
                end

                default: begin
                    done <= '0;
                    invalid <= '0;
                end
            endcase
        end
    end

    // State logic
    always_ff @(posedge clk) begin
        if (~rstn) begin
            current_state <= VPP_IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    always_comb begin
        next_state = current_state;
        ready = 0;

        case (current_state)
            VPP_IDLE: begin
                if (i_vertex_dv) begin
                    next_state = VPP_CLIP;
                end else begin
                    ready = 1;
                end
            end

            VPP_CLIP: begin
                if (z_invalid) begin
                    next_state = VPP_ERROR_STATE;
                end else begin
                    next_state = VPP_PERSPECTIVE_DIVIDE;
                end
            end

            VPP_PERSPECTIVE_DIVIDE: begin
                if (w_ndc_x_done && w_ndc_y_done && w_ndc_z_done) begin
                    if (!w_ndc_x_valid || !w_ndc_y_valid || !w_ndc_z_valid) begin
                        next_state = VPP_ERROR_STATE;
                    end else begin
                        next_state = VPP_SCREEN_SPACE_TRANSFORM;
                    end
                end
            end

            VPP_SCREEN_SPACE_TRANSFORM: begin
                next_state = VPP_IDLE;
            end

            VPP_ERROR_STATE: begin
                next_state = VPP_IDLE;
            end

            default:
                next_state = VPP_IDLE;
        endcase
    end
endmodule
