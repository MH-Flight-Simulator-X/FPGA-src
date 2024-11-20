`timescale 1ns / 1ps

module render_pipeline #(
    parameter unsigned INPUT_DATAWIDTH = 24,
    parameter unsigned INPUT_FRACBITS  = 13,
    parameter unsigned OUTPUT_DATAWIDTH = 12,
    parameter unsigned COLORWIDTH = 4,

    parameter unsigned MAX_TRIANGLE_COUNT = 32768,
    parameter unsigned MAX_VERTEX_COUNT   = 32768,

    parameter unsigned SCREEN_WIDTH  = 320,
    parameter unsigned SCREEN_HEIGHT = 240,

    parameter unsigned ADDRWIDTH = $clog2(SCREEN_WIDTH * SCREEN_HEIGHT),

    parameter real ZFAR = 100.0,
    parameter real ZNEAR = 0.1
    ) (
    input logic clk,
    input logic rstn,

    input  logic start,
    output logic ready,
    output logic finished,

    // Transform matrix from MVP Matrix FIFO
    output logic o_mvp_matrix_read_en,
    input  logic signed [INPUT_DATAWIDTH-1:0] i_mvp_matrix[4][4],
    input  logic i_mvp_dv,

    // Read vertex data from Model Buffer -- Effectively accessed as SAM
    output logic o_model_buff_vertex_read_en,
    input  logic signed [INPUT_DATAWIDTH-1:0] i_vertex[3],
    input  logic i_vertex_dv,
    input  logic i_vertex_last,

    // Read index data from Model Buffer -- Also SAM access pattern
    output logic o_model_buff_index_read_en,
    input  logic [$clog2(MAX_VERTEX_COUNT)-1:0] i_index_data[3],
    input  logic i_index_dv,
    input  logic i_index_last,

    // Rasterizer Output
    output logic [ADDRWIDTH-1:0] o_fb_addr_write,
    output logic o_fb_write_en,

    output logic [OUTPUT_DATAWIDTH-1:0] o_fb_depth_data,
    output logic [COLORWIDTH-1:0] o_fb_color_data
    );

    // TODO: Actually use the signals for something
    /* verilator lint_off UNUSED */

    // Transform pipeline
    logic transform_pipeline_start;
    logic transform_pipeline_next;
    logic transform_pipeline_ready;
    logic transform_pipeline_done;

    logic signed [OUTPUT_DATAWIDTH-1:0] tp_v0[3];
    logic signed [OUTPUT_DATAWIDTH-1:0] tp_v1[3];
    logic signed [OUTPUT_DATAWIDTH-1:0] tp_v2[3];
    logic tp_o_triangle_dv;
    logic tp_o_triangle_last;

    transform_pipeline #(
        .INPUT_DATAWIDTH(INPUT_DATAWIDTH),
        .INPUT_FRACBITS(INPUT_FRACBITS),
        .OUTPUT_DATAWIDTH(OUTPUT_DATAWIDTH),

        .MAX_TRIANGLE_COUNT(MAX_TRIANGLE_COUNT),
        .MAX_VERTEX_COUNT(MAX_VERTEX_COUNT),

        .SCREEN_WIDTH(SCREEN_WIDTH),
        .SCREEN_HEIGHT(SCREEN_HEIGHT),

        .ZFAR(ZFAR),
        .ZNEAR(ZNEAR)
    ) transform_pipeline_inst (
        .clk(clk),
        .rstn(rstn),

        .transform_pipeline_start(transform_pipeline_start),
        .transform_pipeline_next(transform_pipeline_next),
        .transform_pipeline_ready(transform_pipeline_ready),
        .transform_pipeline_done(transform_pipeline_done),

        .o_mvp_matrix_read_en(o_mvp_matrix_read_en),
        .i_mvp_matrix(i_mvp_matrix),
        .i_mvp_dv(i_mvp_dv),

        .o_model_buff_vertex_read_en(o_model_buff_vertex_read_en),
        .i_vertex(i_vertex),
        .i_vertex_dv(i_vertex_dv),
        .i_vertex_last(i_vertex_last),

        .o_model_buff_index_read_en(o_model_buff_index_read_en),
        .i_index_data(i_index_data),
        .i_index_dv(i_index_dv),
        .i_index_last(i_index_last),

        .o_v0(tp_v0),
        .o_v1(tp_v1),
        .o_v2(tp_v2),
        .o_triangle_dv(tp_o_triangle_dv),
        .o_triangle_last(tp_o_triangle_last)
    );

    // TODO: Replace with finished Rasterizer
    logic w_rasterizer_ready;
    logic w_rasterizer_finished;
    rasterizer #(
        .DATAWIDTH(OUTPUT_DATAWIDTH),
        .COLORWIDTH(COLORWIDTH),
        .SCREEN_WIDTH(SCREEN_WIDTH),
        .SCREEN_HEIGHT(SCREEN_HEIGHT),
        .ADDRWIDTH(ADDRWIDTH)
    ) rasterizer_inst (
        .clk(clk),
        .rstn(rstn),

        .ready(w_rasterizer_ready),

        .i_v0(tp_v0),
        .i_v1(tp_v1),
        .i_v2(tp_v2),
        .i_triangle_dv(tp_o_triangle_dv),
        .i_triangle_last(tp_o_triangle_last),

        .o_fb_addr_write(o_fb_addr_write),
        .o_fb_write_en(o_fb_write_en),

        .o_fb_depth_data(o_fb_depth_data),
        .o_fb_color_data(o_fb_color_data),

        .finished(w_rasterizer_finished)
    );

    // Latch finish
    always_ff @(posedge clk) begin
        if (~rstn) begin
            finished <= 1'b0;
        end else begin
            // $display("Start: %d, Ready: %d, Finished: %d", start, transform_pipeline_ready, w_rasterizer_finished);
            if (w_rasterizer_finished) begin
                finished <= 1'b1;
            end else if (start) begin
                finished <= 1'b0;
            end
        end
    end

    // Assign internal signals
    assign transform_pipeline_start = start;
    assign transform_pipeline_next = w_rasterizer_ready;

    // Assign external signals
    assign ready = transform_pipeline_ready;

endmodule
