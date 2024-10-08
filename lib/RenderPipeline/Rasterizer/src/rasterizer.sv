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

    output logic [FB_ADDR_WIDTH-1:0] fb_addr,
    output logic fb_write_enable,
    output logic done
); 

    // logic to store x and y coordinates while drawing
    logic signed [VERTEX_WIDTH-1:0] x, y;

    // logic to store bounding box coordinates
    logic signed [VERTEX_WIDTH-1:0] i_min_x, i_max_x, i_min_y, i_max_y;
    logic signed [VERTEX_WIDTH-1:0] min_x, max_x, min_y, max_y;
    
    // logic to store a value used to jump to next line in bounding box
    logic [FB_ADDR_WIDTH-1:0] line_jump_value;

    // logic to store whether bounding box is inside framebuffer
    logic bbox_is_valid;

    // State machine for bounding box calculation and drawing
    typedef enum logic [3:0] {
        VERIFY_BBOX,
        INIT_DRAW,
        DRAW,
        NEW_LINE,
        DONE
    } state_t;

    state_t state;

    always_comb begin
        // Calculate bbox of vertex 0, 1 and 2
        i_min_x = (x0 < x1) ? ((x0 < x2) ? x0 : x2) : ((x1 < x2) ? x1 : x2);
        i_max_x = (x0 > x1) ? ((x0 > x2) ? x0 : x2) : ((x1 > x2) ? x1 : x2);
        i_min_y = (y0 < y1) ? ((y0 < y2) ? y0 : y2) : ((y1 < y2) ? y1 : y2);
        i_max_y = (y0 > y1) ? ((y0 > y2) ? y0 : y2) : ((y1 > y2) ? y1 : y2);

        // Clamp min and max values of bbox to edges of framebuffer
        min_x = (i_min_x < 0) ? 0 : i_min_x;
        max_x = (i_max_x > FB_WIDTH-1) ? FB_WIDTH-1 : i_max_x;
        min_y = (i_min_y < 0) ? 0 : i_min_y;
        max_y = (i_max_y > FB_HEIGHT-1) ? FB_HEIGHT-1 : i_max_y;

        // Check if bbox is inside of framebuffer
        bbox_is_valid = (min_x < max_x) && (min_y < max_y);
    end

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            done <= 1'b0;

            state <= VERIFY_BBOX;
        end
        else begin
            case (state)
                VERIFY_BBOX: begin
                    if (bbox_is_valid) begin
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

                    fb_addr <= (y[FB_ADDR_WIDTH-1:0]*FB_WIDTH[FB_ADDR_WIDTH-1:0]) + x[FB_ADDR_WIDTH-1:0];

                    state <= DRAW;
                end

                DRAW: begin
                    if (x < max_x) begin
                        fb_addr <= fb_addr + 1;
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
                        fb_addr <= fb_addr + line_jump_value[FB_ADDR_WIDTH-1:0]; 

                        x <= min_x;

                        state <= DRAW;
                    end
                    else begin
                        done <= 1'b1;
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
