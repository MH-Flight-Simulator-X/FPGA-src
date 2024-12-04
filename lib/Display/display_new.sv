`timescale 1ns / 1ps

module display_new #(
    parameter unsigned DISPLAY_WIDTH = 160,
    parameter unsigned DISPLAY_HEIGHT = 120,
    parameter unsigned DISPLAY_COORD_WIDTH = 16,
    parameter unsigned SCALE = 4,

    parameter unsigned FB_DATA_WIDTH = 4,
    parameter unsigned DB_DATA_WIDTH = 12,

    parameter unsigned COLOR_CHANNEL_WIDTH = 4,
    parameter unsigned FB_CLEAR_VALUE = 0,
    parameter unsigned DB_CLEAR_VALUE = {DB_DATA_WIDTH{1'b1}},

    parameter string PALETTE_FILE = "palette.mem",
    parameter string FB_IMAGE_FILE = "image.mem",

    // Derived parameters
    parameter unsigned DISPLAY_DEPTH = DISPLAY_WIDTH*DISPLAY_HEIGHT,
    parameter unsigned DISPLAY_ADDR_WIDTH = $clog2(DISPLAY_DEPTH),

    parameter unsigned CLUT_WIDTH = 3 * COLOR_CHANNEL_WIDTH,    // 4-bit r, g and b
    parameter unsigned CLUT_DEPTH = 1 << FB_DATA_WIDTH          // 2^4 colors

) (
    input logic clk,
    input logic clk_pixel,
    input logic rstn,

    input logic frame_render_done,
    input logic frame_clear,
    output logic new_frame_render_ready,
    output logic frame_swapped,

    input logic [DISPLAY_ADDR_WIDTH-1:0] i_pixel_write_addr,
    input logic [FB_DATA_WIDTH-1:0] i_fb_data,
    input logic [DB_DATA_WIDTH-1:0] i_db_data,
    input logic i_pixel_write_valid,

    // VGA output signals
    output logic hsync,
    output logic vsync,

    output logic [COLOR_CHANNEL_WIDTH-1:0] o_red,
    output logic [COLOR_CHANNEL_WIDTH-1:0] o_green,
    output logic [COLOR_CHANNEL_WIDTH-1:0] o_blue
);

    // Generates display signals
    logic signed [DISPLAY_COORD_WIDTH-1:0] screen_x, screen_y;
    logic de, frame;
    display_signals_480p #(
        .CORDW(DISPLAY_COORD_WIDTH)
    ) display_signal_inst (
        .clk_pix(clk_pixel),
        .rst_pix(~rstn),

        .sx(screen_x),
        .sy(screen_y),

        .hsync(hsync),
        .vsync(vsync),
        .de(de),
        .frame(frame),
        .line()
    );

    // Signals for reading and writing to frame and depth buffers
    logic w_display_buffers_ready;
    logic r_display_buffers_write_en;

    logic [DISPLAY_ADDR_WIDTH-1:0] r_fb_addr_read;
    logic [FB_DATA_WIDTH-1:0] w_display_data_read;

    logic [DB_DATA_WIDTH-1:0] delayed_i_db_data;
    logic [FB_DATA_WIDTH-1:0] delayed_i_fb_data;
    logic [DISPLAY_ADDR_WIDTH-1:0] delayed_addr_write;

    // Depth buffer
    logic [DB_DATA_WIDTH-1:0] w_db_read_data;
    logic w_db_ready;

    buffer #(
        .WIDTH(DB_DATA_WIDTH),
        .DEPTH(DISPLAY_DEPTH)
    ) depth_buffer_inst (
        .clk_write(clk),
        .clk_read(clk),

        .ready(w_db_ready),
        .clear(frame_clear),
        .clear_value(DB_CLEAR_VALUE),

        .write_enable(r_display_buffers_write_en),
        .addr_write(delayed_addr_write),
        .addr_read(i_pixel_write_addr),
        .data_in(delayed_i_db_data),
        .data_out(w_db_read_data)
    );

    // ============== FRAME BUFFERS ==============
    // Selects which display should be the one to be rendered to. The other
    // one will be used to display to the screen. 0 indicates inst_1 is active,
    // 1 indicates inst_2 is active.
    logic r_current_active_render_target = 1'b0;

    logic w_fb_inst_1_write_en;
    logic w_fb_inst_2_write_en;

    logic w_fb_inst_1_ready;
    logic w_fb_inst_2_ready;

    logic w_fb_inst_1_clear;
    logic w_fb_inst_2_clear;

    logic [FB_DATA_WIDTH-1:0] w_fb_inst_1_data_read;
    logic [FB_DATA_WIDTH-1:0] w_fb_inst_2_data_read;

    // Logic for determining which display should be interacted with
    always_comb begin
        if (r_current_active_render_target) begin
            w_fb_inst_2_write_en = r_display_buffers_write_en & w_fb_inst_2_ready;
            w_fb_inst_2_clear = frame_clear;
            w_display_buffers_ready = w_fb_inst_2_ready; //  && w_db_ready

            w_fb_inst_1_write_en = '0;
            w_fb_inst_1_clear = '0;

            w_display_data_read = w_fb_inst_1_data_read;
        end else begin
            w_fb_inst_1_write_en = r_display_buffers_write_en & w_fb_inst_1_ready;
            w_fb_inst_1_clear = frame_clear;
            w_display_buffers_ready = w_fb_inst_1_ready; //  && w_db_ready

            w_fb_inst_2_write_en = '0;
            w_fb_inst_2_clear = '0;

            w_display_data_read = w_fb_inst_2_data_read;
        end
    end

    // Framebuffer instantiations
    buffer #(
        .WIDTH(FB_DATA_WIDTH),
        .DEPTH(DISPLAY_DEPTH),
        .FILE(FB_IMAGE_FILE)
    ) framebuffer_inst_1 (
        .clk_write(clk),
        .clk_read(clk_pixel),

        .ready(w_fb_inst_1_ready),
        .clear(w_fb_inst_1_clear),
        .clear_value(FB_CLEAR_VALUE),

        .write_enable(w_fb_inst_1_write_en),
        .addr_write(delayed_addr_write),
        .addr_read(r_fb_addr_read),
        .data_in(delayed_i_fb_data),
        .data_out(w_fb_inst_1_data_read)
    );

    buffer #(
        .WIDTH(FB_DATA_WIDTH),
        .DEPTH(DISPLAY_DEPTH),
        .FILE(FB_IMAGE_FILE)
    ) framebuffer_inst_2 (
        .clk_write(clk),
        .clk_read(clk_pixel),

        .ready(w_fb_inst_2_ready),
        .clear(w_fb_inst_2_clear),
        .clear_value(FB_CLEAR_VALUE),

        .write_enable(w_fb_inst_2_write_en),
        .addr_write(delayed_addr_write),
        .addr_read(r_fb_addr_read),
        .data_in(delayed_i_fb_data),
        .data_out(w_fb_inst_2_data_read)
    );

    // ================= CLUT =================
    logic [CLUT_WIDTH-1:0] clut_data;
    rom #(
        .WIDTH(CLUT_WIDTH),
        .DEPTH(CLUT_DEPTH),
        .FILE(PALETTE_FILE)
    ) clut_inst (
        .clk(clk_pixel),
        .addr(w_display_data_read),
        .data(clut_data)
    );

    // ================= STATE =================
    logic [DISPLAY_COORD_WIDTH-1:0] x_scale_counter, y_scale_counter;
    logic [DISPLAY_ADDR_WIDTH-1:0] fb_x, fb_y;

    logic r_frame_render_done;
    logic r_frame_swapped;
    logic [2:0] r_frame_signal_sync;
    logic [1:0] r_frame_swapped_sync;

    logic pixel_in_fb;
    // always_comb begin
    // end

    always_ff @(posedge clk) begin
        if (~rstn) begin
            r_frame_render_done <= '0;
            r_frame_signal_sync[0] <= '0;
            r_frame_signal_sync[1] <= '0;
            r_frame_signal_sync[2] <= '0;
        end else begin
            delayed_i_db_data <= i_db_data;
            delayed_i_fb_data <= i_fb_data;
            delayed_addr_write <= i_pixel_write_addr;

            if (i_pixel_write_valid) begin //  && (delayed_i_db_data < w_db_read_data)
                r_display_buffers_write_en <= 1;
            end else begin
                r_display_buffers_write_en <= 0;
            end

            r_frame_signal_sync[0] <= frame;
            r_frame_signal_sync[1] <= r_frame_signal_sync[0];
            r_frame_signal_sync[2] <= r_frame_signal_sync[1];

            if (~r_frame_signal_sync[1] && r_frame_signal_sync[2]) begin
                r_frame_render_done <= '0;
            end else if (frame_render_done) begin
                r_frame_render_done <= frame_render_done;
            end

            r_frame_swapped_sync[0] <= r_frame_swapped;
            r_frame_swapped_sync[1] <= r_frame_swapped_sync[0];
        end
    end
    assign frame_swapped = r_frame_swapped_sync[1];

    always_ff @(posedge clk_pixel) begin
        pixel_in_fb <= (0 <= screen_y && screen_y < DISPLAY_HEIGHT * SCALE &&
                        0 <= screen_x && screen_x < DISPLAY_WIDTH * SCALE);
        if (frame) begin
            if (r_frame_render_done) begin
                r_current_active_render_target <= ~r_current_active_render_target;
                $display("Switching buffers");
                $display("Current active render target: %d", ~r_current_active_render_target);
                r_frame_swapped <= 1'b1;
            end else begin
                r_frame_swapped <= 1'b0;
            end

            x_scale_counter <= '0;
            y_scale_counter <= '0;
            fb_x <= '0;
            fb_y <= '0;
            r_fb_addr_read <= '0;
        end else if (pixel_in_fb) begin
            r_frame_swapped <= 1'b0;
            if (x_scale_counter < SCALE-1) begin
                x_scale_counter <= x_scale_counter + 1;
            end else begin
                x_scale_counter <= '0;

                if (fb_x < DISPLAY_WIDTH - 1) begin
                    fb_x <= fb_x + 1;
                end else begin
                    fb_x <= '0;

                    if (y_scale_counter < SCALE - 1) begin
                        y_scale_counter <= y_scale_counter + 1;
                    end else begin
                        y_scale_counter <= '0;

                        if (fb_y < DISPLAY_HEIGHT - 1) begin
                            fb_y <= fb_y + 1;
                        end
                    end
                end
            end

            r_fb_addr_read <= fb_y * DISPLAY_WIDTH + fb_x;
        end else begin
            r_frame_swapped <= 1'b0;
        end
    end

    always_comb begin
        new_frame_render_ready = w_display_buffers_ready;

        if (pixel_in_fb && de) begin
            {o_red, o_green, o_blue} = clut_data;
        end else begin
            {o_red, o_green, o_blue} = 0;
        end
    end

endmodule
