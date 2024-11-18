`timescale 1ns / 1ps

module display#(
    parameter unsigned DISPLAY_WIDTH = 160,
    parameter unsigned DISPLAY_HEIGHT = 120,
    parameter unsigned SCALE = 4,
    parameter unsigned DISPLAY_COORD_WIDTH = 16,
    parameter unsigned FB_DATA_WIDTH = 4,
    parameter unsigned DB_DATA_WIDTH = 12,
    parameter unsigned CLUT_WIDTH = 12,
    parameter unsigned CLUT_DEPTH = 16,
    parameter unsigned CHANNEL_WIDTH = 4,
    parameter unsigned FB_CLEAR_VALUE = 0,
    parameter string PALETTE_FILE = "palette.mem",
    parameter string FB_IMAGE_FILE = "image.mem"
    ) (
    input logic clk,
    input logic clk_pix,

    input logic unsigned [BUFFER_ADDR_WIDTH-1:0] buffer_addr_write,

    input logic unsigned [FB_DATA_WIDTH-1:0] i_fb_data,
    input logic unsigned [DB_DATA_WIDTH-1:0] i_db_data,

    input logic addr_inside_triangle,

    input logic clear,

    output logic unsigned [CHANNEL_WIDTH-1:0] o_red,
    output logic unsigned [CHANNEL_WIDTH-1:0] o_green,
    output logic unsigned [CHANNEL_WIDTH-1:0] o_blue,

    output logic hsync,
    output logic vsync,

    output logic ready
    );

    localparam unsigned COLOR_WIDTH = CHANNEL_WIDTH*3;

    localparam unsigned BUFFER_DEPTH = DISPLAY_WIDTH*DISPLAY_HEIGHT;
    localparam unsigned BUFFER_ADDR_WIDTH = $clog2(BUFFER_DEPTH);

    // Display signals and coordinates
    logic signed [DISPLAY_COORD_WIDTH-1:0] screen_x, screen_y;
    logic de;
    logic frame;
    display_signals_480p #(.CORDW(DISPLAY_COORD_WIDTH)) display_signal_inst (
        .clk_pix(clk_pix),
        .rst_pix(1'b0),
        .sx(screen_x),
        .sy(screen_y),
        .hsync(hsync),
        .vsync(vsync),
        .de(de),
        .frame(frame),
        .line()
    );

    // Color lookup table
    logic [COLOR_WIDTH-1:0] clut_data;
    rom #(
        .WIDTH(CLUT_WIDTH),
        .DEPTH(CLUT_DEPTH),
        .FILE(PALETTE_FILE)
    ) clut (
        .clk(clk_pix),
        .addr(fb_data),
        .data(clut_data)
    );

    // Framebuffer memory
    logic [FB_DATA_WIDTH-1:0] fb_data;
    logic fb_ready;
    logic framebuffer_write_enable;
    buffer #(
        .WIDTH(FB_DATA_WIDTH),
        .DEPTH(BUFFER_DEPTH),
        .FILE(FB_IMAGE_FILE)
    ) framebuffer (
        .clk_write(clk),
        .clk_read(clk_pix),
        .write_enable(framebuffer_write_enable),
        .clear(clear),
        .ready(fb_ready),
        .clear_value(FB_CLEAR_VALUE),
        .addr_write(buffer_addr_write_d),
        .addr_read(fb_addr_read),
        .data_in(i_fb_data_d),
        .data_out(fb_data)
    );


    // Depth buffer memory
    logic [DB_DATA_WIDTH-1:0] db_data;
    logic db_ready;
    localparam DB_CLEAR_VALUE = {DB_DATA_WIDTH{1'b1}};
    logic depth_write_enable;
    logic [BUFFER_ADDR_WIDTH-1:0] depth_read_addr;

    buffer #(
        .WIDTH(DB_DATA_WIDTH),
        .DEPTH(BUFFER_DEPTH)
    ) depth_buffer (
        .clk_write(clk),
        .clk_read(clk),
        .write_enable(depth_write_enable),
        .clear(clear),
        .ready(db_ready),
        .clear_value(DB_CLEAR_VALUE),
        .addr_write(buffer_addr_write_d),
        .addr_read(depth_read_addr),
        .data_in(i_db_data_d),
        .data_out(db_data)
    );

    logic [BUFFER_ADDR_WIDTH-1:0] fb_addr_read;
    logic [BUFFER_ADDR_WIDTH-1:0] db_addr_read;

    logic pixel_in_fb;

    logic unsigned [DISPLAY_COORD_WIDTH-1:0] x_scale_counter, y_scale_counter;
    logic unsigned [DISPLAY_COORD_WIDTH-1:0] fb_x, fb_y;

    // Delayed signals for depth test
    logic [DB_DATA_WIDTH-1:0] i_db_data_d;
    logic [FB_DATA_WIDTH-1:0] i_fb_data_d;
    logic [BUFFER_ADDR_WIDTH-1:0] buffer_addr_write_d;
    logic addr_inside_triangle_d;

    always_ff @(posedge clk_pix) begin 
        // Check if pixel is inside buffer drawing area
        pixel_in_fb <= (0 <= screen_y && screen_y < DISPLAY_HEIGHT * SCALE && 
                        0 <= screen_x && screen_x < DISPLAY_WIDTH * SCALE);

        if (frame) begin
            // Reset counters at start of frame
            x_scale_counter <= 0;
            y_scale_counter <= 0;
            fb_x <= 0;
            fb_y <= 0;
            fb_addr_read <= 0;
        end
        else if (pixel_in_fb) begin
            if (x_scale_counter < SCALE - 1) begin
                x_scale_counter <= x_scale_counter + 1;
            end
            else begin
                x_scale_counter <= 0;
                if (fb_x < DISPLAY_WIDTH - 1) begin
                    fb_x <= fb_x + 1;
                end
                else begin
                    fb_x <= 0;
                    if (y_scale_counter < SCALE - 1) begin
                        y_scale_counter <= y_scale_counter + 1;
                    end
                    else begin
                        y_scale_counter <= 0;
                        if (fb_y < DISPLAY_HEIGHT - 1) begin
                            fb_y <= fb_y + 1;
                        end
                    end
                end
            end

            fb_addr_read <= fb_y * DISPLAY_WIDTH + fb_x;
        end
    end

    // Depth test and write logic
    always_ff @(posedge clk) begin
        // Delay signals by one clock cycle
        addr_inside_triangle_d <= addr_inside_triangle;
        i_db_data_d <= i_db_data;
        i_fb_data_d <= i_fb_data;
        buffer_addr_write_d <= buffer_addr_write;

        if (addr_inside_triangle) begin
            // Set the read address to the write address
            depth_read_addr <= buffer_addr_write;
        end else begin
            depth_read_addr <= '0; // Default or idle value
        end

        // After one clock cycle, perform the depth test
        if (addr_inside_triangle_d) begin
            if (i_db_data_d < db_data) begin
                depth_write_enable <= 1;
                framebuffer_write_enable <= 1;
            end else begin
                depth_write_enable <= 0;
                framebuffer_write_enable <= 0;
            end
        end else begin
            depth_write_enable <= 0;
            framebuffer_write_enable <= 0;
        end
    end

    always_comb begin
        // Check if display is ready
        ready = fb_ready && db_ready;

        // Output color logic
        if (pixel_in_fb && de) begin
            {o_red, o_green, o_blue} = clut_data;
        end
        else begin
            {o_red, o_green, o_blue} = 0;
        end
    end 

endmodule
