`default_nettype none
`timescale 1ns / 1ps

module top_MH_FPGA (
    input  wire logic clk,          // 100 MHz clock
    output      logic led,          // If clk100m is locked
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
    parameter unsigned MAX_MODEL_COUNT    = 32768;
    parameter unsigned MAX_NUM_OBJECTS_PER_FRAME = 1024;

    parameter unsigned SCREEN_WIDTH  = 160;
    parameter unsigned SCREEN_HEIGHT = 120;

    parameter unsigned ADDRWIDTH = $clog2(SCREEN_WIDTH * SCREEN_HEIGHT);

    parameter real ZFAR = 100.0;
    parameter real ZNEAR = 0.1;

    // =========================== CLOCKS ===========================
    logic rstn;
    logic clk_100m;
    logic clk_100m_locked;

    clock_100Mhz clock_100m_inst (
        .clk_20m(clk),
        .rst(0),
        .clk_100m(clk_100m),
        .clk_100m_5x(),
        .clk_100m_locked(clk_100m_locked)
    );
    always_ff @(posedge clk_100m) rstn <= !clk_100m_locked;
    assign led = clk_100m_locked;

    // =========================== FPGA-MCU-COM ===========================
    logic [MAX_NUM_OBJECTS_PER_FRAME-1:0] w_mcu_num_objects;

    // =========================== MODEL DATA ===========================

    // =========================== RENDER PIPELINE ===========================
    logic r_render_pipeline_start;
    logic w_render_pipeline_ready;
    logic w_render_pipeline_finished;

    // MVP Matrix
    logic w_mvp_matrix_read_en;
    logic signed [INPUT_DATAWIDTH-1:0] r_mvp_matrix_data[4][4];
    logic r_mvp_dv;

    // Vertex Data
    logic w_model_buff_vertex_read_en;
    logic signed [INPUT_DATAWIDTH-1:0] r_vertex_data[3];
    logic r_vertex_dv;
    logic r_vertex_last;

    // Index Data
    logic w_model_buff_index_read_en;
    logic [ADDRWIDTH-1:0] r_index_data[3];
    logic r_index_dv;
    logic r_index_last;

    // Framebuffer
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

        .render_pipeline_start(r_render_pipeline_start),
        .render_pipeline_ready(w_render_pipeline_ready),
        .render_pipeline_finished(w_render_pipeline_finished),

        .o_mvp_matrix_read_en(w_mvp_matrix_read_en),
        .i_mvp_matrix(r_mvp_matrix_data),
        .i_mvp_dv(r_mvp_dv),

        .o_model_buff_vertex_read_en(w_model_buff_vertex_read_en),
        .i_vertex(r_vertex_data),
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

    // =========================== DISPLAY ===========================

    // =========================== STATE ===========================
    typedef enum logic [1:0] {
        IDLE,
        AWAIT_MCU_DATA,
        CLEAR_FB,
        RENDER,
        DONE
    } state_t;
    state_t current_state = IDLE, next_state;

    always_ff @(posedge clk) begin
        if (~rstn) begin
            current_state <= IDLE;
        end
        else begin
            current_state <= next_state;
        end
    end

    always_comb begin
        next_state = current_state;

        case (current_state)
            IDLE: begin
                if (w_render_pipeline_ready) begin // TODO: add more ready signals
                    next_state = AWAIT_MCU_DATA;
                end
            end

            AWAIT_MCU_DATA: begin
                if () begin                 // TODO: Add MCU data output valid signal
                    next_state = CLEAR_FB;
                end
            end

            CLEAR_FB: begin
                if (w_render_pipeline_ready) begin  // TODO: Add clear done signal
                    next_state = RENDER;
                end
            end

            RENDER: begin
                if (w_render_pipeline_finished) begin
                    if (r_render_pipeline_num_objects_rendered == w_mcu_num_objects) begin
                        next_state = DONE;
                    end
                end
            end

            DONE: begin
                next_state = IDLE;
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

    always_ff @(posedge clk) begin
        case (current_state)
            IDLE: begin
                r_render_pipeline_start <= 0;
            end

            AWAIT_MCU_DATA: begin
                r_render_pipeline_start <= 0;
            end

            CLEAR_FB: begin
                r_render_pipeline_start <= 0;
            end

            RENDER: begin
                if (w_render_pipeline_finished) begin
                    r_rendered_objects <= r_rendered_objects + 1;

                    if (r_rendered_objects == w_mcu_num_objects-1) begin
                        r_render_pipeline_start <= 0;
                    end else begin
                        r_render_pipeline_start <= 1;
                    end
                end
            end

            DONE: begin
                r_render_pipeline_start <= 0;
            end

            default: begin
                r_render_pipeline_start <= 0;
            end
        endcase
    end
endmodule
