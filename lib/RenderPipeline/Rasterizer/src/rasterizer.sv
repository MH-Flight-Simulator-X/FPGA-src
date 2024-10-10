module rasterizer #(
    parameter VERTEX_WIDTH,
    parameter FB_ADDR_WIDTH,
    parameter [VERTEX_WIDTH-1:0] FB_WIDTH,
    parameter [VERTEX_WIDTH-1:0] FB_HEIGHT
    // parameter signed [VERTEX_WIDTH-1:0] TILE_MIN_X,
    // parameter signed [VERTEX_WIDTH-1:0] TILE_MAX_X,
    // parameter signed [VERTEX_WIDTH-1:0] TILE_MIN_Y,
    // parameter signed [VERTEX_WIDTH-1:0] TILE_MAX_Y
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
    logic signed [VERTEX_WIDTH-1:0] min_x, max_x, min_y, max_y;
    
    // logic to store a value used to jump to next line in bounding box
    logic [FB_ADDR_WIDTH-1:0] line_jump_value;

    // logic to store whether bounding box is inside framebuffer
    logic bounding_box_is_valid;

    localparam TILE_MIN_X = 0;
    localparam TILE_MIN_Y = 0;

    bounding_box #(
        .TILE_MIN_X(TILE_MIN_X),
        .TILE_MAX_X(FB_WIDTH),
        .TILE_MIN_Y(TILE_MIN_Y),
        .TILE_MAX_Y(FB_HEIGHT),

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

    // State machine
    typedef enum logic [3:0] {
        VERIFY_BBOX,
        INIT_DRAW,
        DRAW,
        NEW_LINE,
        DONE
    } state_t;

    state_t state;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            done <= 1'b0;

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

                    fb_addr <= (min_y[FB_ADDR_WIDTH-1:0]*FB_WIDTH[FB_ADDR_WIDTH-1:0]) + min_x[FB_ADDR_WIDTH-1:0];

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
