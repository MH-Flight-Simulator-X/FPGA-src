`default_nettype none
`timescale 1ns / 1ps

module top_MH_FPGA (
    input  wire logic clk,     // 100 MHz clock
    output      logic vga_hsync,    // horizontal sync
    output      logic vga_vsync,    // vertical sync
    output      logic [3:0] vga_r,  // 4-bit VGA red
    output      logic [3:0] vga_g,  // 4-bit VGA green
    output      logic [3:0] vga_b  // 4-bit VGA blue
    );

    logic rstn;
    logic clk_100m;
    logic clk_100m_locked;

    clock_100Mhz clock_100m_inst (
        .clk(clk),
        .rst(1),
        .clk_100m(clk_100m),
        .clk_100m_5x(),
        .clk_100m_locked(clk_100m_locked)
    );
    always_ff @(posedge clk_100m) rstn <= !clk_100m_locked;

    // generate pixel clock
    logic clk_pix;
    logic clk_pix_locked;
    logic rst_pix;
    clock_480p clock_pix_inst (
       .clk(clk_100m),
       .rst(1),  // reset button is active low
       .clk_pix(clk_pix),
       .clk_pix_5x(),  // not used for VGA output
       .clk_pix_locked(clk_pix_locked)
    );
    always_ff @(posedge clk_pix) rst_pix <= !clk_pix_locked;  // wait for clock lock

    // display sync signals and coordinates
    localparam CORDW = 16;  // signed coordinate width (bits)
    logic signed [CORDW-1:0] sx, sy;
    logic hsync, vsync;
    logic de, frame;
    projectf_display_480p #(.CORDW(CORDW)) display_inst (
        .clk_pix,
        .rst_pix,
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
    // localparam FB_PIXELS = FB_WIDTH * FB_HEIGHT;  // total pixels in buffer
    // localparam FB_ADDRW  = $clog2(FB_PIXELS);  // address width
    // localparam FB_DATAW  = 4;  // color bits per pixel
    // localparam FB_IMAGE  = "image.mem";  // bitmap file

    // pixel read address and color
    // logic [FB_ADDRW-1:0] fb_addr_read;
    // logic [FB_ADDRW-1:0] fb_addr_write;
    // logic [FB_DATAW-1:0] fb_colr_read;
    // logic fb_write_enable;
    //
    // localparam signed X0 = 3;
    // localparam signed Y0 = 4;
    // localparam signed Z0 = 4;
    // localparam signed X1 = 40;
    // localparam signed Y1 = 90;
    // localparam signed Z1 = 4;
    // localparam signed X2 = 111;
    // localparam signed Y2 = 20;
    // localparam signed Z2 = 1000;
    //
    // localparam signed TILE_MIN_X = 0;
    // localparam signed TILE_MIN_Y = 0;
    // localparam signed TILE_MAX_X = 160;
    // localparam signed TILE_MAX_Y = 120;
    //
    // logic [11:0] depth_data_in;
    //
    // rasterizer #(
    //     .VERTEX_WIDTH(CORDW),
    //     .FB_ADDR_WIDTH(FB_ADDRW),
    //     .FB_WIDTH(FB_WIDTH),
    //     .TILE_MIN_X(TILE_MIN_X),
    //     .TILE_MIN_Y(TILE_MIN_Y),
    //     .TILE_MAX_X(TILE_MAX_X),
    //     .TILE_MAX_Y(TILE_MAX_Y)
    // ) rasterizer_inst (
    //     .clk(clk_100m),
    //     .rst(!rstn),
    //
    //     .x0(X0),
    //     .y0(Y0),
    //     .z0(Z0),
    //     .x1(X1),
    //     .y1(Y1),
    //     .z1(Z1),
    //     .x2(X2),
    //     .y2(Y2),
    //     .z2(Z2),
    //
    //     .fb_addr(fb_addr_write),
    //     .fb_write_enable(fb_write_enable),
    //     .depth_data(depth_data_in),
    //     .done()
    // );
    //
    // // framebuffer memory
    // buffer #(
    //     .FB_WIDTH(FB_WIDTH),
    //     .FB_HEIGHT(FB_HEIGHT),
    //     .DATA_WIDTH(FB_DATAW),
    //     .FILE(FB_IMAGE)
    // ) fb_inst (
    //     .clk_write(clk_100m),
    //     .clk_read(clk_pix),
    //     .write_enable(fb_write_enable),
    //     .clear(),
    //     .clear_value(),
    //     .addr_write(fb_addr_write),
    //     .addr_read(fb_addr_read),
    //     .data_in(),
    //     .data_out(fb_colr_read)
    // );
    //
    // localparam DB_CLEAR_VALUE = 4095;
    // localparam DB_DATA_WIDTH = 12;
    //
    // logic [FB_ADDRW-1:0] db_addr_read;
    //logic [FB_ADDRW-1:0] db_addr_write;
    // logic [11:0] db_data_out;
    //logic db_write_enable = 1'b0;

    // depth buffer memory
    // buffer #(
    //     .FB_WIDTH(FB_WIDTH),
    //     .FB_HEIGHT(FB_HEIGHT),
    //     .DATA_WIDTH(DB_DATA_WIDTH)
    // ) db_inst (
    //     .clk_write(clk_100m),
    //     .clk_read(clk_pix),
    //     .write_enable(fb_write_enable),
    //     .clear(),
    //     .clear_value(DB_CLEAR_VALUE),
    //     .addr_write(fb_addr_write),
    //     .addr_read(db_addr_read),
    //     .data_in(depth_data_in),
    //     .data_out(db_data_out)
    // );


    // calculate framebuffer read address for display output
    // logic read_fb;
    // always_ff @(posedge clk_pix) begin
    //     read_fb <= (sy >= 0 && sy < FB_HEIGHT && sx >= 0 && sx < FB_WIDTH);
    //     if (frame) begin  // reset address at start of frame
    //         fb_addr_read <= 0;
    //     end else if (read_fb) begin  // increment address in painting area
    //         fb_addr_read <= fb_addr_read + 1;
    //     end
    // end
    //
    // logic read_db;
    // always_ff @(posedge clk_pix) begin
    //     read_db <= (sy >= 0 && sy < FB_HEIGHT && sx >= FB_WIDTH && sx < FB_WIDTH*2);
    //     if (frame) begin  // reset address at start of frame
    //         db_addr_read <= 0;
    //     end else if (read_db) begin  // increment address in painting area
    //         db_addr_read <= db_addr_read + 1;
    //     end
    // end
    //
    // localparam CLUT_SIZE = 16;
    // localparam CLUT_COLOR_WIDTH = 12;
    // localparam PALETE_FILE = "palette.mem";

    // colour lookup table
    // logic [COLRW-1:0] fb_pix_colr;
    // clut #(
    //     .SIZE(CLUT_SIZE),
    //     .COLOR_WIDTH(CLUT_COLOR_WIDTH),
    //     .FILE(PALETE_FILE)
    // ) clut_inst (
    //     .clk(clk_pix),
    //     .addr(fb_colr_read),
    //     .color(fb_pix_colr)
    // );


    // paint screen
    logic paint_fb;
    logic paint_db;
    logic [CHANW-1:0] paint_r, paint_g, paint_b;  // color channels
    always_comb begin
        paint_fb = (sy >= 0 && sy < FB_HEIGHT && sx >= 0 && sx < FB_WIDTH);
        paint_db = (sy >= 0 && sy < FB_HEIGHT && sx >= FB_WIDTH && sx < FB_WIDTH*2);
        if (paint_fb) begin
            // {paint_r, paint_g, paint_b} = fb_pix_colr;
            {paint_r, paint_g, paint_b} = 12'b111100000000;
        end
        else if (paint_db) begin
            //{paint_r, paint_g, paint_b} = {depth_data[3:0], 8'b00000000};
            // {paint_r, paint_g, paint_b} = db_data_out;
            {paint_r, paint_g, paint_b} = 12'b000011110000;
        end
        else begin
            {paint_r, paint_g, paint_b} =  BG_COLR;
        end
    end

    // display colour: paint colour but black in blanking interval
    logic [CHANW-1:0] display_r, display_g, display_b;
    always_comb {display_r, display_g, display_b} = (de) ? {paint_r, paint_g, paint_b} : 0;

    // VGA Pmod output
    always_ff @(posedge clk_pix) begin
        vga_hsync <= hsync;
        vga_vsync <= vsync;
        vga_r <= display_r;
        vga_g <= display_g;
        vga_b <= display_b;
    end
endmodule
