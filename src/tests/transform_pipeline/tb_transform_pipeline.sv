`timescale 1ns / 1ps

module tb_transform_pipeline #(
    parameter unsigned INPUT_VERTEX_DATAWIDTH = 24,
    parameter unsigned INPUT_VERTEX_FRACBITS = 13,
    parameter unsigned OUTPUT_VERTEX_DATAWIDTH = 10,
    parameter unsigned OUTPUT_DEPTH_FRACBITS = 11,

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

    output logic signed [INPUT_VERTEX_DATAWIDTH-1:0] o_vertex_vs[4],
    output logic o_vertex_vs_dv,

    output logic signed [OUTPUT_VERTEX_DATAWIDTH-1:0] o_vertex_pixel[2],
    output logic signed [OUTPUT_DEPTH_FRACBITS:0] o_vertex_z,
    output logic o_vertex_dv,

    output logic vpp_error,

    output logic ready
    );

    // Vertex Shader
    logic w_vs_ready;
    /* verilator lint_off UNUSED */
    logic w_vs_finished;
    /* verilator lint_on UNUSED */

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
    logic signed [OUTPUT_DEPTH_FRACBITS:0] w_vertex_z;
    logic w_vpp_o_vertex_dv;

    logic w_vpp_o_vertex_invalid;
    logic w_vpp_ready;

    vertex_post_processor #(
        .INPUT_VERTEX_DATAWIDTH(INPUT_VERTEX_DATAWIDTH),
        .INPUT_VERTEX_FRACBITS(INPUT_VERTEX_FRACBITS),
        .OUTPUT_VERTEX_DATAWIDTH(OUTPUT_VERTEX_DATAWIDTH),
        .OUTPUT_DEPTH_FRACBITS(OUTPUT_DEPTH_FRACBITS),

        .SCREEN_WIDTH(SCREEN_WIDTH),
        .SCREEN_HEIGHT(SCREEN_HEIGHT),
        .ZFAR(ZFAR),
        .ZNEAR(ZNEAR)
    ) vertex_post_processor_inst (
        .clk(clk),
        .rstn(rstn),

        .i_vertex(r_vpp_i_vertex),
        .i_vertex_dv(r_vpp_i_vertex_dv),

        .o_vertex_pixel(w_vertex_pixel),
        .o_vertex_z(w_vertex_z),
        .o_vertex_dv(w_vpp_o_vertex_dv),
        .o_invalid(w_vpp_o_vertex_invalid),

        .ready(w_vpp_ready)
    );

    // Assign Vertex Post-Proccessor output to output
    always_ff @(posedge clk) begin
        if (~rstn) begin
            o_vertex_pixel[0] <= '0;
            o_vertex_pixel[1] <= '0;
            o_vertex_z <= '0;
            o_vertex_dv <= '0;

            vpp_error <= 0;
        end else begin
            if (w_vpp_o_vertex_dv) begin
                if (!w_vpp_o_vertex_invalid) begin
                    o_vertex_pixel[0] <= w_vertex_pixel[0];
                    o_vertex_pixel[1] <= w_vertex_pixel[1];
                    o_vertex_z <= w_vertex_z;
                    o_vertex_dv <= 1;

                    vpp_error <= 0;
                end else begin
                    vpp_error <= 1;
                end
            end else begin
                o_vertex_dv <= 0;
                vpp_error <= 0;
            end
        end
    end

    // FIFO Buffer
    localparam unsigned FIFO_BUFFER_WIDTH = 4 * INPUT_VERTEX_DATAWIDTH;
    //      DEPTH = (input_freq * ports * DATAWIDTH) / (output_freq * ports * DATAWIDTH)
    localparam unsigned FIFO_BUFFER_DEPTH = INPUT_VERTEX_DATAWIDTH + INPUT_VERTEX_FRACBITS + 2;

    logic w_fifo_read_en;
    logic w_fifo_write_en;

    logic w_fifo_full;
    logic w_fifo_empty;

    logic signed [4 * INPUT_VERTEX_DATAWIDTH - 1:0] w_FIFO_data_out;

    sync_fifo #(
        .DATAWIDTH(FIFO_BUFFER_WIDTH),
        .DEPTH(FIFO_BUFFER_DEPTH)
    ) sync_fifo_inst (
        .rstn(rstn),

        .write_clk(clk),
        .read_clk(clk),
        .read_en(w_fifo_read_en),
        .write_en(w_fifo_write_en),

        .data_in({w_vs_o_vertex[0], w_vs_o_vertex[1], w_vs_o_vertex[2], w_vs_o_vertex[3]}),
        .data_out(w_FIFO_data_out),
        .o_dv(r_vpp_i_vertex_dv),

        .empty(w_fifo_empty),
        .full(w_fifo_full)
    );

    // Assign vpp vertex in by unpacking w_FIFO_data_out
    assign {r_vpp_i_vertex[0], r_vpp_i_vertex[1], r_vpp_i_vertex[2], r_vpp_i_vertex[3]} = w_FIFO_data_out;

    assign w_fifo_read_en = w_vpp_ready & !w_fifo_empty;
    assign w_fifo_write_en = w_vs_o_vertex_dv & !w_fifo_full;

    // For testing only
    assign o_vertex_vs[0] = w_vs_o_vertex[0];
    assign o_vertex_vs[1] = w_vs_o_vertex[1];
    assign o_vertex_vs[2] = w_vs_o_vertex[2];
    assign o_vertex_vs[3] = w_vs_o_vertex[3];
    assign o_vertex_vs_dv = w_vs_o_vertex_dv;

    assign ready = w_vs_ready & !w_fifo_full;
endmodule
