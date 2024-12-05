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
    input  logic clk_pixel,
    input  logic rstn,

    output logic ready,
    output logic finished,

    // Transform matrix from MVP Matrix FIFO
    output logic o_mvp_matrix_read_en,
    input  logic signed [INPUT_DATAWIDTH-1:0] i_mvp_matrix[4][4],
    input  logic i_mvp_dv,

    output logic frame,
    output logic display_en,
    output [15:0] sx,
    output [15:0] sy,

    output      logic vga_hsync,    // horizontal sync
    output      logic vga_vsync,    // vertical sync
    output      logic [7:0] vga_r,  // (8-bit temp for sim) 4-bit VGA red
    output      logic [7:0] vga_g,  // (8-bit temp for sim) 4-bit VGA green
    output      logic [7:0] vga_b   // (8-bit temp for sim) 4-bit VGA blue
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

    parameter unsigned SCREEN_WIDTH  = 160;
    parameter unsigned SCREEN_HEIGHT = 120;

    parameter unsigned ADDRWIDTH = $clog2(SCREEN_WIDTH * SCREEN_HEIGHT);

    parameter real ZFAR = 100.0;
    parameter real ZNEAR = 0.1;

    parameter string PALETTE_FILE = "palette.mem";
    parameter string FB_IMAGE_FILE = "image.mem";

    parameter unsigned TRIG_LUT_ADDRWIDTH = 12;

    // ============================ MODEL READER =============================
    logic w_model_reader_ready;
    logic r_model_reader_reset = 1'b0;

    logic [$clog2(MAX_MODEL_COUNT)-1:0] r_model_id = '0;

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
        .reset(r_model_reader_reset),
        .ready(w_model_reader_ready),

        .model_index(r_model_id),

        .index_read_en (w_model_buff_index_read_en),
        .vertex_read_en(w_model_buff_vertex_read_en),

        .index_data(r_index_data),
        .vertex_data(r_vertex),

        .index_o_dv(r_index_dv),
        .vertex_o_dv(r_vertex_dv),
        .index_data_last(r_index_last),
        .vertex_data_last(r_vertex_last)
    );

    // =========================== MVP Matrix Generation ===========================
    logic [TRIG_LUT_ADDRWIDTH-1:0] r_angle = '0;

    logic signed [INPUT_DATAWIDTH-1:0] r_view_projection_mat[4][4];
    logic signed [INPUT_DATAWIDTH-1:0] w_rot_z_mat[4][4];
    logic r_mvp_matrix_compontents_dv = 1'b0;

    logic signed [INPUT_DATAWIDTH-1:0] w_mvp_matrix[4][4];
    logic w_mvp_matrix_dv;
    logic w_mat_mul_ready;

    rot_z #(
        .DATA_WIDTH(INPUT_DATAWIDTH),
        .FRA_BITS(INPUT_FRACBITS),
        .TRIG_LUT_ADDR_WIDTH(TRIG_LUT_ADDRWIDTH)
    ) rot_z_mat_inst (
        .clk(clk),
        .angle(r_angle),
        .rot_z_mat(w_rot_z_mat)
    );

    mat_mul #(
        .DATAWIDTH(INPUT_DATAWIDTH),
        .FRACBITS(INPUT_FRACBITS)
    ) mat_mul_inst (
        .clk(clk),
        .rstn(rstn),

        .A(r_view_projection_mat),
        .B(w_rot_z_mat),
        .i_dv(r_mvp_matrix_components_dv),

        .C(w_mvp_matrix),
        .o_dv(w_mvp_matrix_dv),
        .o_ready(w_mat_mul_ready)
    );

    // =========================== RENDER_START PIPELINE ===========================
    logic r_render_pipeline_start = 1'b0;
    logic w_render_pipeline_ready;
    logic w_render_pipeline_finished;

    // MVP Matrix
    logic w_mvp_matrix_read_en;
    logic signed [INPUT_DATAWIDTH-1:0] r_mvp_matrix[4][4];
    logic r_mvp_dv = 1'b0;

    // Output raster signals
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

    logic signed [INPUT_DATAWIDTH-1:0] w_mvp_matrix[4][4];
    logic w_mvp_matrix_dv;

        .o_mvp_matrix_read_en(w_mvp_matrix_read_en),
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

        .o_fb_addr_write(w_fb_addr_write),
        .o_fb_write_en(w_fb_write_en),

        .o_fb_depth_data(w_fb_depth_data),
        .o_fb_color_data(w_fb_color_data)
    );

    // ============================ DISPLAY ============================
    logic r_display_clear = 1'b0;

    logic w_display_new_frame_render_ready;
    logic w_display_frame_swapped;

    display_new #(
        .DISPLAY_WIDTH(SCREEN_WIDTH),
        .DISPLAY_HEIGHT(SCREEN_HEIGHT),
        .DISPLAY_COORD_WIDTH(16),
        .SCALE(4),

        .FB_DATA_WIDTH(COLORWIDTH),
        .DB_DATA_WIDTH(OUTPUT_DATAWIDTH),

        .COLOR_CHANNEL_WIDTH(4),
        .FB_CLEAR_VALUE(0),

        .PALETTE_FILE(PALETTE_FILE),
        .FB_IMAGE_FILE(FB_IMAGE_FILE)
    ) display_inst (
        .clk(clk),
        .clk_pixel(clk_pixel),
        .rstn(rstn),

        .frame_render_done(w_render_pipeline_finished),
        .frame_clear(r_display_clear),
        .new_frame_render_ready(w_display_new_frame_render_ready),
        .frame_swapped(w_display_frame_swapped),

        .i_pixel_write_addr(w_fb_addr_write),
        .i_pixel_write_valid(w_fb_write_en),
        .i_fb_data(w_fb_color_data),
        .i_db_data(w_fb_depth_data),

        .o_red(),
        .o_green(),
        .o_blue(),
        .hsync(vga_hsync),
        .vsync(vga_vsync)
    );

    assign frame = display_inst.frame;
    assign sx = display_inst.screen_x;
    assign sy = display_inst.screen_y;
    assign display_en = display_inst.de;

    assign vga_r = {2{display_inst.o_red}};
    assign vga_g = {2{display_inst.o_green}};
    assign vga_b = {2{display_inst.o_blue}};

    // ============================ STATE =============================
    typedef enum logic [3:0] {
        MODEL_BUFFER_RESET,
        MODEL_BUFFER_WAIT_RESET,
        DISPLAY_CLEAR,
        DISPLAY_CLEAR_WAIT,
        RENDER_START,
        MVP_MATRIX_SET,
        MVP_MATRIX_WAIT_SET,
        RENDER_WAIT_FINISHED,
        RENDER_FINISHED
    } state_t;
    state_t current_state = MODEL_BUFFER_RESET, next_state;

    always_ff @(posedge clk) begin
        if (~rstn) begin
            current_state <= MODEL_BUFFER_RESET;
        end else begin
            current_state <= next_state;
        end
    end

    always_comb begin
        next_state = current_state;

        case (current_state)
            MODEL_BUFFER_RESET: begin
                next_state = MODEL_BUFFER_WAIT_RESET;
            end

            MODEL_BUFFER_WAIT_RESET: begin
                if (w_model_reader_ready) begin
                    next_state = DISPLAY_CLEAR;
                end
            end

            DISPLAY_CLEAR: begin
                if (r_display_clear && ~w_display_new_frame_render_ready) begin
                    next_state = DISPLAY_CLEAR_WAIT;
                end
            end

            DISPLAY_CLEAR_WAIT: begin
                if (w_display_new_frame_render_ready && w_render_pipeline_ready) begin
                    next_state = RENDER_START;
                end
            end

            RENDER_START: begin
                if (w_render_pipeline_ready && r_render_pipeline_start) begin
                    next_state = MVP_MATRIX_SET;
                end
            end

            MVP_MATRIX_SET: begin
                next_state = MVP_MATRIX_WAIT_SET;
            end

            MVP_MATRIX_WAIT_SET: begin
                if (~w_mvp_matrix_read_en) begin
                    next_state = RENDER_WAIT_FINISHED;
                end
            end

            RENDER_WAIT_FINISHED: begin
                if (w_render_pipeline_finished) begin
                    next_state = RENDER_FINISHED;
                end
            end

            RENDER_FINISHED: begin
                if (w_display_frame_swapped) begin
                    next_state = MODEL_BUFFER_RESET;
                end
            end

            default: begin
                next_state = MODEL_BUFFER_RESET;
            end
        endcase
    end

    always_ff @(posedge clk) begin
        if (~rstn) begin
            r_render_pipeline_start <= 1'b0;
            o_mvp_matrix_read_en <= 1'b0;
            finished <= 1'b0;
            r_display_clear <= 1'b0;
        end else begin
            case (current_state)
                MODEL_BUFFER_RESET: begin
                    r_render_pipeline_start <= 1'b0;
                    o_mvp_matrix_read_en <= 1'b0;
                    finished <= 1'b0;
                    r_model_reader_reset <= 1'b1;
                    r_display_clear <= 1'b0;
                end

                MODEL_BUFFER_WAIT_RESET: begin
                    r_model_reader_reset <= 1'b0;
                end

                DISPLAY_CLEAR: begin
                    r_display_clear <= 1'b1;
                end

                DISPLAY_CLEAR_WAIT: begin
                    r_display_clear <= 1'b0;
                end

                RENDER_START: begin
                    if (w_render_pipeline_ready) begin
                        r_render_pipeline_start <= 1'b1;
                    end else begin
                        r_render_pipeline_start <= 1'b0;
                    end
                end

                MVP_MATRIX_SET: begin
                    r_render_pipeline_start <= 1'b0;

                    if (w_mvp_matrix_read_en) begin
                        o_mvp_matrix_read_en <= 1'b1;
                    end else begin
                        o_mvp_matrix_read_en <= 1'b0;
                    end
                end

                MVP_MATRIX_WAIT_SET: begin
                    o_mvp_matrix_read_en <= 1'b0;
                end

                RENDER_FINISHED: begin
                    finished <= 1'b1;
                    if (w_display_frame_swapped) begin
                        r_model_id <= (r_model_id == '0) ? 1 : 0;
                    end
                end

                default: begin
                end
            endcase
        end
    end

endmodule
