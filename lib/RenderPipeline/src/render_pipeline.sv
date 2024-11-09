`timescale 1ns / 1ps

module render_pipeline #(
    parameter unsigned INPUT_DATAWIDTH = 24,
    parameter unsigned INPUT_FRACBITS  = 13,
    parameter unsigned OUTPUT_DATAWIDTH = 12,

    parameter unsigned MAX_TRIANGLE_COUNT = 4096,
    parameter unsigned MAX_VERTEX_COUNT   = 4096,

    parameter unsigned SCREEN_WIDTH  = 320,
    parameter unsigned SCREEN_HEIGHT = 320,

    parameter real ZFAR = 100.0,
    parameter real ZNEAR = 0.1
    ) (
    input logic clk,
    input logic rstn,

    input  logic start,
    output logic ready,

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
    input  logic i_index_last
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
        .o_triangle_dv(tp_o_triangle_dv)
    );

    // TODO: Replace with finished Rasterizer
    logic rasterizer_frontend_ready;
    logic rasterizer_frontend_next;

    logic signed [OUTPUT_DATAWIDTH-1:0] rf_bb_tl[2];
    logic signed [OUTPUT_DATAWIDTH-1:0] rf_bb_br[2];

    logic signed [2*OUTPUT_DATAWIDTH-1:0] rf_edge_val0;
    logic signed [2*OUTPUT_DATAWIDTH-1:0] rf_edge_val1;
    logic signed [2*OUTPUT_DATAWIDTH-1:0] rf_edge_val2;

    logic signed [OUTPUT_DATAWIDTH-1:0] rf_edge_delta0[2];
    logic signed [OUTPUT_DATAWIDTH-1:0] rf_edge_delta1[2];
    logic signed [OUTPUT_DATAWIDTH-1:0] rf_edge_delta2[2];

    logic [2*OUTPUT_DATAWIDTH-1:0] rf_area_inv;
    logic rf_o_dv;

    rasterizer_frontend #(
        .DATAWIDTH(OUTPUT_DATAWIDTH),
        .SCREEN_WIDTH(SCREEN_WIDTH),
        .SCREEN_HEIGHT(SCREEN_HEIGHT)
    ) rasterizer_frontend_inst (
        .clk(clk),
        .rstn(rstn),

        .ready(rasterizer_frontend_ready),
        .next(rasterizer_frontend_next),

        .i_v0(tp_v0),
        .i_v1(tp_v1),
        .i_v2(tp_v2),
        .i_triangle_dv(tp_o_triangle_dv),

        .bb_tl(rf_bb_tl),
        .bb_br(rf_bb_br),
        .edge_val0(rf_edge_val0),
        .edge_val1(rf_edge_val1),
        .edge_val2(rf_edge_val2),

        .edge_delta0(rf_edge_delta0),
        .edge_delta1(rf_edge_delta1),
        .edge_delta2(rf_edge_delta2),
        .area_inv(rf_area_inv),
        .o_dv(rf_o_dv)
    );

    // Assign internal signals
    assign transform_pipeline_start = start;
    assign transform_pipeline_next = rasterizer_frontend_ready;

    // Assign external signals
    assign ready = transform_pipeline_ready;

endmodule
