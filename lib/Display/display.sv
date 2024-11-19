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
    input logic rst,

    output logic ready,
    input logic clear,

    input logic unsigned [BUFFER_ADDR_WIDTH-1:0] i_pixel_write_addr,
    input logic unsigned [FB_DATA_WIDTH-1:0] i_fb_data,
    input logic unsigned [DB_DATA_WIDTH-1:0] i_db_data,
    input logic i_pixel_write_valid,

    // VGA signals
    output logic unsigned [CHANNEL_WIDTH-1:0] o_red,
    output logic unsigned [CHANNEL_WIDTH-1:0] o_green,
    output logic unsigned [CHANNEL_WIDTH-1:0] o_blue,

    output logic hsync,
    output logic vsync
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
        .rst_pix(rst),
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
        .read_en(),
        .addr(fb_data),
        .data(clut_data),
        .dv()
    );

    // Framebuffer memory
    logic [FB_DATA_WIDTH-1:0] fb_data;
    logic fb_ready;
    logic buffer_write_enable;

    buffer #(
        .WIDTH(FB_DATA_WIDTH),
        .DEPTH(BUFFER_DEPTH),
        .FILE(FB_IMAGE_FILE)
    ) framebuffer (
        .clk_write(clk),
        .clk_read(clk_pix),
        .write_enable(buffer_write_enable),
        .clear(clear),
        .ready(fb_ready),
        .clear_value(FB_CLEAR_VALUE),
        .addr_write(delayed_buffer_addr_write),
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
        .clk_read(clk),
        .write_enable(buffer_write_enable),
        .clear(clear),
        .ready(db_ready),
        .clear_value(DB_CLEAR_VALUE),
        .addr_write(delayed_buffer_addr_write),
        .addr_read(i_pixel_write_addr),
        .data_in(delayed_i_db_data),
        .data_out(db_data)
    );

    logic [BUFFER_ADDR_WIDTH-1:0] fb_addr_read;
    logic [BUFFER_ADDR_WIDTH-1:0] db_addr_read;

    logic pixel_in_fb;

    logic unsigned [DISPLAY_COORD_WIDTH-1:0] x_scale_counter, y_scale_counter;
    logic unsigned [DISPLAY_COORD_WIDTH-1:0] fb_x, fb_y;

    logic unsigned [DB_DATA_WIDTH-1:0] delayed_i_db_data;
    logic unsigned [BUFFER_ADDR_WIDTH-1:0] delayed_buffer_addr_write;
    logic delayed_addr_inside_triangle;


    // Depth test and write logic
    always_ff @(posedge clk) begin
        delayed_i_db_data <= i_db_data;
        delayed_buffer_addr_write <= i_pixel_write_addr;
        delayed_addr_inside_triangle <= i_pixel_write_valid;

        // if (i_pixel_write_valid && (delayed_i_db_data < db_data)) begin
        //     buffer_write_enable <= 1;
        // end
        // else begin
        //     buffer_write_enable <= 0;
        // end
        buffer_write_enable <= i_pixel_write_valid;
    end

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

