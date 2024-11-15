`timescale 1ns / 1ps

module display#(
    parameter unsigned DISPLAY_WIDTH = 160,
    parameter unsigned DISPLAY_HEIGHT = 120,
    parameter unsigned DISPLAY_COORD_WIDTH = 16,
    parameter unsigned FB_DATA_WIDTH = 4,
    parameter unsigned DB_DATA_WIDTH = 12,
    parameter unsigned CLUT_WIDTH = 12,
    parameter unsigned CLUT_DEPTH = 16,
    parameter unsigned CHANNEL_WIDTH = 4,
    parameter unsigned COLOR_WIDTH = CHANNEL_WIDTH*3,
    parameter unsigned BG_COLOR = 'h137,
    parameter unsigned BUFFER_DEPTH = DISPLAY_WIDTH*DISPLAY_HEIGHT,
    parameter unsigned BUFFER_ADDR_WIDTH = $clog2(BUFFER_DEPTH),
    parameter string PALETTE_FILE = "palette.mem",
    parameter string FB_IMAGE_FILE = "image.mem"
    ) (
    input logic clk,
    input logic clk_pix,

    input logic unsigned [BUFFER_ADDR_WIDTH-1:0] buffer_addr_write,

    input logic unsigned [DB_DATA_WIDTH-1:0] i_depth_data,

    input logic addr_inside_triangle,

    input logic clear,

    output logic unsigned [CHANNEL_WIDTH-1:0] o_red,
    output logic unsigned [CHANNEL_WIDTH-1:0] o_green,
    output logic unsigned [CHANNEL_WIDTH-1:0] o_blue,

    output ready
    );

    // display sync signals and coordinates
    logic signed [DISPLAY_COORD_WIDTH-1:0] screen_x, screen_y;
    logic hsync, vsync;
    logic de;
    logic frame;
    projectf_display_480p #(.CORDW(DISPLAY_COORD_WIDTH)) display_signal_inst (
        .clk_pix,
        .rst_pix(),
        .sx(screen_x),
        .sy(screen_y),
        .hsync,
        .vsync,
        .de,
        .frame,
        .line()
    );

    // colour lookup table
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

    logic [FB_DATA_WIDTH-1:0] fb_data;
    logic fb_ready;

    // framebuffer memory
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
        .data_in(),
        .data_out(fb_data)
    );


    logic [DB_DATA_WIDTH-1:0] db_value;
    logic db_ready;

    localparam DB_CLEAR_VALUE = 4095;

    // depth buffer memory
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
        .data_in(i_depth_data),
        .data_out(db_value)
    );


    assign ready = fb_ready && db_ready;


    logic [BUFFER_ADDR_WIDTH-1:0] fb_addr_read;
    logic [BUFFER_ADDR_WIDTH-1:0] db_addr_read;

    // calculate framebuffer read address for display output
    logic read_fb;
    always_ff @(posedge clk_pix) begin
        read_fb <= (screen_y >= 0 && screen_y < DISPLAY_HEIGHT && screen_x >= 0 && screen_x < DISPLAY_WIDTH);
        if (frame) begin  // reset address at start of frame
            fb_addr_read <= 0;
        end
        else if (read_fb) begin  // increment address in painting area
            fb_addr_read <= fb_addr_read + 1;
        end
    end

    logic read_db;
    always_ff @(posedge clk_pix) begin
        read_db <= (screen_y >= 0 && screen_y < DISPLAY_HEIGHT && screen_x >= DISPLAY_WIDTH && screen_x < DISPLAY_WIDTH*2);
        if (frame) begin  // reset address at start of frame
            db_addr_read <= 0;
        end 
        else if (read_db) begin  // increment address in painting area
            db_addr_read <= db_addr_read + 1;
        end
    end

    // paint screen
    logic paint_db;
    logic paint_fb;
    always_comb begin
        paint_fb = (screen_y >= 0 && screen_y < DISPLAY_HEIGHT && screen_x >= 0 && screen_x < DISPLAY_WIDTH);
        paint_db = (screen_y >= 0 && screen_y < DISPLAY_HEIGHT && screen_x >= DISPLAY_WIDTH && screen_x < DISPLAY_WIDTH*2);
        if (paint_fb) begin
            {o_red, o_green, o_blue} = clut_data;
        end
        else if (paint_db) begin
            {o_red, o_green, o_blue} = {db_value[11:8], 8'b00000000};
        end
        else begin
            {o_red, o_green, o_blue} = BG_COLOR;
        end
    end 

endmodule
