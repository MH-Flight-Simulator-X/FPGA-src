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

    input logic i_model_reader_reset,

    // // Read vertex data from Model Buffer -- Effectively accessed as SAM
    // output logic o_model_buff_vertex_read_en,
    // input  logic signed [INPUT_DATAWIDTH-1:0] i_vertex[3],
    // input  logic i_vertex_dv,
    // input  logic i_vertex_last,
    //
    // // Read index data from Model Buffer -- Also SAM access pattern
    // output logic o_model_buff_index_read_en,
    // input  logic [$clog2(MAX_VERTEX_COUNT)-1:0] i_index_data[3],
    // input  logic i_index_dv,
    // input  logic i_index_last,

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
    parameter unsigned MAX_INDEX_COUNT    = 32768;
    parameter unsigned MAX_MODEL_COUNT    = 16;
    parameter unsigned MAX_NUM_OBJECTS_PER_FRAME = 1024;

    parameter unsigned SCREEN_WIDTH  = 320;
    parameter unsigned SCREEN_HEIGHT = 240;

    parameter unsigned ADDRWIDTH = $clog2(SCREEN_WIDTH * SCREEN_HEIGHT);

    parameter real ZFAR = 100.0;
    parameter real ZNEAR = 0.1;

    // ============================ MODEL READER =============================
    logic w_model_reader_ready;

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

    model_reader #(
        .MODEL_INDEX_WIDTH($clog2(MAX_MODEL_COUNT)),
        .INDEX_ADDR_WIDTH($clog2(MAX_INDEX_COUNT)),
        .VERTEX_ADDR_WIDTH($clog2(MAX_VERTEX_COUNT)),
        .COORDINATE_WIDTH(INPUT_DATAWIDTH),
        .MODEL_HEADER_FILE("model_headers.mem"),
        .MODEL_FACES_FILE("model_faces.mem"),
        .MODEL_VERTEX_FILE("model_vertex.mem")
    ) model_reader_inst (
        .clk(clk),
        .reset(i_model_reader_reset),
        .ready(w_model_reader_ready),

        .model_index(0),        // Can be used to select which mesh to render, for now just 0

        .index_read_en (w_model_buff_index_read_en),
        .vertex_read_en(w_model_buff_vertex_read_en),

        .index_data(r_index_data),
        .vertex_data(r_vertex),

        .index_o_dv(r_index_dv),
        .vertex_o_dv(r_vertex_dv),
        .index_data_last(r_index_last),
        .vertex_data_last(r_vertex_last)
    );

    // =========================== RENDER PIPELINE ===========================
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

        .start(start),
        .ready(ready),
        .finished(finished),

        .o_mvp_matrix_read_en(o_mvp_matrix_read_en),
        .i_mvp_matrix(i_mvp_matrix),
        .i_mvp_dv(i_mvp_dv),

        .o_model_buff_vertex_read_en(w_model_buff_vertex_read_en),
        .i_vertex(r_vertex),
        .i_vertex_dv(r_vertex_dv),
        .i_vertex_last(r_vertex_last),

        .o_model_buff_index_read_en(w_model_buff_index_read_en),
        .i_index_data(r_index_data),
        .i_index_dv(r_index_dv),
        .i_index_last(r_index_last),

        .o_fb_addr_write(o_fb_addr_write),
        .o_fb_write_en(o_fb_write_en),

        .o_fb_depth_data(o_fb_depth_data),
        .o_fb_color_data(o_fb_color_data)
    );

    // // Read vertex data from Model Buffer -- Effectively accessed as SAM
    // assign o_model_buff_vertex_read_en = w_model_buff_vertex_read_en;
    // assign r_vertex[0] = i_vertex[0]; assign r_vertex[1] = i_vertex[1]; assign r_vertex[2] = i_vertex[2];
    // assign r_vertex_dv = i_vertex_dv;
    // assign r_vertex_last = i_vertex_last;
    //
    // // Read index data from Model Buffer -- Also SAM access pattern
    // assign o_model_buff_index_read_en = w_model_buff_index_read_en;
    // assign r_index_data[0] = i_index_data[0]; assign r_index_data[1] = i_index_data[1]; assign r_index_data[2] = i_index_data[2];
    // assign r_index_dv = i_index_dv;
    // assign r_index_last = i_index_last;

endmodule
