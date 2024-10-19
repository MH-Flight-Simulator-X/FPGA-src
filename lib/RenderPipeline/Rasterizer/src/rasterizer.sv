`default_nettype none
`timescale 1ns / 1ps

module rasterizer #(
    parameter VERTEX_WIDTH = 16,
    parameter FB_ADDR_WIDTH = 4,
    parameter [VERTEX_WIDTH-1:0] FB_WIDTH = 32,
    parameter signed [VERTEX_WIDTH-1:0] TILE_MIN_X = 0,
    parameter signed [VERTEX_WIDTH-1:0] TILE_MAX_X = 32,
    parameter signed [VERTEX_WIDTH-1:0] TILE_MIN_Y = 0,
    parameter signed [VERTEX_WIDTH-1:0] TILE_MAX_Y = 16
) (
    input logic clk,
    input logic rst,

    input logic signed [VERTEX_WIDTH-1:0] x0,
    input logic signed [VERTEX_WIDTH-1:0] y0,
    input logic signed [VERTEX_WIDTH-1:0] z0,
    input logic signed [VERTEX_WIDTH-1:0] x1,
    input logic signed [VERTEX_WIDTH-1:0] y1,
    input logic signed [VERTEX_WIDTH-1:0] z1,
    input logic signed [VERTEX_WIDTH-1:0] x2,
    input logic signed [VERTEX_WIDTH-1:0] y2,
    input logic signed [VERTEX_WIDTH-1:0] z2,

    output logic [FB_ADDR_WIDTH-1:0] fb_addr,
    output logic fb_write_enable,
    output logic [VERTEX_WIDTH-1:0] depth_data,
    output logic done
); 

    localparam RECIPROCAL_WIDTH = 12;
    localparam Z_WIDTH = VERTEX_WIDTH * 2 + RECIPROCAL_WIDTH;
    localparam SHIFT_AMOUNT = VERTEX_WIDTH + RECIPROCAL_WIDTH;

    // Logic to store x and y coordinates while drawing
    logic signed [VERTEX_WIDTH-1:0] x, y;
    logic signed [Z_WIDTH-1:0] z, z_dx, z_dy, z_row_start;

    // Adjust the assignment to depth_data
    assign depth_data = z[Z_WIDTH - 1 : SHIFT_AMOUNT];

    // logic to store bounding box coordinates
    logic signed [VERTEX_WIDTH-1:0] min_x, max_x, min_y, max_y;
    
    // edge functions
    logic signed [VERTEX_WIDTH-1:0] e0, e1, e2; 
    logic signed [VERTEX_WIDTH-1:0] e0_row_start, e1_row_start, e2_row_start;
    logic signed [VERTEX_WIDTH-1:0] e0_dx, e0_dy, e1_dx, e1_dy, e2_dx, e2_dy;

    // barycentric weights
    logic signed [VERTEX_WIDTH + RECIPROCAL_WIDTH-1:0] w0, w1, w2;
    logic signed [VERTEX_WIDTH + RECIPROCAL_WIDTH-1:0] w0_dx, w0_dy, w1_dx, w1_dy, w2_dx, w2_dy;

    // logic to store a value used to jump to next line in bounding box
    logic [FB_ADDR_WIDTH-1:0] line_jump_value;

    // logic to store whether bounding box is inside tile
    logic bounding_box_is_valid;

    bounding_box #(
        .TILE_MIN_X(TILE_MIN_X),
        .TILE_MAX_X(TILE_MAX_X),
        .TILE_MIN_Y(TILE_MIN_Y),
        .TILE_MAX_Y(TILE_MAX_Y),

        .COORD_WIDTH(VERTEX_WIDTH)
    ) bounding_box_inst (
        .x0(x0),
        .y0(y0),
        .x1(x1),
        .y1(y1),
        .x2(x2),
        .y2(y2),

        .min_x(min_x),
        .max_x(max_x),
        .min_y(min_y),
        .max_y(max_y),

        .valid(bounding_box_is_valid)
    );

    localparam RECIPROCAL_SIZE = 65000;
    localparam RECIPROCAL_FILE = "reciprocal.mem";

    logic [RECIPROCAL_WIDTH-1:0] area_reciprocal;
    logic [VERTEX_WIDTH-1:0] area;

    clut #(
        .SIZE(RECIPROCAL_SIZE),
        .COLOR_WIDTH(RECIPROCAL_WIDTH),
        .FILE(RECIPROCAL_FILE)
    ) reciprocal_inst (
        .clk(clk),
        .addr(area),
        .color(area_reciprocal)
    );

    function signed [VERTEX_WIDTH-1:0] edge_function (
        input signed [VERTEX_WIDTH-1:0] v1_x,
        input signed [VERTEX_WIDTH-1:0] v1_y,
        input signed [VERTEX_WIDTH-1:0] v2_x,
        input signed [VERTEX_WIDTH-1:0] v2_y,
        input signed [VERTEX_WIDTH-1:0] p_x,
        input signed [VERTEX_WIDTH-1:0] p_y
    );
        edge_function = (p_x - v1_x) * (v2_y - v1_y) - (p_y - v1_y) * (v2_x - v1_x);
    endfunction


    // State machine
    typedef enum logic [3:0] {
        VERIFY_BBOX,
        INIT_DRAW,
        INIT_DRAW_2,
        INIT_DRAW_3,
        INIT_DRAW_4,
        DRAW,
        DONE
    } state_t;

    state_t state;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            done <= 1'b0;
            fb_write_enable <= 1'b0;

            state <= VERIFY_BBOX;
        end
        else begin
            case (state)
                VERIFY_BBOX: begin
                    if (bounding_box_is_valid) begin
                        state <= INIT_DRAW;
                    end
                    else begin
                        state <= DONE;
                    end
                end 

                INIT_DRAW: begin
                    x <= min_x;
                    y <= min_y;

                    line_jump_value <= FB_WIDTH[FB_ADDR_WIDTH-1:0] - (max_x[FB_ADDR_WIDTH-1:0] - min_x[FB_ADDR_WIDTH-1:0]);

                    fb_addr <= (min_y[FB_ADDR_WIDTH-1:0]*FB_WIDTH[FB_ADDR_WIDTH-1:0]) + min_x[FB_ADDR_WIDTH-1:0] - 1;

                    e0 <= edge_function(x0, y0, x1, y1, min_x, min_y);
                    e1 <= edge_function(x1, y1, x2, y2, min_x, min_y);
                    e2 <= edge_function(x2, y2, x0, y0, min_y, min_x);

                    e0_dx <= y1 - y0;
                    e0_dy <= -(x1 - x0);

                    e1_dx <= y2 - y1; 
                    e1_dy <= -(x2 - x1);

                    e2_dx <= y0 - y2;
                    e2_dy <= -(x0 - x2);

                    area <= edge_function(x0, y0, x1, y1, x2, y2);

                    state <= INIT_DRAW_2;
                end

                INIT_DRAW_2: begin
                    e0_row_start <= e0;
                    e1_row_start <= e1;
                    e2_row_start <= e2;

                    // Compute barycentric weights at top-left corner of bounding box
                    w0 <= e0 * area_reciprocal;
                    w1 <= e1 * area_reciprocal;
                    w2 <= e2 * area_reciprocal;

                    // Compute increments for barycentric weights
                    w0_dx <= e0_dx * area_reciprocal; 
                    w0_dy <= e0_dy * area_reciprocal;

                    w1_dx <= e1_dx * area_reciprocal;
                    w1_dy <= e1_dy * area_reciprocal;

                    w2_dx <= e2_dx * area_reciprocal;
                    w2_dy <= e2_dy * area_reciprocal;

                    state <= INIT_DRAW_3;
                end

                INIT_DRAW_3: begin
                    // Initialize z at the top-left corner
                    z <= (w0 * z0) + (w1 * z1) + (w2 * z2);

                    // Compute z increments
                    z_dx <= (w0_dx * z0) + (w1_dx * z1) + (w2_dx * z2);
                    z_dy <= (w0_dy * z0) + (w1_dy * z1) + (w2_dy * z2);

                    state <= INIT_DRAW_4;
                end

                INIT_DRAW_4: begin
                    z_row_start <= z;

                    state <= DRAW;
                end

                DRAW: begin
                    if (x < max_x) begin
                        fb_addr <= fb_addr + 1;

                        e0 <= e0 + e0_dx;
                        e1 <= e1 + e1_dx;
                        e2 <= e2 + e2_dx; 

                        x <= x + 1;

                        z <= z + z_dx;

                        if (e0 + e0_dx > 0 && e1 + e1_dx > 0 && e2 + e2_dx > 0) begin
                            fb_write_enable <= 1'b1;
                        end
                        else begin
                            fb_write_enable <= 1'b0;
                        end
                    end 
                    else begin
                        if (y < max_y) begin
                            e0 <= e0_row_start + e0_dy;
                            e1 <= e1_row_start + e1_dy;
                            e2 <= e2_row_start + e2_dy;

                            e0_row_start <= e0_row_start + e0_dy;
                            e1_row_start <= e1_row_start + e1_dy;
                            e2_row_start <= e2_row_start + e2_dy;

                            y <= y + 1; 
                            fb_addr <= fb_addr + line_jump_value[FB_ADDR_WIDTH-1:0]; 

                            x <= min_x;

                            z_row_start <= z_row_start + z_dy;
                            z <= z_row_start + z_dy;

                            if (e0_row_start + e0_dy > 0 && e1_row_start + e1_dy > 0 && e2_row_start + e2_dy > 0) begin
                                    fb_write_enable <= 1'b1;
                            end
                            else begin
                                fb_write_enable <= 1'b0;
                            end
                        end
                        else begin
                            done <= 1'b1;
                            state <= DONE;
                        end
                    end 
                end

                DONE: begin
                    fb_write_enable <= 1'b0;
                    done <= 1'b1; 
                    state <= DONE;
                end

                default: state <= DONE;

            endcase
        end
    end
endmodule

