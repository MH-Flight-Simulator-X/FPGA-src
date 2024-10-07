module rasterizer #(
    parameter VERTEX_WIDTH,
    parameter FB_ADDR_WIDTH,
    parameter signed [VERTEX_WIDTH-1:0] FB_WIDTH,
    parameter signed [VERTEX_WIDTH-1:0] FB_HEIGHT
) (
    input logic clk,
    input logic rst,

    input logic signed [VERTEX_WIDTH-1:0] x0,
    input logic signed [VERTEX_WIDTH-1:0] y0,
    input logic signed [VERTEX_WIDTH-1:0] x1,
    input logic signed [VERTEX_WIDTH-1:0] y1,
    input logic signed [VERTEX_WIDTH-1:0] x2,
    input logic signed [VERTEX_WIDTH-1:0] y2,

    output reg [FB_ADDR_WIDTH-1:0] fb_addr_write,
    output reg fb_write_enable,
    output reg done
); 

    // Registers to hold bounding box coordinates
    reg signed [VERTEX_WIDTH-1:0] min_x, max_x, min_y, max_y;

    // Registers to store whether part of the bounding box is inside framebuffer
    reg min_x_is_right_of_fb_start;
    reg max_x_is_right_of_fb_start;
    reg min_y_is_right_of_fb_start;
    reg max_y_is_right_of_fb_start;
    reg min_x_is_left_of_fb_end;
    reg max_x_is_left_of_fb_end;
    reg min_y_is_left_of_fb_end;
    reg max_y_is_left_of_fb_end;
    reg min_x_is_inside;
    reg min_y_is_inside;
    reg max_x_is_inside;
    reg max_y_is_inside;
    reg x_is_inside;
    reg y_is_inside;

    // Register to store a value used to jump to next line in bounding box
    reg [FB_ADDR_WIDTH-1:0] line_jump_value;

    // State machine for bounding box calculation and drawing
    typedef enum logic [3:0] {
        COMPUTE_BBOX_STAGE_1,
        COMPUTE_BBOX_STAGE_2,
        CHECK_BBOX_IS_INSIDE_STAGE_1,
        CHECK_BBOX_IS_INSIDE_STAGE_2,
        CHECK_BBOX_IS_INSIDE_STAGE_3,
        VERIFY_BBOX,
        CLAMP_BBOX,
        INIT_DRAW,
        DRAW,
        NEW_LINE,
        DONE
    } state_t;

    state_t state;

    reg [VERTEX_WIDTH-1:0] x, y;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            fb_write_enable <= 0;
            fb_addr_write <= 0;

            done <= 1'b0;

            state <= COMPUTE_BBOX_STAGE_1;
        end
        else begin
            case (state)
                COMPUTE_BBOX_STAGE_1: begin
                    // Calculate bbox for vertex 0 and 1
                    min_x <= (x0 < x1) ? x0 : x1;
                    max_x <= (x0 > x1) ? x0 : x1;
                    min_y <= (y0 < y1) ? y0 : y1;
                    max_y <= (y0 > y1) ? y0 : y1;

                    state <= COMPUTE_BBOX_STAGE_2;
                end

                COMPUTE_BBOX_STAGE_2: begin
                    // Calculate bbox for vertex 0, 1 and 2
                    min_x <= (min_x < x2) ? min_x : x2;
                    max_x <= (max_x > x2) ? max_x : x2;
                    min_y <= (min_y < y2) ? min_y : y2;
                    max_y <= (max_y > y2) ? max_y : y2;

                    state <= CHECK_BBOX_IS_INSIDE_STAGE_1;
                end

                CHECK_BBOX_IS_INSIDE_STAGE_1: begin
                    // Check if bbox corners appear after start of framebuffer
                    min_x_is_right_of_fb_start <= (0 <= min_x);
                    max_x_is_right_of_fb_start <= (0 <= max_x);
                    min_y_is_right_of_fb_start <= (0 <= min_x);
                    max_y_is_right_of_fb_start <= (0 <= max_y);

                    // Check if bbox corners appear before end of framebuffer
                    min_x_is_left_of_fb_end <= (min_x < FB_WIDTH);
                    min_y_is_left_of_fb_end <= (min_y < FB_HEIGHT);
                    max_x_is_left_of_fb_end <= (max_x < FB_WIDTH);
                    max_y_is_left_of_fb_end <= (max_y < FB_HEIGHT);

                    state <= CHECK_BBOX_IS_INSIDE_STAGE_2;
                end

                CHECK_BBOX_IS_INSIDE_STAGE_2: begin
                    // Check if bbox corners are inside of framebuffer
                    min_x_is_inside <= (min_x_is_right_of_fb_start && min_x_is_left_of_fb_end);
                    min_y_is_inside <= (min_y_is_right_of_fb_start && min_y_is_left_of_fb_end);
                    max_x_is_inside <= (max_x_is_right_of_fb_start && max_x_is_left_of_fb_end);
                    max_y_is_inside <= (max_y_is_right_of_fb_start && max_y_is_left_of_fb_end);

                    state <= CHECK_BBOX_IS_INSIDE_STAGE_3;
                end

                CHECK_BBOX_IS_INSIDE_STAGE_3: begin
                    // Check if either min or max points are inside framebuffer
                    x_is_inside <= (min_x_is_inside || max_x_is_inside);
                    y_is_inside <= (min_y_is_inside || max_y_is_inside);

                    state <= VERIFY_BBOX;
                end

                VERIFY_BBOX: begin
                    // Verify that at least one corner of bbox is inside framebuffer
                    if (x_is_inside && y_is_inside) begin
                        state <= CLAMP_BBOX;
                    end
                    else begin
                        // No computing is needed if the whole bbox is outside framebuffer
                        state <= DONE;
                    end
                end

                CLAMP_BBOX: begin
                    // Clamp bbox inside framebuffer
                    min_x <= (min_x < 0) ? 0 : min_x;
                    max_x <= (max_x > FB_WIDTH-1) ? FB_WIDTH-1 : max_x;
                    min_y <= (min_y < 0) ? 0 : min_y;
                    max_y <= (max_y > FB_HEIGHT-1) ? FB_HEIGHT-1 : max_y;

                    state <= INIT_DRAW;
                end

                INIT_DRAW: begin
                    x <= min_x;
                    y <= min_y;

                    line_jump_value <= FB_WIDTH[FB_ADDR_WIDTH-1:0] - (max_x[FB_ADDR_WIDTH-1:0] - min_x[FB_ADDR_WIDTH-1:0]);

                    state <= DRAW;
                end

                DRAW: begin
                    if (x < max_x) begin
                        fb_addr_write <= fb_addr_write + 1;
                        fb_write_enable <= 1'b1;
                        x <= x + 1;
                    end 
                    else begin
                        state <= NEW_LINE;
                    end 
                end

                NEW_LINE: begin
                    if (y < max_y) begin
                        y <= y + 1; 
                        fb_addr_write <= fb_addr_write + line_jump_value[FB_ADDR_WIDTH-1:0]; 

                        state <= DRAW;
                    end
                    else begin
                        state <= DONE;
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
