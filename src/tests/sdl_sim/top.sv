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

    // color parameters
    localparam unsigned COLOR_LOOKUP_WIDTH = 4;
    localparam unsigned CHANNEL_WIDTH = 4;
    localparam unsigned COLOR_WIDTH = 3*CHANNEL_WIDTH;
    logic [COLOR_WIDTH-1:0] BG_COLOR = 'h137;

    // framebuffer (FB)
    localparam unsigned FB_DATA_WIDTH  = 4;
    localparam unsigned FB_DEPTH = SCREEN_WIDTH * SCREEN_HEIGHT;
    localparam unsigned FB_ADDR_WIDTH  = $clog2(FB_DEPTH);
    localparam string FB_IMAGE_FILE  = "../../image.mem";

    // pixel read address and color
    logic [FB_ADDR_WIDTH-1:0] buffer_addr_write;
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

        .o_fb_addr_write(buffer_addr_write),
        .o_fb_write_en(fb_write_enable),
        .o_fb_depth_data(w_depth_data),
        .o_fb_color_data(w_color_data),

        .finished(done)
    );

    localparam CLUT_WIDTH = 12;
    localparam CLUT_DEPTH = 16;
    localparam PALETTE_FILE = "../../palette.mem";

    logic [CHANNEL_WIDTH-1:0] red, green, blue;
    display #(
        .DISPLAY_WIDTH(SCREEN_WIDTH),
        .DISPLAY_HEIGHT(SCREEN_HEIGHT),
        .DISPLAY_COORD_WIDTH(ADDRWIDTH),
        .FB_DATA_WIDTH(FB_DATA_WIDTH),
        .DB_DATA_WIDTH(DATAWIDTH),
        .CHANNEL_WIDTH(CHANNEL_WIDTH),
        .PALETTE_FILE(PALETTE_FILE),
        .FB_IMAGE_FILE(FB_IMAGE_FILE)
    ) display_inst (
        .clk(clk_100m),
        .clk_pix(clk_pix),

        .buffer_addr_write(buffer_addr_write),
        .addr_inside_triangle(fb_write_enable),

        .i_fb_data(w_color_data),
        .i_db_data(w_depth_data),

        .clear(),
        .ready(),

        .o_red(red),
        .o_green(green),
        .o_blue(blue)
    ); 

    assign sdl_sx = display_inst.screen_x;
    assign sdl_sy = display_inst.screen_y;
    assign sdl_de = display_inst.de;
    assign frame = display_inst.frame;

    // SDL output (8 bits per colour channel)
    always_ff @(posedge clk_pix) begin
        sdl_r <= {2{red}};  // double signal width from 4 to 8 bits
        sdl_g <= {2{green}};
        sdl_b <= {2{blue}};
    end
endmodule
