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

    parameter string PALETTE_FILE = "palette.mem";
    parameter string FB_IMAGE_FILE  =  "image.mem";

    // =========================== CLOCKS ===========================
    // logic rstn;
    // logic clk_100m;
    // logic clk_100m_locked;
    //
    // clock_100Mhz clock_100m_inst (
    //     .clk_20m(clk),
    //     .rst(0),
    //     .clk_100m(clk_100m),
    //     .clk_100m_5x(),
    //     .clk_100m_locked(clk_100m_locked)
    // );
    // always_ff @(posedge clk_100m) rstn <= !clk_100m_locked;
    // assign led = clk_100m_locked;
    //
    // // generate pixel clock
    // logic clk_pix;
    // logic clk_pix_locked;
    // logic rst_pix;
    // clock_480p clock_pix_inst (
    //    .clk(clk_100m),
    //    .rst(~rstn),  // reset button is active low
    //    .clk_pix(clk_pix),
    //    .clk_pix_5x(),  // not used for VGA output
    //    .clk_pix_locked(clk_pix_locked)
    // );
    // always_ff @(posedge clk_pix) rst_pix <= !clk_pix_locked;  // wait for clock lock

    // =========================== FPGA-MCU-COM ===========================
    logic [MAX_NUM_OBJECTS_PER_FRAME-1:0] w_mcu_num_objects;

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

    // External state stuff for render pipeline
    logic [MAX_NUM_OBJECTS_PER_FRAME-1:0] r_render_pipeline_num_objects_rendered;

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

    // =========================== DISPLAY ===========================
    logic w_display_ready;
    logic r_display_clear;

    display #(
        .DISPLAY_WIDTH(SCREEN_WIDTH),
        .DISPLAY_HEIGHT(SCREEN_HEIGHT),
        .SCALE(2),
        .DISPLAY_COORD_WIDTH(ADDRWIDTH),
        .FB_DATA_WIDTH(COLORWIDTH),
        .DB_DATA_WIDTH(OUTPUT_DATAWIDTH),
        .CLUT_WIDTH(12),
        .CLUT_DEPTH(1 << COLORWIDTH),
        .CHANNEL_WIDTH(4),
        .FB_CLEAR_VALUE(0),
        .PALETTE_FILE(PALETTE_FILE),
        .FB_IMAGE_FILE(FB_IMAGE_FILE)
    ) display_inst (
        .clk(clk),
        .clk_pix(clk_pix),
        .rst(~rstn),

        .ready(display_ready),
        .clear(clear),

        .i_pixel_write_addr(w_fb_addr_write),
        .i_pixel_write_valid(w_fb_write_en),
        .i_fb_data(w_fb_color_data),
        .i_db_data(w_fb_depth_data),

        .o_red(vga_r),
        .o_green(vga_g),
        .o_blue(vga_b),

        .hsync(vga_hsync),
        .vsync(vga_vsync)
    );

    assign frame = display_inst.frame;
    assign display_en = display_inst.de;
    assign sx = display_inst.screen_x;
    assign sy = display_inst.screen_y;

    // =========================== STATE ===========================
    // typedef enum logic [1:0] {
    //     IDLE,
    //     AWAIT_MCU_DATA,
    //     CLEAR_FB,
    //     RENDER,
    //     DONE
    // } state_t;
    // state_t current_state = IDLE, next_state;
    //
    // always_ff @(posedge clk) begin
    //     if (~rstn) begin
    //         current_state <= IDLE;
    //     end
    //     else begin
    //         current_state <= next_state;
    //     end
    // end
    //
    // always_comb begin
    //     next_state = current_state;
    //
    //     case (current_state)
    //         IDLE: begin
    //             if (w_render_pipeline_ready) begin // TODO: add more ready signals
    //                 next_state = AWAIT_MCU_DATA;
    //             end
    //         end
    //
    //         AWAIT_MCU_DATA: begin
    //             if () begin                 // TODO: Add MCU data output valid signal
    //                 next_state = CLEAR_FB;
    //             end
    //         end
    //
    //         CLEAR_FB: begin
    //             if (w_render_pipeline_ready) begin  // TODO: Add clear done signal
    //                 next_state = RENDER;
    //             end
    //         end
    //
    //         RENDER: begin
    //             if (w_render_pipeline_finished) begin
    //                 if (r_render_pipeline_num_objects_rendered == w_mcu_num_objects) begin
    //                     next_state = DONE;
    //                 end
    //             end
    //         end
    //
    //         DONE: begin
    //             next_state = IDLE;
    //         end
    //
    //         default: begin
    //             next_state = IDLE;
    //         end
    //     endcase
    // end
    //
    // always_ff @(posedge clk) begin
    //     case (current_state)
    //         IDLE: begin
    //             r_render_pipeline_start <= 0;
    //         end
    //
    //         AWAIT_MCU_DATA: begin
    //             r_render_pipeline_start <= 0;
    //         end
    //
    //         CLEAR_FB: begin
    //             r_render_pipeline_start <= 0;
    //         end
    //
    //         RENDER: begin
    //             if (w_render_pipeline_finished) begin
    //                 r_rendered_objects <= r_rendered_objects + 1;
    //
    //                 if (r_rendered_objects == w_mcu_num_objects-1) begin
    //                     r_render_pipeline_start <= 0;
    //                 end else begin
    //                     r_render_pipeline_start <= 1;
    //                 end
    //             end
    //         end
    //
    //         DONE: begin
    //             r_render_pipeline_start <= 0;
    //         end
    //
    //         default: begin
    //             r_render_pipeline_start <= 0;
    //         end
    //     endcase
    // end
endmodule
