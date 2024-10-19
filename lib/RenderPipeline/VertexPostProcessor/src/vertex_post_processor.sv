// This modules does a simple vertex clipping test and does perspective divide
// The clipping test sets invalid = 1 if not
//      0 < ndc.z < ndc.w
// If clipping failes, invalid will be 1

`timescale 1ns / 1ps

typedef enum logic [2:0] {
    VPP_IDLE,
    VPP_CLIP,
    VPP_PERSPECTIVE_DIVIDE,
    VPP_DONE,
    VPP_ERROR_STATE
} vertex_post_processor_state_t;

module vertex_post_processor #(
        parameter unsigned DATAWIDTH = 24,
        parameter unsigned FRACBITS = 13
    ) (
        input logic clk,
        input logic rstn,
        output logic ready,

        input logic signed [DATAWIDTH-1:0] i_vertex[4],
        input logic i_vertex_dv,

        output logic signed [DATAWIDTH-1:0] o_vertex[3],
        output logic done,
        output logic invalid
    );

    // State
    vertex_post_processor_state_t current_state = VPP_IDLE, next_state = VPP_IDLE;

    // Register input vertex data
    logic signed [DATAWIDTH-1:0] r_clip_x;
    logic signed [DATAWIDTH-1:0] r_clip_y;
    logic signed [DATAWIDTH-1:0] r_clip_z;
    logic signed [DATAWIDTH-1:0] r_clip_w;

    // CLIP-NDC Signals
    logic signed [DATAWIDTH-1:0] w_ndc_x;
    logic signed [DATAWIDTH-1:0] w_ndc_y;
    logic signed [DATAWIDTH-1:0] w_ndc_z;

    logic w_ndc_x_valid, w_ndc_y_valid, w_ndc_z_valid;
    logic w_ndc_x_busy, w_ndc_z_busy, w_ndc_y_busy;
    logic w_ndc_x_done, w_ndc_y_done, w_ndc_z_done;
    logic w_ndc_x_dbz, w_ndc_y_dbz, w_ndc_z_dbz;
    logic w_ndc_x_ovf, w_ndc_y_ovf, w_ndc_z_ovf;

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
        z_invalid = (0 < r_clip_z) || (r_clip_z < r_clip_w);
    end

    // Clip to ndc dividers
    fixed_point_divide #(
        .WIDTH(DATAWIDTH),
        .FRACBITS(FRACBITS)
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
        .WIDTH(DATAWIDTH),
        .FRACBITS(FRACBITS)
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
        .WIDTH(DATAWIDTH),
        .FRACBITS(FRACBITS)
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
            foreach (o_vertex[i]) o_vertex[i] <= '0;
        end else begin
            case (current_state)
                VPP_DONE: begin
                    o_vertex[0] <= w_ndc_x;
                    o_vertex[1] <= w_ndc_y;
                    o_vertex[2] <= w_ndc_z;
                    done <= '1;
                end

                VPP_ERROR_STATE: begin
                    done <= '1;
                end

                default: begin
                    done <= '0;
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
        invalid = 0;
        ready = 1;

        case (current_state)
            VPP_IDLE: begin
                if (i_vertex_dv) begin
                    next_state = VPP_CLIP;
                    ready = 0;
                end
            end

            VPP_CLIP: begin
                if (z_invalid) begin
                    next_state = VPP_ERROR_STATE;
                end else begin
                    next_state = VPP_PERSPECTIVE_DIVIDE;
                end
                ready = 0;
            end

            VPP_PERSPECTIVE_DIVIDE: begin
                if (w_ndc_x_valid & w_ndc_y_valid & w_ndc_z_valid) begin
                    next_state = VPP_ERROR_STATE;
                end else if (w_ndc_x_done && w_ndc_y_done && w_ndc_z_done) begin
                    next_state = VPP_DONE;
                end

                ready = 0;
            end

            VPP_DONE: begin
                next_state = VPP_IDLE;
            end

            VPP_ERROR_STATE: begin
                invalid = 1;
                ready = 0;
            end

            default:
                next_state = VPP_IDLE;
        endcase
    end
endmodule
