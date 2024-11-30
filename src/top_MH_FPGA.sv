/*
    __  _____  __    _________       __    __     _____ _                 __      __                _  __
   /  |/  / / / /   / ____/ (_)___ _/ /_  / /_   / ___/(_)___ ___  __  __/ /___ _/ /_____  _____   | |/ /
  / /|_/ / /_/ /   / /_  / / / __ `/ __ \/ __/   \__ \/ / __ `__ \/ / / / / __ `/ __/ __ \/ ___/   |   /
 / /  / / __  /   / __/ / / / /_/ / / / / /_    ___/ / / / / / / / /_/ / / /_/ / /_/ /_/ / /      /   |
/_/  /_/_/ /_/   /_/   /_/_/\__, /_/ /_/\__/   /____/_/_/ /_/ /_/\__,_/_/\__,_/\__/\____/_/      /_/|_|
                           /____/
*/

`default_nettype none
`timescale 1ns / 1ps

module top_MH_FPGA (
    input  logic clk,
    input  logic clk_pix,
    input  logic rstn,

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
    output logic [COLORWIDTH-1:0] o_fb_color_data,

    output logic frame,
    output logic display_ready,
    output logic display_en,
    output [ADDRWIDTH-1:0] sx,
    output [ADDRWIDTH-1:0] sy,

    input logic clear,

    output      logic vga_hsync,    // horizontal sync
    output      logic vga_vsync,    // vertical sync
    output      logic [3:0] vga_r,  // 4-bit VGA red
    output      logic [3:0] vga_g,  // 4-bit VGA green
    output      logic [3:0] vga_b   // 4-bit VGA blue
    );

    // =========================== PARAMETERS ===========================
    parameter unsigned INPUT_DATAWIDTH = 24;
    parameter unsigned INPUT_FRACBITS  = 13;
    parameter unsigned OUTPUT_DATAWIDTH = 12;
    parameter unsigned COLORWIDTH = 4;

    parameter unsigned MAX_TRIANGLE_COUNT = 32768;
    parameter unsigned MAX_VERTEX_COUNT   = 32768;
    parameter unsigned MAX_MODEL_COUNT    = 16;
    parameter unsigned MAX_NUM_OBJECTS_PER_FRAME = 1024;

    parameter unsigned SCREEN_WIDTH  = 320;
    parameter unsigned SCREEN_HEIGHT = 240;

    parameter unsigned ADDRWIDTH = $clog2(SCREEN_WIDTH * SCREEN_HEIGHT);

    parameter real ZFAR = 100.0;
    parameter real ZNEAR = 0.1;

    // =========================== RENDER PIPELINE ===========================
    logic r_render_pipeline_start;
    logic w_render_pipeline_ready;
    logic w_render_pipeline_finished;

    logic w_mvp_matrix_read_en;
    logic signed [INPUT_DATAWIDTH-1:0] r_mvp_matrix[4][4];
    logic r_mvp_dv;

    // Read vertex data from Model Buffer -- Effectively accessed as SAM
    logic w_model_buff_vertex_read_en;
    logic signed [INPUT_DATAWIDTH-1:0] r_vertex[3];
    logic r_vertex_dv;
    logic r_vertex_last;

    // Read index data from Model Buffer -- Also SAM access pattern
    logic w_model_buff_index_read_en;
    logic [$clog2(MAX_VERTEX_COUNT)-1:0] r_index_data[3];
    logic r_index_dv;
    logic r_index_last;

    // Rasterizer Output
    logic [ADDRWIDTH-1:0] w_fb_addr_write;
    logic w_fb_write_en;

    logic [OUTPUT_DATAWIDTH-1:0] w_fb_depth_data;
    logic [COLORWIDTH-1:0] w_fb_color_data;

    render_pipeline #(
        .INPUT_DATAWIDTH(INPUT_DATAWIDTH),
        .INPUT_FRACBITS(INPUT_FRACBITS),
        .OUTPUT_DATAWIDTH(OUTPUT_DATAWIDTH),
        .COLORWIDTH(COLORWIDTH),

        .MAX_TRIANGLE_COUNT(MAX_TRIANGLE_COUNT),
        .MAX_VERTEX_COUNT(MAX_VERTEX_COUNT),

        .SCREEN_WIDTH(SCREEN_WIDTH),
        .SCREEN_HEIGHT(SCREEN_HEIGHT),

        .ADDRWIDTH(ADDRWIDTH),

        .ZFAR(ZFAR),
        .ZNEAR(ZNEAR)
    ) render_pipeline_inst (
        .clk(clk),
        .rstn(rstn),

        .start(r_render_pipeline_start),
        .ready(w_render_pipeline_ready),
        .finished(w_render_pipeline_finished),

        .o_mvp_matrix_read_en(w_mvp_matrix_read_en),
        .i_mvp_matrix(r_mvp_matrix),
        .i_mvp_dv(r_mvp_dv),

        .o_model_buff_vertex_read_en(w_model_buff_vertex_read_en),
        .i_vertex(r_vertex),
        .i_vertex_dv(r_vertex_dv),
        .i_vertex_last(r_vertex_last),

        .o_model_buff_index_read_en(w_model_buff_index_read_en),
        .i_index_data(r_index_data),
        .i_index_dv(r_index_dv),
        .i_index_last(r_index_last),

        .o_fb_addr_write(w_fb_addr_write),
        .o_fb_write_en(w_fb_write_en),

        .o_fb_depth_data(w_fb_depth_data),
        .o_fb_color_data(w_fb_color_data)
    );

    assign r_render_pipeline_start = start;
    assign ready = w_render_pipeline_ready;
    assign finished = w_render_pipeline_finished;

    assign o_mvp_matrix_read_en = w_mvp_matrix_read_en;
    assign r_mvp_matrix[0][0] = i_mvp_matrix[0][0]; assign r_mvp_matrix[0][1] = i_mvp_matrix[0][1]; assign r_mvp_matrix[0][2] = i_mvp_matrix[0][2]; assign r_mvp_matrix[0][3] = i_mvp_matrix[0][3];
    assign r_mvp_matrix[1][0] = i_mvp_matrix[1][0]; assign r_mvp_matrix[1][1] = i_mvp_matrix[1][1]; assign r_mvp_matrix[1][2] = i_mvp_matrix[1][2]; assign r_mvp_matrix[1][3] = i_mvp_matrix[1][3];
    assign r_mvp_matrix[2][0] = i_mvp_matrix[2][0]; assign r_mvp_matrix[2][1] = i_mvp_matrix[2][1]; assign r_mvp_matrix[2][2] = i_mvp_matrix[2][2]; assign r_mvp_matrix[2][3] = i_mvp_matrix[2][3];
    assign r_mvp_matrix[3][0] = i_mvp_matrix[3][0]; assign r_mvp_matrix[3][1] = i_mvp_matrix[3][1]; assign r_mvp_matrix[3][2] = i_mvp_matrix[3][2]; assign r_mvp_matrix[3][3] = i_mvp_matrix[3][3];
    assign r_mvp_dv = i_mvp_dv;

    // Read vertex data from Model Buffer -- Effectively accessed as SAM
    assign o_model_buff_vertex_read_en = w_model_buff_vertex_read_en;
    assign r_vertex[0] = i_vertex[0]; assign r_vertex[1] = i_vertex[1]; assign r_vertex[2] = i_vertex[2];
    assign r_vertex_dv = i_vertex_dv;
    assign r_vertex_last = i_vertex_last;

    // Read index data from Model Buffer -- Also SAM access pattern
    assign o_model_buff_index_read_en = w_model_buff_index_read_en;
    assign r_index_data[0] = i_index_data[0]; assign r_index_data[1] = i_index_data[1]; assign r_index_data[2] = i_index_data[2];
    assign r_index_dv = i_index_dv;
    assign r_index_last = i_index_last;

    // Rasterizer Output
    assign o_fb_addr_write = w_fb_addr_write;
    assign o_fb_write_en = w_fb_write_en;

    assign o_fb_depth_data = w_fb_depth_data;
    assign o_fb_color_data = w_fb_color_data;

endmodule
