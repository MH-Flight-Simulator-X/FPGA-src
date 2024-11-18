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
    parameter unsigned BG_COLOR = 'h137, 
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

    output ready
    );

    localparam unsigned COLOR_WIDTH = CHANNEL_WIDTH*3;

    localparam unsigned BUFFER_DEPTH = DISPLAY_WIDTH*DISPLAY_HEIGHT;
    localparam unsigned BUFFER_ADDR_WIDTH = $clog2(BUFFER_DEPTH);

    // Display signals and coordinates
    logic signed [DISPLAY_COORD_WIDTH-1:0] screen_x, screen_y;
    logic de;
    logic frame;
    projectf_display_480p #(.CORDW(DISPLAY_COORD_WIDTH)) display_signal_inst (
        .clk_pix(clk_pix),
        .rst_pix(),
        .sx(screen_x),
        .sy(screen_y),
        .hsync(),
        .vsync(),
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
    buffer #(
        .WIDTH(FB_DATA_WIDTH),
        .DEPTH(BUFFER_DEPTH),
        .FILE(FB_IMAGE_FILE)
    ) framebuffer (
        .clk_write(clk),
        .clk_read(clk_pix),
        .write_enable(addr_inside_triangle),
        .clear(clear),
        .ready(fb_ready),
        .clear_value(),
        .addr_write(buffer_addr_write),
        .addr_read(fb_addr_read),
        .data_in(i_fb_data),
        .data_out(fb_data)
    );


    // Depth buffer memory
    logic [DB_DATA_WIDTH-1:0] db_data;
    logic db_ready;
    localparam DB_CLEAR_VALUE = {DB_DATA_WIDTH{1'b1}};

    buffer #(
        .WIDTH(DB_DATA_WIDTH),
        .DEPTH(BUFFER_DEPTH)
    ) depth_buffer (
        .clk_write(clk),
        .clk_read(clk_pix),
        .write_enable(addr_inside_triangle),
        .clear(clear),
        .ready(db_ready),
        .clear_value(DB_CLEAR_VALUE),
        .addr_write(buffer_addr_write),
        .addr_read(db_addr_read),
        .data_in(i_db_data),
        .data_out(db_data)
    );

    logic [BUFFER_ADDR_WIDTH-1:0] fb_addr_read;
    logic [BUFFER_ADDR_WIDTH-1:0] db_addr_read;

    logic pixel_in_fb;

    logic unsigned [DISPLAY_COORD_WIDTH-1:0] x_scale_counter, y_scale_counter;
    logic unsigned [DISPLAY_COORD_WIDTH-1:0] fb_x, fb_y;

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
            // Update horizontal scaling counter
            if (x_scale_counter < SCALE - 1) begin
                x_scale_counter <= x_scale_counter + 1;
            end
            else begin
                x_scale_counter <= 0;
                // Move to next framebuffer pixel horizontally
                if (fb_x < DISPLAY_WIDTH - 1) begin
                    fb_x <= fb_x + 1;
                end
                else begin
                    fb_x <= 0;
                    // Update vertical scaling counter
                    if (y_scale_counter < SCALE - 1) begin
                        y_scale_counter <= y_scale_counter + 1;
                    end
                    else begin
                        y_scale_counter <= 0;
                        // Move to next framebuffer line vertically
                        if (fb_y < DISPLAY_HEIGHT - 1) begin
                            fb_y <= fb_y + 1;
                        end
                    end
                end
            end

            fb_addr_read <= fb_y * DISPLAY_WIDTH + fb_x;
        end
    end


    always_comb begin
        // Check if display is ready
        ready = fb_ready && db_ready;

        // Output color logic
        if (~de) begin
            {o_red, o_green, o_blue} = 0;
        end
        else if (pixel_in_fb) begin
            {o_red, o_green, o_blue} = clut_data;
        end
        else begin
            {o_red, o_green, o_blue} = BG_COLOR;
        end
    end 

endmodule
