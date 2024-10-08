module bounding_box #(
    parameter signed TILE_MIN_X = 0,
    parameter signed TILE_MAX_X = 32,
    parameter signed TILE_MIN_Y = 0,
    parameter signed TILE_MAX_Y = 16,
    parameter COORD_WIDTH = 10
) (
    input logic signed [COORD_WIDTH-1:0] x0,
    input logic signed [COORD_WIDTH-1:0] y0,
    input logic signed [COORD_WIDTH-1:0] x1,
    input logic signed [COORD_WIDTH-1:0] y1,
    input logic signed [COORD_WIDTH-1:0] x2,
    input logic signed [COORD_WIDTH-1:0] y2, 

    output logic signed [COORD_WIDTH-1:0] min_x,
    output logic signed [COORD_WIDTH-1:0] max_x,
    output logic signed [COORD_WIDTH-1:0] min_y,
    output logic signed [COORD_WIDTH-1:0] max_y,

    output logic valid
);

    // logic to store intermediate bbox coordinates
    logic signed [COORD_WIDTH-1:0] i_min_x, i_max_x, i_min_y, i_max_y;

    always_comb begin
        // Calculate bbox of vertex 0, 1 and 2
        i_min_x = (x0 < x1) ? ((x0 < x2) ? x0 : x2) : ((x1 < x2) ? x1 : x2);
        i_max_x = (x0 > x1) ? ((x0 > x2) ? x0 : x2) : ((x1 > x2) ? x1 : x2);
        i_min_y = (y0 < y1) ? ((y0 < y2) ? y0 : y2) : ((y1 < y2) ? y1 : y2);
        i_max_y = (y0 > y1) ? ((y0 > y2) ? y0 : y2) : ((y1 > y2) ? y1 : y2);

        // Clamp min and max values of bbox to edges tile
        min_x = (i_min_x < TILE_MIN_X) ? TILE_MIN_X : i_min_x;
        max_x = (i_max_x > TILE_MAX_X) ? TILE_MAX_X : i_max_x;
        min_y = (i_min_y < TILE_MIN_Y) ? TILE_MIN_Y : i_min_y;
        max_y = (i_max_y > TILE_MAX_Y) ? TILE_MAX_Y : i_max_y;

        // Check if bbox is inside tile
        valid = (min_x < max_x) && (min_y < max_y);
    end

endmodule

