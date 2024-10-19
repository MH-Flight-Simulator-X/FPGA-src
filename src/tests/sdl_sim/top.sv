`timescale 1ns / 1ps

module top (
    input  wire logic clk_100m,            // 100MHz clock
    input  wire logic clk_pix,             // pixel clock
    input  wire logic sim_rst,             // sim reset
    output      logic [CORDW-1:0] sdl_sx,  // horizontal SDL position
    output      logic [CORDW-1:0] sdl_sy,  // vertical SDL position
    output      logic sdl_de,              // data enable (low in blanking interval)
    output      logic [7:0] sdl_r,         // 8-bit red
    output      logic [7:0] sdl_g,         // 8-bit green
    output      logic [7:0] sdl_b,         // 8-bit blue
    output      logic frame,

    output logic signed [CORDW-1:0] min_x,
    output logic signed [CORDW-1:0] max_x,
    output logic signed [CORDW-1:0] min_y,
    output logic signed [CORDW-1:0] max_y,

    output logic signed [VERTEX_WIDTH-1:0] e0,
    output logic signed [VERTEX_WIDTH-1:0] e1,
    output logic signed [VERTEX_WIDTH-1:0] e2,

    output logic signed [VERTEX_WIDTH-1:0] e0_dx, 
    output logic signed [VERTEX_WIDTH-1:0] e0_dy, 
    output logic signed [VERTEX_WIDTH-1:0] e1_dx, 
    output logic signed [VERTEX_WIDTH-1:0] e1_dy, 
    output logic signed [VERTEX_WIDTH-1:0] e2_dx, 
    output logic signed [VERTEX_WIDTH-1:0] e2_dy,
    output logic done
    );

    parameter VERTEX_WIDTH = 16;

    // display sync signals and coordinates
    localparam CORDW = 16;  // signed coordinate width (bits)
    logic signed [CORDW-1:0] sx, sy;
    logic hsync, vsync;
    logic de;
    projectf_display_480p #(.CORDW(CORDW)) display_inst (
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
    localparam CHANW = 4;        // color channel width (bits)
    localparam COLRW = 3*CHANW;  // color width: three channels (bits)
    localparam BG_COLR = 'h137;  // background color

    // framebuffer (FB)
    localparam FB_WIDTH  = 160;  // framebuffer width in pixels
    localparam FB_HEIGHT = 120;  // framebuffer width in pixels
    localparam FB_PIXELS = FB_WIDTH * FB_HEIGHT;  // total pixels in buffer
    localparam FB_ADDRW  = $clog2(FB_PIXELS);  // address width
    localparam FB_DATAW  = 4;  // color bits per pixel
    localparam FB_IMAGE  = "../../image.mem";  // bitmap file

    // pixel read address and color
    logic [FB_ADDRW-1:0] fb_addr_read;
    logic [FB_ADDRW-1:0] fb_addr_write;
    logic [FB_DATAW-1:0] fb_colr_read;
    logic fb_write_enable;

    localparam signed X0 = 12;
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

    localparam unsigned RECIPROCAL_SIZE = 65000;
    localparam string RECIPROCAL_FILE = "../../reciprocal.mem";

    rasterizer #(
        .VERTEX_WIDTH(CORDW),
        .FB_ADDR_WIDTH(FB_ADDRW),
        .FB_WIDTH(FB_WIDTH),
        .TILE_MIN_X(TILE_MIN_X),
        .TILE_MIN_Y(TILE_MIN_Y),
        .TILE_MAX_X(TILE_MAX_X),
        .TILE_MAX_Y(TILE_MAX_Y),
        .RECIPROCAL_SIZE(RECIPROCAL_SIZE),
        .RECIPROCAL_FILE(RECIPROCAL_FILE)
    ) rasterizer_inst (
        .clk(clk_100m),
        .rst(sim_rst),

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
        .done
    );

    assign min_x = rasterizer_inst.min_x;
    assign max_x = rasterizer_inst.max_x;
    assign min_y = rasterizer_inst.min_y;
    assign max_y = rasterizer_inst.max_y;

    assign e0 = rasterizer_inst.e0;
    assign e1 = rasterizer_inst.e1;
    assign e2 = rasterizer_inst.e2;

    assign e0_dx = rasterizer_inst.e0_dx;
    assign e0_dy = rasterizer_inst.e0_dy;
    assign e1_dx = rasterizer_inst.e1_dx;
    assign e1_dy = rasterizer_inst.e1_dy;
    assign e2_dx = rasterizer_inst.e2_dx;
    assign e2_dy = rasterizer_inst.e2_dy;

    // framebuffer memory
    framebuffer #(
        .FB_WIDTH(FB_WIDTH),
        .FB_HEIGHT(FB_HEIGHT),
        .DATA_WIDTH(FB_DATAW),
        .FILE(FB_IMAGE)
    ) fb_inst (
        .clk_write(clk_100m),
        .clk_read(clk_pix),
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
        .clk_write(clk_100m),
        .clk_read(clk_pix),
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
    always_ff @(posedge clk_pix) begin
        read_fb <= (sy >= 0 && sy < FB_HEIGHT && sx >= 0 && sx < FB_WIDTH);
        if (frame) begin  // reset address at start of frame
            fb_addr_read <= 0;
        end else if (read_fb) begin  // increment address in painting area
            fb_addr_read <= fb_addr_read + 1;
        end
    end

    logic read_db;
    always_ff @(posedge clk_pix) begin
        read_db <= (sy >= 0 && sy < FB_HEIGHT && sx >= FB_WIDTH && sx < FB_WIDTH*2);
        if (frame) begin  // reset address at start of frame
            db_addr_read <= 0;
        end else if (read_db) begin  // increment address in painting area
            db_addr_read <= db_addr_read + 1;
        end
    end
    
    localparam CLUT_SIZE = 16;
    localparam CLUT_COLOR_WIDTH = 12;
    localparam PALETE_FILE = "../../palette.mem";
    
    // colour lookup table
    logic [COLRW-1:0] fb_pix_colr;
    clut #(
        .SIZE(CLUT_SIZE),
        .COLOR_WIDTH(CLUT_COLOR_WIDTH),
        .FILE(PALETE_FILE)
    ) clut_inst (
        .clk(clk_100m),
        .addr(fb_colr_read),
        .color(fb_pix_colr)
    );
    

    // paint screen
    logic paint_db;
    logic paint_fb;
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
    always_ff @(posedge clk_pix) begin
        sdl_sx <= sx;
        sdl_sy <= sy;
        sdl_de <= de;
        sdl_r <= {2{paint_r}};  // double signal width from 4 to 8 bits
        sdl_g <= {2{paint_g}};
        sdl_b <= {2{paint_b}};
    end
endmodule
