`timescale 1ns / 1ps

/* verilator lint_off UNUSED */
module top #(
    parameter unsigned DATAWIDTH = 12,
    parameter unsigned SCREEN_WIDTH = 160,
    parameter unsigned SCREEN_HEIGHT = 120,
    parameter unsigned ADDRWIDTH = $clog2(SCREEN_WIDTH * SCREEN_HEIGHT)
    ) (
    input  logic clk_100m,            // 100MHz clock
    input  logic clk_pix,             // pixel clock
    input  logic sim_rst,             // sim reset
    output logic [ADDRWIDTH-1:0] sdl_sx,  // horizontal SDL position
    output logic [ADDRWIDTH-1:0] sdl_sy,  // vertical SDL position
    output logic sdl_de,              // data enable (low in blanking interval)
    output logic [7:0] sdl_r,         // 8-bit red
    output logic [7:0] sdl_g,         // 8-bit green
    output logic [7:0] sdl_b,         // 8-bit blue
    output logic frame,
    output logic done
    );

    // display sync signals and coordinates
    logic signed [ADDRWIDTH-1:0] sx, sy;
    logic hsync, vsync;
    logic de;
    projectf_display_480p #(
        .CORDW(ADDRWIDTH)
    ) display_signal_inst (
        .clk_pix,
        .rst_pix(sim_rst),
        .sx,
        .sy,
        .hsync,
        .vsync,
        .de,
        .frame,
        .line()
    );

    // color parameters
    localparam unsigned COLOR_LOOKUP_WIDTH = 4;
    localparam unsigned CHANNEL_WIDTH = 4;
    localparam unsigned COLOR_WIDTH = 3*CHANNEL_WIDTH;
    logic [COLOR_WIDTH-1:0] BG_COLOR = 'h137;

    // framebuffer (FB)
    localparam unsigned FB_DATA_WIDTH  = 4;
    localparam unsigned FB_DEPTH = SCREEN_WIDTH * SCREEN_HEIGHT;
    localparam string FB_IMAGE  = "../../image.mem";

    // pixel read address and color
    logic [ADDRWIDTH-1:0] fb_addr_read;
    logic [ADDRWIDTH-1:0] fb_addr_write;
    logic [FB_DATA_WIDTH-1:0] fb_color_read;
    logic fb_write_enable;

    // TODO: FIX
    localparam signed X0 = 8;
    localparam signed Y0 = 4;
    localparam signed Z0 = 12'b100000000000; // 0.5

    localparam signed X1 = 20;
    localparam signed Y1 = 30;
    localparam signed Z1 = 12'b100000000000; // 0.5

    localparam signed X2 = 40;
    localparam signed Y2 = 20;
    localparam signed Z2 = 12'b000110011001; // 0.1

    localparam signed TILE_MIN_X = 0;
    localparam signed TILE_MIN_Y = 0;
    localparam signed TILE_MAX_X = SCREEN_WIDTH;
    localparam signed TILE_MAX_Y = SCREEN_HEIGHT;

    logic signed [DATAWIDTH-1:0] v0[3];
    logic signed [DATAWIDTH-1:0] v1[3];
    logic signed [DATAWIDTH-1:0] v2[3];

    initial begin
        v0[0] = X0; v0[1] = Y0; v0[2] = Z0;
        v1[0] = X1; v1[1] = Y1; v1[2] = Z1;
        v2[0] = X2; v2[1] = Y2; v2[2] = Z2;
    end

    logic unsigned [DATAWIDTH-1:0] w_depth_data;
    logic unsigned [COLOR_LOOKUP_WIDTH-1:0] w_color_data;

    rasterizer #(
        .DATAWIDTH(DATAWIDTH),
        .COLORWIDTH(COLOR_LOOKUP_WIDTH),
        .SCREEN_WIDTH(SCREEN_WIDTH),
        .SCREEN_HEIGHT(SCREEN_HEIGHT),
        .ADDRWIDTH(ADDRWIDTH)
    ) rasterizer_inst (
        .clk(clk_100m),
        .rstn(~sim_rst),
        .ready(),

        .i_v0(v0),
        .i_v1(v1),
        .i_v2(v2),
        .i_triangle_dv(1),
        .i_triangle_last(1),

        .o_fb_addr_write(fb_addr_write),
        .o_fb_write_en(fb_write_enable),
        .o_fb_depth_data(w_depth_data),
        .o_fb_color_data(w_color_data),
        .finished(done)
    );

    // framebuffer memory
    buffer #(
        .WIDTH(FB_DATA_WIDTH),
        .DEPTH(FB_DEPTH),
        .FILE(FB_IMAGE)
    ) framebuffer (
        .clk_write(clk_100m),
        .clk_read(clk_pix),
        .write_enable(fb_write_enable),
        .clear(),
        .ready(),
        .clear_value(),
        .addr_write(fb_addr_write),
        .addr_read(fb_addr_read),
        .data_in(w_color_data),
        .data_out(fb_color_read)
    );

    localparam unsigned DB_CLEAR_VALUE = (1 << DATAWIDTH)-1;
    localparam unsigned DB_DATA_WIDTH = 12;

    logic [ADDRWIDTH-1:0] db_addr_read;
    logic [DATAWIDTH-1:0] db_data_out;

    // Depth Buffer memory
    buffer #(
        .WIDTH(DB_DATA_WIDTH),
        .DEPTH(FB_DEPTH)
    ) db_inst (
        .clk_write(clk_100m),
        .clk_read(clk_pix),
        .write_enable(fb_write_enable),
        .clear(),
        .ready(),
        .clear_value(DB_CLEAR_VALUE),
        .addr_write(fb_addr_write),
        .addr_read(db_addr_read),
        .data_in(w_depth_data),
        .data_out(db_data_out)
    );

    // calculate framebuffer read address for display output
    logic read_fb;
    always_ff @(posedge clk_pix) begin
        read_fb <= (sy >= 0 && sy < SCREEN_HEIGHT && sx >= 0 && sx < SCREEN_WIDTH);
        if (frame) begin  // reset address at start of frame
            fb_addr_read <= 0;
        end else if (read_fb) begin  // increment address in painting area
            fb_addr_read <= fb_addr_read + 1;
        end
    end

    logic read_db;
    always_ff @(posedge clk_pix) begin
        read_db <= (sy >= 0 && sy < SCREEN_HEIGHT && sx >= SCREEN_WIDTH && sx < SCREEN_WIDTH*2);
        if (frame) begin  // reset address at start of frame
            db_addr_read <= 0;
        end else if (read_db) begin  // increment address in painting area
            db_addr_read <= db_addr_read + 1;
        end
    end

    localparam CLUT_WIDTH = 12;
    localparam CLUT_DEPTH = 16;
    localparam PALETTE_FILE = "../../palette.mem";

    // Colour Lookup Table
    logic [COLOR_WIDTH-1:0] fb_pix_color;
    rom #(
        .WIDTH(CLUT_WIDTH),
        .DEPTH(CLUT_DEPTH),
        .FILE(PALETTE_FILE)
    ) clut (
        .clk(clk_pix),
        .addr(fb_color_read),
        .data(fb_pix_color)
    );

    logic [CHANNEL_WIDTH-1:0] red, green, blue;
    display #(
        .DISPLAY_WIDTH(SCREEN_WIDTH),
        .DISPLAY_HEIGHT(SCREEN_HEIGHT),
        .COORDINATE_WIDTH(ADDRWIDTH),
        .FB_DATA_WIDTH(FB_DATA_WIDTH),
        .DB_DATA_WIDTH(DB_DATA_WIDTH),
        .CHANNEL_WIDTH(CHANNEL_WIDTH)
    ) display_inst (
        // .clk_pix(clk_pix),
        .screen_x(sx),
        .screen_y(sy),
        .fb_pix_colr(fb_pix_color),
        .db_value(db_data_out),
        .o_red(red),
        .o_green(green),
        .o_blue(blue)
    );

    // SDL output (8 bits per colour channel)
    always_ff @(posedge clk_pix) begin
        sdl_sx <= sx;
        sdl_sy <= sy;
        sdl_de <= de;
        sdl_r <= {2{red}};  // double signal width from 4 to 8 bits
        sdl_g <= {2{green}};
        sdl_b <= {2{blue}};
    end
endmodule
