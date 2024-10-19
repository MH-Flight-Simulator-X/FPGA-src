`timescale 1ns / 1ps

module top (
    input  wire logic clk,                 // clock
    input  wire logic sim_rst,             // sim reset
    output      logic [CORDW-1:0] sdl_sx,  // horizontal SDL position
    output      logic [CORDW-1:0] sdl_sy,  // vertical SDL position
    output      logic sdl_de,              // data enable (low in blanking interval)
    output      logic [7:0] sdl_r,         // 8-bit red
    output      logic [7:0] sdl_g,         // 8-bit green
    output      logic [7:0] sdl_b,         // 8-bit blue
    output      logic frame
    );

    // display sync signals and coordinates
    localparam CORDW = 16;  // signed coordinate width (bits)
    logic signed [CORDW-1:0] sx, sy;
    logic hsync, vsync;
    logic de;
    projectf_display_480p #(.CORDW(CORDW)) display_inst (
        .clk_pix(clk),
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
    localparam CHANW = 4;        // color channel width (bits)
    localparam COLRW = 3*CHANW;  // color width: three channels (bits)
    localparam BG_COLR = 'h137;  // background color

    // framebuffer (FB)
    localparam FB_WIDTH  = 160;  // framebuffer width in pixels
    localparam FB_HEIGHT = 120;  // framebuffer width in pixels
    localparam FB_PIXELS = FB_WIDTH * FB_HEIGHT;  // total pixels in buffer
    localparam FB_ADDRW  = $clog2(FB_PIXELS);  // address width
    localparam FB_DATAW  = 4;  // color bits per pixel
    localparam FB_IMAGE  = "image.mem";  // bitmap file

    // pixel read address and color
    logic [FB_ADDRW-1:0] fb_addr_read;
    logic [FB_ADDRW-1:0] fb_addr_write;
    logic [FB_DATAW-1:0] fb_colr_read;
    logic fb_write_enable;

    localparam signed X0 = 3;
    localparam signed Y0 = 4;
    localparam signed Z0 = 4;
    localparam signed X1 = 40;
    localparam signed Y1 = 90;
    localparam signed Z1 = 4;
    localparam signed X2 = 111;
    localparam signed Y2 = 20;
    localparam signed Z2 = 1000;

    localparam signed TILE_MIN_X = 0;
    localparam signed TILE_MIN_Y = 0;
    localparam signed TILE_MAX_X = 160;
    localparam signed TILE_MAX_Y = 120;

    logic [11:0] depth_data_in;

    rasterizer #(
        .VERTEX_WIDTH(CORDW),
        .FB_ADDR_WIDTH(FB_ADDRW),
        .FB_WIDTH(FB_WIDTH),
        .TILE_MIN_X(TILE_MIN_X),
        .TILE_MIN_Y(TILE_MIN_Y),
        .TILE_MAX_X(TILE_MAX_X),
        .TILE_MAX_Y(TILE_MAX_Y)
    ) rasterizer_inst (
        .clk,
        .rst(),

        .x0(X0),
        .y0(Y0),
        .z0(Z0),
        .x1(X1),
        .y1(Y1),
        .z1(Z1),
        .x2(X2),
        .y2(Y2),
        .z2(Z2),

        .fb_addr(fb_addr_write),
        .fb_write_enable(fb_write_enable),
        .depth_data(),
        .done()
    );

    // framebuffer memory
    framebuffer #(
        .FB_WIDTH(FB_WIDTH),
        .FB_HEIGHT(FB_HEIGHT),
        .DATA_WIDTH(FB_DATAW),
        .FILE(FB_IMAGE)
    ) fb_inst (
        .clk_write(clk),
        .clk_read(clk),
        .write_enable(fb_write_enable),
        .clear(),
        .ready(),
        .clear_value(),
        .addr_write(fb_addr_write),
        .addr_read(fb_addr_read),
        .data_in(),
        .data_out(fb_colr_read)
    );

    localparam DB_CLEAR_VALUE = 4095;
    localparam DB_DATA_WIDTH = 12;

    logic [FB_ADDRW-1:0] db_addr_read;
    //logic [FB_ADDRW-1:0] db_addr_write;
    logic [11:0] db_data_out;
    //logic db_write_enable = 1'b0;

    // depth buffer memory
    framebuffer #(
        .FB_WIDTH(FB_WIDTH),
        .FB_HEIGHT(FB_HEIGHT),
        .DATA_WIDTH(DB_DATA_WIDTH)
    ) db_inst (
        .clk_write(clk),
        .clk_read(clk),
        .write_enable(fb_write_enable),
        .clear(),
        .ready(),
        .clear_value(DB_CLEAR_VALUE),
        .addr_write(fb_addr_write),
        .addr_read(db_addr_read),
        .data_in(depth_data_in),
        .data_out(db_data_out)
    );
    

    // calculate framebuffer read address for display output
    logic read_fb;
    always_ff @(posedge clk) begin
        read_fb <= (sy >= 0 && sy < FB_HEIGHT && sx >= 0 && sx < FB_WIDTH);
        if (frame) begin  // reset address at start of frame
            fb_addr_read <= 0;
        end else if (read_fb) begin  // increment address in painting area
            fb_addr_read <= fb_addr_read + 1;
        end
    end

    logic read_db;
    always_ff @(posedge clk) begin
        read_db <= (sy >= 0 && sy < FB_HEIGHT && sx >= FB_WIDTH && sx < FB_WIDTH*2);
        if (frame) begin  // reset address at start of frame
            db_addr_read <= 0;
        end else if (read_db) begin  // increment address in painting area
            db_addr_read <= db_addr_read + 1;
        end
    end
    
    localparam CLUT_SIZE = 16;
    localparam CLUT_COLOR_WIDTH = 12;
    localparam PALETE_FILE = "palette.mem";
    
    // colour lookup table
    logic [COLRW-1:0] fb_pix_colr;
    clut #(
        .SIZE(CLUT_SIZE),
        .COLOR_WIDTH(CLUT_COLOR_WIDTH),
        .FILE(PALETE_FILE)
    ) clut_inst (
        .clk,
        .addr(fb_colr_read),
        .color(fb_pix_colr)
    );
    

    // paint screen
    logic paint_fb;
    logic paint_db;
    logic [CHANW-1:0] paint_r, paint_g, paint_b;  // color channels
    always_comb begin
        paint_fb = (sy >= 0 && sy < FB_HEIGHT && sx >= 0 && sx < FB_WIDTH);
        paint_db = (sy >= 0 && sy < FB_HEIGHT && sx >= FB_WIDTH && sx < FB_WIDTH*2);
        if (paint_fb) begin
            {paint_r, paint_g, paint_b} = fb_pix_colr;
        end
        else if (paint_db) begin
            //{paint_r, paint_g, paint_b} = {depth_data[3:0], 8'b00000000};
            {paint_r, paint_g, paint_b} = db_data_out;
        end
        else begin
            {paint_r, paint_g, paint_b} =  BG_COLR;
        end
    end

    // SDL output (8 bits per colour channel)
    always_ff @(posedge clk) begin
        sdl_sx <= sx;
        sdl_sy <= sy;
        sdl_de <= de;
        sdl_r <= {2{paint_r}};  // double signal width from 4 to 8 bits
        sdl_g <= {2{paint_g}};
        sdl_b <= {2{paint_b}};
    end
endmodule