// `timescale 1ns / 1ps
//
// /* verilator lint_off UNUSED */
// module display#(
//     parameter unsigned DISPLAY_WIDTH = 160,
//     parameter unsigned DISPLAY_HEIGHT = 120,
//     parameter unsigned DISPLAY_COORD_WIDTH = 16,
//     parameter unsigned FB_DATA_WIDTH = 4,
//     parameter unsigned DB_DATA_WIDTH = 12,
//     parameter unsigned CLUT_WIDTH = 12,
//     parameter unsigned CLUT_DEPTH = 16,
//     parameter unsigned CHANNEL_WIDTH = 4,
//     parameter unsigned BG_COLOR = 'h137,
//     parameter string PALETTE_FILE = "palette.mem",
//     parameter string FB_IMAGE_FILE = "image.mem"
//     ) (
//     input logic clk,
//     input logic clk_pix,
//     input logic clear,
//     output ready,
//
//     input logic unsigned [BUFFER_ADDR_WIDTH-1:0] i_pixel_write_addr,
//     input logic i_pixel_write_valid,
//     input logic unsigned [FB_DATA_WIDTH-1:0] i_fb_data,
//     input logic unsigned [DB_DATA_WIDTH-1:0] i_db_data,
//
//     output logic hsync,
//     output logic vsync,
//     output logic unsigned [CHANNEL_WIDTH-1:0] o_red,
//     output logic unsigned [CHANNEL_WIDTH-1:0] o_green,
//     output logic unsigned [CHANNEL_WIDTH-1:0] o_blue
//     );
//
//     localparam unsigned COLOR_WIDTH = CHANNEL_WIDTH*3;
//
//     localparam unsigned BUFFER_DEPTH = DISPLAY_WIDTH*DISPLAY_HEIGHT;
//     localparam unsigned BUFFER_ADDR_WIDTH = $clog2(BUFFER_DEPTH);
//
//     // Display signals and coordinates
//     logic signed [DISPLAY_COORD_WIDTH-1:0] screen_x, screen_y;
//     logic de;
//     logic frame;
//     display_signals_480p #(.CORDW(DISPLAY_COORD_WIDTH)) display_signal_inst (
//         .clk_pix(clk_pix),
//         .rst_pix(),
//         .sx(screen_x),
//         .sy(screen_y),
//         .hsync(hsync),
//         .vsync(vsync),
//         .de(de),
//         .frame(frame),
//         .line()
//     );
//
//     // Color lookup table
//     logic UNUSED_DV;
//     logic [COLOR_WIDTH-1:0] clut_data;
//     rom #(
//         .WIDTH(CLUT_WIDTH),
//         .DEPTH(CLUT_DEPTH),
//         .FILE(PALETTE_FILE)
//     ) clut (
//         .clk(clk_pix),
//         .read_en(),
//         .addr(fb_data),
//         .data(clut_data),
//         .dv(UNUSED_DV)
//     );
//
//     // Framebuffer memory
//     logic [FB_DATA_WIDTH-1:0] fb_data;
//     logic fb_ready;
//     buffer #(
//         .WIDTH(FB_DATA_WIDTH),
//         .DEPTH(BUFFER_DEPTH),
//         .FILE(FB_IMAGE_FILE)
//     ) framebuffer (
//         .clk_write(clk),
//         .clk_read(clk_pix),
//         .write_enable(i_pixel_write_valid),
//         .clear(clear),
//         .ready(fb_ready),
//         .clear_value(0),
//         .addr_write(i_pixel_write_addr),
//         .addr_read(fb_addr_read),
//         .data_in(i_fb_data),
//         .data_out(fb_data)
//     );
//
//
//     // Depth buffer memory
//     logic [DB_DATA_WIDTH-1:0] db_data;
//     logic db_ready;
//     localparam DB_CLEAR_VALUE = {DB_DATA_WIDTH{1'b1}};
//     buffer #(
//         .WIDTH(DB_DATA_WIDTH),
//         .DEPTH(BUFFER_DEPTH)
//     ) depth_buffer (
//         .clk_write(clk),
//         .clk_read(clk_pix),
//         .write_enable(i_pixel_write_valid),
//         .clear(clear),
//         .ready(db_ready),
//         .clear_value(DB_CLEAR_VALUE),
//         .addr_write(i_pixel_write_addr),
//         .addr_read(db_addr_read),
//         .data_in(i_db_data),
//         .data_out(db_data)
//     );
//
//     logic [BUFFER_ADDR_WIDTH-1:0] fb_addr_read;
//     logic [BUFFER_ADDR_WIDTH-1:0] db_addr_read;
//
//     // calculate framebuffer read address for display output
//     logic pixel_in_fb;
//     logic pixel_in_db;
//
//     always_ff @(posedge clk_pix) begin 
//         // Check if pixel is inside buffer drawing area
//         pixel_in_fb <= (screen_y >= 0 && screen_y < DISPLAY_HEIGHT && screen_x >= 0 && screen_x < DISPLAY_WIDTH);
//         pixel_in_db <= (screen_y >= 0 && screen_y < DISPLAY_HEIGHT && screen_x >= DISPLAY_WIDTH && screen_x < DISPLAY_WIDTH*2);
//
//         if (frame) begin
//             // reset addresses at start of frame
//             fb_addr_read <= 0;
//             db_addr_read <= 0;
//         end
//         else if (pixel_in_fb) begin
//             fb_addr_read <= fb_addr_read + 1;
//         end
//         else if (pixel_in_db) begin
//             db_addr_read <= db_addr_read + 1;
//         end
//     end
//
//
//     always_comb begin
//         // Check if display is ready
//         ready = fb_ready && db_ready;
//
//         // Output color logic
//         if (~de) begin
//             {o_red, o_green, o_blue} = 0;
//         end
//         else if (pixel_in_fb) begin
//             {o_red, o_green, o_blue} = clut_data;
//         end
//         else if (pixel_in_db) begin
//             {o_red, o_green, o_blue} = {db_data[11:8], 8'b00000000};
//         end
//         else begin
//             {o_red, o_green, o_blue} = BG_COLOR;
//         end
//     end 
//
// endmodule
