`default_nettype none
`timescale 1ns / 1ps

module top_MH_FPGA (
    input  wire logic clk_100m,     // 100 MHz clock
    input  wire logic btn_rst_n,    // reset button
    input  wire logic [3:0] sw,
    input  wire logic [3:0] btn,
    output      logic vga_hsync,    // horizontal sync
    output      logic vga_vsync,    // vertical sync
    output      logic [3:0] vga_r,  // 4-bit VGA red
    output      logic [3:0] vga_g,  // 4-bit VGA green
    output      logic [3:0] vga_b,  // 4-bit VGA blue
    output      logic [3:0] led
    );

    // generate pixel clock
    logic clk_pix;
    logic clk_pix_locked;
    logic rst_pix;
    clock_480p clock_pix_inst (
       .clk_100m,
       .rst(!btn_rst_n),  // reset button is active low
       .clk_pix,
       /* verilator lint_off PINCONNECTEMPTY */
       .clk_pix_5x(),  // not used for VGA output
       /* verilator lint_on PINCONNECTEMPTY */
       .clk_pix_locked
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

    // colour parameters
    localparam CHANW = 4;        // colour channel width (bits)
    localparam COLRW = 3*CHANW;  // colour width: three channels (bits)
    localparam BG_COLR = 'h137;  // background colour

    // framebuffer (FB)
    localparam FB_WIDTH  = 160;  // framebuffer width in pixels
    localparam FB_HEIGHT = 120;  // framebuffer width in pixels
    localparam FB_PIXELS = FB_WIDTH * FB_HEIGHT;  // total pixels in buffer
    localparam FB_ADDRW  = $clog2(FB_PIXELS);  // address width
    localparam FB_DATAW  = 4;  // colour bits per pixel
    localparam FB_IMAGE  = "image.mem";  // bitmap file

    // pixel read address and colour
    logic [FB_ADDRW-1:0] fb_addr_read;
    logic [FB_ADDRW-1:0] fb_addr_write;
    logic [FB_DATAW-1:0] fb_colr_read;

    // framebuffer memory
    framebuffer #(
        .FB_WIDTH(FB_WIDTH),
        .FB_HEIGHT(FB_HEIGHT),
        .DATA_WIDTH(FB_DATAW),
        .FILE(FB_IMAGE)
    ) fb_inst (
        .clk_write(clk_100m),
        .clk_read(clk_pix),
        .write_enable(btn[0]),
        .clear(btn[1]),
        .clear_value(sw),
        .addr_write(fb_addr_write),
        .addr_read(fb_addr_read),
        .data_in(sw),
        .data_out(fb_colr_read)
    );
    
    localparam DIV_BY = 27'd100_000_000;  // 100 million

    logic stb;
    logic [26:0] cnt = 0;
    always_ff @(posedge clk_100m) begin
        if (cnt != DIV_BY-1) begin
            stb <= 0;
            cnt <= cnt + 1;
        end else begin
            stb <= 1;
            cnt <= 0;
        end
    end

    always_ff @(posedge clk_100m) begin
        if (stb) begin
            led <= led + 1;
            fb_addr_write <= fb_addr_write + 1;
        end
    end

    // calculate framebuffer read address for display output
    logic read_fb;
    always_ff @(posedge clk_pix) begin
        read_fb <= (sy >= 0 && sy < FB_HEIGHT && sx >= 0 && sx < FB_WIDTH);
        if (frame) begin  // reset address at start of frame
            fb_addr_read <= 0;
        end else if (read_fb) begin  // increment address in painting area
            fb_addr_read <= fb_addr_read + 1;
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
        .clk(clk_pix),
        .addr(fb_colr_read),
        .color(fb_pix_colr)
    );

    // paint screen
    logic paint_area;  // area of framebuffer to paint
    logic [CHANW-1:0] paint_r, paint_g, paint_b;  // colour channels
    always_comb begin
        paint_area = (sy >= 0 && sy < FB_HEIGHT && sx >= 0 && sx < FB_WIDTH);
        {paint_r, paint_g, paint_b} = paint_area ? fb_pix_colr : BG_COLR;
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