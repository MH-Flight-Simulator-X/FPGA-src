`default_nettype none
`timescale 1ns / 1ps

module rasterizer #(
    parameter unsigned VERTEX_WIDTH = 16,
    parameter unsigned FB_ADDR_WIDTH = 15,
    parameter unsigned [VERTEX_WIDTH-1:0] FB_WIDTH = 160,
    parameter signed [VERTEX_WIDTH-1:0] TILE_MIN_X = 0,
    parameter signed [VERTEX_WIDTH-1:0] TILE_MAX_X = 160,
    parameter signed [VERTEX_WIDTH-1:0] TILE_MIN_Y = 0,
    parameter signed [VERTEX_WIDTH-1:0] TILE_MAX_Y = 120,
    parameter unsigned RECIPROCAL_SIZE = 65000,
    parameter string RECIPROCAL_FILE = "reciprocal.mem"
) (
    input logic clk,
    input logic rst,

    input logic signed [VERTEX_WIDTH-1:0] vertex[3][3], 

    output logic [FB_ADDR_WIDTH-1:0] fb_addr,
    output logic signed [VERTEX_WIDTH-1:0] depth_data,

    output logic fb_write_enable,
    output logic done
);

    localparam unsigned RECIPROCAL_WIDTH = 12;
    localparam unsigned Z_WIDTH = VERTEX_WIDTH * 2 + RECIPROCAL_WIDTH;

    // Logic to store x and y coordinates while drawing
    logic signed [VERTEX_WIDTH-1:0] x, y;
    logic signed [Z_WIDTH-1:0] z, z_dx, z_dy, z_row_start;

    // Adjust the assignment to depth_data
    assign depth_data = z[27:12];

    // logic to store bounding box coordinates
    logic signed [VERTEX_WIDTH-1:0] min_x, max_x, min_y, max_y;

    // edge functions
    logic signed [VERTEX_WIDTH-1:0] edge_val[3];
    logic signed [VERTEX_WIDTH-1:0] edge_row_start[3];
    logic signed [VERTEX_WIDTH-1:0] edge_delta[3][2];

    // barycentric weights
    logic signed [VERTEX_WIDTH + RECIPROCAL_WIDTH-1:0] bar_weight[3];
    logic signed [VERTEX_WIDTH + RECIPROCAL_WIDTH-1:0] bar_weight_delta[3][2];

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
        .x0(vertex[0][0]),
        .y0(vertex[0][1]),
        .x1(vertex[1][0]),
        .y1(vertex[1][1]),
        .x2(vertex[2][0]),
        .y2(vertex[2][1]),

        .min_x(min_x),
        .max_x(max_x),
        .min_y(min_y),
        .max_y(max_y),

        .valid(bounding_box_is_valid)
    );

    logic signed [RECIPROCAL_WIDTH-1:0] area_reciprocal;
    logic signed [VERTEX_WIDTH-1:0] area;

    clut #(
        .SIZE(RECIPROCAL_SIZE),
        .COLOR_WIDTH(RECIPROCAL_WIDTH),
        .FILE(RECIPROCAL_FILE)
    ) reciprocal_inst (
        .clk(clk),
        .addr(area),
        .color(area_reciprocal)
    );

    function automatic signed [VERTEX_WIDTH-1:0] edge_function (
        input logic signed [VERTEX_WIDTH-1:0] v1_x,
        input logic signed [VERTEX_WIDTH-1:0] v1_y,
        input logic signed [VERTEX_WIDTH-1:0] v2_x,
        input logic signed [VERTEX_WIDTH-1:0] v2_y,
        input logic signed [VERTEX_WIDTH-1:0] p_x,
        input logic signed [VERTEX_WIDTH-1:0] p_y
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
        INIT_DRAW_5,
        DRAW,
        DONE
    } state_t;

    state_t state;

    localparam int cycle_map[3] = '{1, 2, 0};  // Maps to the next value in a cycle (0 -> 1 -> 2 -> 0)

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

                    foreach (edge_val[i]) begin
                        // Compute edge values using cyclic vertex pairs
                        edge_val[i] <= edge_function(vertex[i][0], vertex[i][1], vertex[cycle_map[i]][0], vertex[cycle_map[i]][1], min_x, min_y);

                        // Compute edge deltas
                        edge_delta[i][0] <= vertex[cycle_map[i]][1] - vertex[i][1];
                        edge_delta[i][1] <= -(vertex[cycle_map[i]][0] - vertex[i][0]);
                    end

                    area <= edge_function(vertex[0][0], vertex[0][1], vertex[1][0], vertex[1][1], vertex[2][0], vertex[2][1]);

                    state <= INIT_DRAW_2;
                end

                INIT_DRAW_2: begin
                    // Wait for reciprocal_area
                    state <= INIT_DRAW_3;
                end

                INIT_DRAW_3: begin
                    foreach (edge_row_start[i]) begin
                        edge_row_start[i] <= edge_val[i];
                    end

                    // Compute barycentric weights at top-left corner of bounding box
                    foreach (bar_weight[i]) begin
                        bar_weight[i] <= edge_val[i] * area_reciprocal;
                        // bar_weight[i] <= edge_val[i] * 6;
                    end

                    // Compute increments for barycentric weights
                    foreach (bar_weight_delta[i]) begin
                        bar_weight_delta[i][0] <= edge_delta[i][0] * area_reciprocal;
                        bar_weight_delta[i][1] <= edge_delta[i][1] * area_reciprocal;
                    end

                    state <= INIT_DRAW_4;
                end

                INIT_DRAW_4: begin
                    // Initialize z at the top-left corner
                    z <= (bar_weight[0] * vertex[0][2]) + (bar_weight[1] * vertex[1][2]) + (bar_weight[2] * vertex[2][2]);

                    // Compute z increments
                    z_dx <= (bar_weight_delta[0][0] * vertex[0][2]) + (bar_weight_delta[1][0] * vertex[1][2]) + (bar_weight_delta[2][0] * vertex[2][2]);
                    z_dy <= (bar_weight_delta[0][1] * vertex[0][2]) + (bar_weight_delta[1][1] * vertex[1][2]) + (bar_weight_delta[2][1] * vertex[2][2]);

                    state <= INIT_DRAW_5;
                end

                INIT_DRAW_5: begin
                    z_row_start <= z;

                    state <= DRAW;
                end

                DRAW: begin
                    if (x < max_x) begin
                        fb_addr <= fb_addr + 1;
                        
                        foreach (edge_val[i]) begin
                            edge_val[i] <= edge_val[i] + edge_delta[i][0];
                        end

                        x <= x + 1;

                        z <= z + z_dx;

                        if (edge_val[0] + edge_delta[0][0] > 0 && edge_val[1] + edge_delta[1][0] > 0 && edge_val[2] + edge_delta[2][0] > 0) begin
                            fb_write_enable <= 1'b1;
                        end
                        else begin
                            fb_write_enable <= 1'b0;
                        end
                    end
                    else begin
                        if (y < max_y) begin
                            foreach (edge_val[i]) begin
                                edge_val[i] <= edge_row_start[i] + edge_delta[i][1];
                                edge_row_start[i] <= edge_row_start[i] + edge_delta[i][1];
                            end

                            y <= y + 1;
                            fb_addr <= fb_addr + line_jump_value[FB_ADDR_WIDTH-1:0];

                            x <= min_x;

                            z_row_start <= z_row_start + z_dy;
                            z <= z_row_start + z_dy;

                            if (edge_row_start[0] + edge_delta[0][1] > 0 && edge_row_start[1] + edge_delta[1][1] > 0 && edge_row_start[2] + edge_delta[2][1] > 0) begin
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

