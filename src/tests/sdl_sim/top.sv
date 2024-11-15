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

    output logic signed [VERTEX_WIDTH-1:0] edge_val[3], 
    output logic signed [VERTEX_WIDTH-1:0] edge_delta[3][2], 

    output logic signed [VERTEX_WIDTH-1:0] edge0,
    output logic signed [VERTEX_WIDTH-1:0] edge1,
    output logic signed [VERTEX_WIDTH-1:0] edge2,

    output logic signed [VERTEX_WIDTH-1:0] area,
    output logic signed [RECIPROCAL_WIDTH-1:0] area_reciprocal,

    output logic signed [VERTEX_WIDTH+RECIPROCAL_WIDTH-1:0] bar_weight[3],
    output logic signed [VERTEX_WIDTH+RECIPROCAL_WIDTH-1:0] bar_weight_delta[3][2],

    output logic signed [VERTEX_WIDTH*2+RECIPROCAL_WIDTH-1:0] z,
    output logic signed [VERTEX_WIDTH*2+RECIPROCAL_WIDTH-1:0] z_dx,
    output logic signed [VERTEX_WIDTH*2+RECIPROCAL_WIDTH-1:0] z_dy,

    output logic signed [VERTEX_WIDTH-1:0] depth_data,
    output logic signed [VERTEX_WIDTH-1:0] z_delta[2],

    output logic unsigned [FB_ADDR_WIDTH-1:0] fb_addr_start,

    logic [3:0] state,
 
    output logic done
    );

    parameter VERTEX_WIDTH = 16;
    parameter RECIPROCAL_WIDTH = 12;

    // color parameters
    localparam CHANNEL_WIDTH = 4;
    localparam COLOR_WIDTH = 3*CHANNEL_WIDTH;
    localparam BG_COLOR = 'h137;

    // framebuffer (FB)
    localparam unsigned FB_WIDTH  = 160;
    localparam unsigned FB_HEIGHT = 120;
    localparam unsigned FB_DATA_WIDTH  = 4;
    localparam unsigned FB_DEPTH = FB_WIDTH * FB_HEIGHT;
    localparam unsigned FB_ADDR_WIDTH  = $clog2(FB_DEPTH);
    localparam string FB_IMAGE_FILE  = "../../image.mem";
    // pixel read address and color
    logic [FB_ADDR_WIDTH-1:0] buffer_addr_write;
    logic fb_write_enable;

    localparam signed X0 = 8;
    localparam signed Y0 = 4;
    // localparam signed Z0 = 16'sh0CCD; // 0.1
    localparam signed Z0 = 16'sh7333; // 0.5
    localparam signed X1 = 20;
    localparam signed Y1 = 30;
    // localparam signed Z1 = 16'sh199A; // 0.2
    localparam signed Z1 = 16'sh7333; // 0.5
    localparam signed X2 = 40;
    localparam signed Y2 = 20;
    localparam signed Z2 = 16'sh0CCD; // 0.1
    // localparam signed Z2 = 16'sh7333; // 0.5

    localparam signed TILE_MIN_X = 0;
    localparam signed TILE_MIN_Y = 0;
    localparam signed TILE_MAX_X = 160;
    localparam signed TILE_MAX_Y = 120;

    localparam CORDW = 16;  // signed coordinate width (bits)

    logic [11:0] depth_data_in;

    localparam unsigned RECIPROCAL_SIZE = 65000;
    localparam RECIPROCAL_FILE = "../../reciprocal.mem";

    localparam DB_DATA_WIDTH = 12;

    logic signed [VERTEX_WIDTH-1:0] vertex[3][3];

    initial begin
        vertex[0][0] = X0;
        vertex[0][1] = Y0;
        vertex[0][2] = Z0;
        
        vertex[1][0] = X1;
        vertex[1][1] = Y1;
        vertex[1][2] = Z1;

        vertex[2][0] = X2;
        vertex[2][1] = Y2;
        vertex[2][2] = Z2;
    end

    rasterizer #(
        .VERTEX_WIDTH(CORDW),
        .FB_ADDR_WIDTH(FB_ADDR_WIDTH),
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

        .vertex,

        .fb_addr(buffer_addr_write),
        .fb_write_enable(fb_write_enable),
        .depth_data(depth_data),
        .done
    );

    assign edge0 = rasterizer_inst.backend_inst.r_edge0;
    assign edge1 = rasterizer_inst.backend_inst.r_edge1;
    assign edge2 = rasterizer_inst.backend_inst.r_edge2;

    // assign edge_delta_0 = rasterizer_inst.backend_inst.r_edge0;
    // assign edge_delta_1 = rasterizer_inst.backend_inst.r_edge1;
    // assign edge_delta_2 = rasterizer_inst.backend_inst.r_edge2;

    assign min_x = rasterizer_inst.bb_tl[0];
    assign max_x = rasterizer_inst.bb_br[0];
    assign min_y = rasterizer_inst.bb_tl[1];
    assign max_y = rasterizer_inst.bb_br[1];

    assign edge_val = rasterizer_inst.edge_val;
    assign edge_delta = rasterizer_inst.edge_delta;

    assign area = rasterizer_inst.area;
    assign area_reciprocal = rasterizer_inst.area_reciprocal;
    
    assign bar_weight = rasterizer_inst.bar_weight;
    assign bar_weight_delta = rasterizer_inst.bar_weight_delta;

    assign z = rasterizer_inst.z;
    assign z_dx = rasterizer_inst.z_dx;
    assign z_dy = rasterizer_inst.z_dy;

    assign state = rasterizer_inst.state;

    assign depth_data_in = depth_data[VERTEX_WIDTH-1:VERTEX_WIDTH-DB_DATA_WIDTH];

    assign z_delta[0] = rasterizer_inst.z_delta[0];
    assign z_delta[1] = rasterizer_inst.z_delta[1];

    assign fb_addr_start = rasterizer_inst.fb_addr_start;  
    
    localparam CLUT_WIDTH = 12;
    localparam CLUT_DEPTH = 16;
    localparam PALETTE_FILE = "../../palette.mem";
 
    
    logic [CHANNEL_WIDTH-1:0] red, green, blue;
    display #(
        .DISPLAY_WIDTH(FB_WIDTH),
        .DISPLAY_HEIGHT(FB_HEIGHT),
        .DISPLAY_COORD_WIDTH(CORDW),
        .FB_DATA_WIDTH(FB_DATA_WIDTH),
        .DB_DATA_WIDTH(DB_DATA_WIDTH),
        .CHANNEL_WIDTH(CHANNEL_WIDTH),
        .PALETTE_FILE(PALETTE_FILE),
        .FB_IMAGE_FILE(FB_IMAGE_FILE)
    ) display_inst (
        .clk(clk_100m),
        .clk_pix(clk_pix),

        .buffer_addr_write(buffer_addr_write),

        .addr_inside_triangle(fb_write_enable),

        .i_depth_data(depth_data_in),

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
