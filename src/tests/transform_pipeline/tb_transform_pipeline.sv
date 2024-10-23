`timescale 1ns / 1ps

module tb_transform_pipeline #(
    parameter unsigned INPUT_VERTEX_DATAWIDTH = 24,
    parameter unsigned INPUT_VERTEX_FRACBITS = 13,
    parameter unsigned OUTPUT_VERTEX_DATAWIDTH = 12,
    parameter unsigned OUTPUT_DEPTH_FRACBITS = 12,

    parameter unsigned SCREEN_WIDTH = 320,
    parameter unsigned SCREEN_HEIGHT = 320,

    parameter real ZFAR = 100.0,
    parameter real ZNEAR = 0.1
    ) (
    input logic clk,
    input logic rstn,

    input logic signed [INPUT_VERTEX_DATAWIDTH-1:0] i_mvp_matrix[4][4],
    input logic i_mvp_dv,

    input logic signed [INPUT_VERTEX_DATAWIDTH-1:0] i_vertex[3],
    input logic i_vertex_dv,
    input logic i_vertex_last,

    output logic signed [INPUT_VERTEX_DATAWIDTH-1:0] o_vs_vertex[4],
    output logic o_vs_vertex_dv,

    output logic signed [OUTPUT_VERTEX_DATAWIDTH-1:0] o_vertex_pixel[2],
    output logic signed [OUTPUT_DEPTH_FRACBITS-1:0] o_vertex_z,
    output logic o_vertex_dv,

    output logic finished,
    output logic vpp_error,

    output logic ready
    );

    // Vertex Shader
    /* verilator lint_off UNUSED */
    logic w_vs_ready;
    logic w_vs_finished;
    /* verilator lint_on UNUSED */
    logic r_vs_enable;

    logic signed [INPUT_VERTEX_DATAWIDTH-1:0] w_vs_o_vertex[4];
    logic w_vs_o_vertex_dv;

    vertex_shader #(
        .DATAWIDTH(INPUT_VERTEX_DATAWIDTH),
        .FRACBITS(INPUT_VERTEX_FRACBITS)
    ) vertex_shader_inst (
        .clk(clk),
        .rstn(rstn),

        .o_ready(w_vs_ready),
        .o_finished(w_vs_finished),
        .i_enable(r_vs_enable),

        .i_mvp_mat(i_mvp_matrix),
        .i_mvp_dv(i_mvp_dv),

        .i_vertex(i_vertex),
        .i_vertex_dv(i_vertex_dv),
        .i_vertex_last(i_vertex_last),

        .o_vertex(w_vs_o_vertex),
        .o_vertex_dv(w_vs_o_vertex_dv)
    );

    // Vertex Post-Processor
    logic signed [INPUT_VERTEX_DATAWIDTH-1:0] r_vpp_i_vertex[4];
    logic r_vpp_i_vertex_dv;

    logic signed [OUTPUT_VERTEX_DATAWIDTH-1:0] w_vertex_pixel[2];
    logic signed [OUTPUT_DEPTH_FRACBITS-1:0] w_vertex_z;
    logic w_vpp_done;

    logic w_vpp_o_vertex_invalid;
    logic w_vpp_ready;

    logic r_vpp_last_vertex = '0;

    vertex_post_processor #(
        .IV_DATAWIDTH(INPUT_VERTEX_DATAWIDTH),
        .IV_FRACBITS(INPUT_VERTEX_FRACBITS),
        .OV_DATAWIDTH(OUTPUT_VERTEX_DATAWIDTH),
        .O_DEPTH_FRACBITS(OUTPUT_DEPTH_FRACBITS),

        .WIDTH(SCREEN_WIDTH),
        .HEIGHT(SCREEN_HEIGHT),
        .ZFAR(ZFAR),
        .ZNEAR(ZNEAR)
    ) vertex_post_processor_inst (
        .clk(clk),
        .rstn(rstn),

        .ready(w_vpp_ready),

        .i_vertex(r_vpp_i_vertex),
        .i_vertex_dv(r_vpp_i_vertex_dv),

        .o_vertex_pixel(w_vertex_pixel),
        .o_vertex_z(w_vertex_z),

        .invalid(w_vpp_o_vertex_invalid),
        .done(w_vpp_done)
    );

    // Assign Vertex Post-Proccessor output to output
    always_ff @(posedge clk) begin
        if (~rstn) begin
            foreach (r_vpp_i_vertex[i]) r_vpp_i_vertex[i] <= '0;
            r_vpp_i_vertex_dv <= '0;
            r_vpp_last_vertex <= '0;

            o_vertex_pixel[0] <= '0;
            o_vertex_pixel[1] <= '0;
            o_vertex_z <= '0;
            o_vertex_dv <= '0;

            vpp_error <= 0;
        end else begin
            if (w_vs_o_vertex_dv) begin
                foreach (r_vpp_i_vertex[i]) r_vpp_i_vertex[i] <= w_vs_o_vertex[i];
                r_vpp_i_vertex_dv <= '1;

                r_vpp_last_vertex <= w_vs_finished;
            end else begin
                r_vpp_i_vertex_dv <= '0;
                // r_vpp_last_vertex <= '0;
            end

            if (w_vpp_done) begin
                if (!w_vpp_o_vertex_invalid) begin
                    o_vertex_pixel[0] <= w_vertex_pixel[0];
                    o_vertex_pixel[1] <= w_vertex_pixel[1];
                    o_vertex_z <= w_vertex_z;

                    vpp_error <= 0;
                end else begin
                    vpp_error <= 1;
                end
                o_vertex_dv <= 1;

                if (r_vpp_last_vertex) begin
                    finished <= '1;
                end else begin
                    finished <= '0;
                end
            end else begin
                o_vertex_dv <= 0;
                vpp_error <= 0;
                finished <= '0;
            end
        end
    end

    assign r_vs_enable = w_vpp_ready;
    assign ready = w_vs_ready;

    // Debug
    assign o_vs_vertex[0] = r_vpp_i_vertex[0];
    assign o_vs_vertex[1] = r_vpp_i_vertex[1];
    assign o_vs_vertex[2] = r_vpp_i_vertex[2];
    assign o_vs_vertex[3] = r_vpp_i_vertex[3];
    assign o_vs_vertex_dv = r_vpp_i_vertex_dv;

endmodule
