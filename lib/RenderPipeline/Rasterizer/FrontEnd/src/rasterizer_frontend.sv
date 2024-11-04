`timescale 1ns / 1ps

module rasterizer_frontend #(
    parameter unsigned DATAWIDTH = 12,
    parameter signed [DATAWIDTH-1:0] SCREEN_MIN_X = 0,
    parameter signed [DATAWIDTH-1:0] SCREEN_MAX_X = 320,
    parameter signed [DATAWIDTH-1:0] SCREEN_MIN_Y = 0,
    parameter signed [DATAWIDTH-1:0] SCREEN_MAX_Y = 320
    ) (
    input logic clk,
    input logic rstn,

    output logic ready,
    input logic next,       // Can safely output next triangle

    input logic signed [DATAWIDTH-1:0] i_v0[3],
    input logic signed [DATAWIDTH-1:0] i_v1[3],
    input logic signed [DATAWIDTH-1:0] i_v2[3],
    input logic i_triangle_dv,

    output logic signed [DATAWIDTH-1:0] bb_tl[2],
    output logic signed [DATAWIDTH-1:0] bb_br[2],
    output logic signed [DATAWIDTH-1:0] edge_val0,
    output logic signed [DATAWIDTH-1:0] edge_val1,
    output logic signed [DATAWIDTH-1:0] edge_val2,

    output logic signed [DATAWIDTH-1:0] edge_delta0[2],
    output logic signed [DATAWIDTH-1:0] edge_delta1[2],
    output logic signed [DATAWIDTH-1:0] edge_delta2[2],
    output logic signed [DATAWIDTH-1:0] area_inv,
    output logic o_dv
    );

    // For now, just set sample point at (0,0)
    localparam logic signed [DATAWIDTH-1:0] P0[2] = '{0, 0};

    // Register input data
    logic signed [DATAWIDTH-1:0] r_v0[3];
    logic signed [DATAWIDTH-1:0] r_v1[3];
    logic signed [DATAWIDTH-1:0] r_v2[3];

    // Edge function data registers
    logic signed [DATAWIDTH-1:0] r_edge_val0;
    logic signed [DATAWIDTH-1:0] r_edge_val1;
    logic signed [DATAWIDTH-1:0] r_edge_val2;
    logic signed [DATAWIDTH-1:0] r_edge_delta0[2];
    logic signed [DATAWIDTH-1:0] r_edge_delta1[2];
    logic signed [DATAWIDTH-1:0] r_edge_delta2[2];
    logic signed [DATAWIDTH-1:0] r_area;

    function automatic signed [DATAWIDTH-1:0] edge_function (
        input logic signed [DATAWIDTH-1:0] v1_x,
        input logic signed [DATAWIDTH-1:0] v1_y,
        input logic signed [DATAWIDTH-1:0] v2_x,
        input logic signed [DATAWIDTH-1:0] v2_y,
        input logic signed [DATAWIDTH-1:0] p_x,
        input logic signed [DATAWIDTH-1:0] p_y
    );
        edge_function = (p_x - v1_x) * (v2_y - v1_y) - (p_y - v1_y) * (v2_x - v1_x);
    endfunction

    logic signed [DATAWIDTH-1:0] w_bb_tl[2];
    logic signed [DATAWIDTH-1:0] w_bb_br[2];
    logic w_bb_valid;

    logic signed [DATAWIDTH-1:0] r_bb_tl[2];
    logic signed [DATAWIDTH-1:0] r_bb_br[2];
    logic r_bb_valid;

    bounding_box #(
        .TILE_MIN_X(SCREEN_MIN_X),
        .TILE_MAX_X(SCREEN_MAX_X),
        .TILE_MIN_Y(SCREEN_MIN_Y),
        .TILE_MAX_Y(SCREEN_MAX_Y),
        .COORD_WIDTH(DATAWIDTH)
    ) bounding_box_inst (
        .x0(r_v0[0]),
        .y0(r_v0[1]),
        .x1(r_v1[0]),
        .y1(r_v1[1]),
        .x2(r_v2[0]),
        .y2(r_v2[1]),

        .min_x(w_bb_tl[0]),
        .max_x(w_bb_br[0]),
        .min_y(w_bb_tl[1]),
        .max_y(w_bb_br[1]),

        .valid(w_bb_valid)
    );

    // DIVIDER UNIT
    /* verilator lint_off UNUSED */
    logic r_area_division_start = '0;

    logic signed [DATAWIDTH-1:0] w_area_reciprocal = '0;
    logic w_area_division_done = 1'b1;
    logic w_area_division_ready = '0;
    /* verilator lint_on UNUSED */

    // ========== STATE ==========
    typedef enum logic [1:0] {
        IDLE,
        STAGE1, // Compute edge function constants, area, edge function deltas and check winding order
        STAGE2, // Compute 1/area
        DONE
    } state_t;
    state_t current_state = IDLE, next_state = IDLE;

    always_ff @(posedge clk) begin
        if (~rstn) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    always_comb begin
        next_state = current_state;
        ready = 1'b0;

        case (current_state)
            IDLE: begin
                if (i_triangle_dv) begin
                    next_state = STAGE1;
                end else begin
                    ready = 1'b1;
                end
            end

            STAGE1: begin
                // TODO: Add BB_valid to state
                next_state = STAGE2;
            end

            STAGE2: begin
                // Back-face culling by checking sign of area
                if (r_area <= '0 || ~r_bb_valid) begin
                    next_state = IDLE;
                end else begin
                    if (w_area_division_done) begin
                        next_state = DONE;
                    end
                end
            end

            DONE: begin
                if (next) begin
                    next_state = IDLE;
                end
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

    always_ff @(posedge clk) begin
        if (~rstn) begin
            foreach (r_v0[i]) r_v0[i] <= '0;
            foreach (r_v1[i]) r_v1[i] <= '0;
            foreach (r_v2[i]) r_v2[i] <= '0;

            foreach (r_bb_tl[i]) r_bb_tl[i] <= '0;
            foreach (r_bb_br[i]) r_bb_br[i] <= '0;

            r_edge_val0 <= '0;
            r_edge_val1 <= '0;
            r_edge_val2 <= '0;
            foreach (r_edge_delta0[i]) r_edge_delta0[i] <= '0;
            foreach (r_edge_delta1[i]) r_edge_delta1[i] <= '0;
            foreach (r_edge_delta2[i]) r_edge_delta2[i] <= '0;
            r_area <= '0;

            o_dv <= '0;

        end else begin
            case (current_state)
                IDLE: begin
                    if (i_triangle_dv) begin
                        foreach (r_v0[i]) r_v0[i] <= i_v0[i];
                        foreach (r_v1[i]) r_v1[i] <= i_v1[i];
                        foreach (r_v2[i]) r_v2[i] <= i_v2[i];
                    end

                    r_edge_val0 <= '0;
                    r_edge_val1 <= '0;
                    r_edge_val2 <= '0;
                    foreach (r_edge_delta0[i]) r_edge_delta0[i] <= '0;
                    foreach (r_edge_delta1[i]) r_edge_delta1[i] <= '0;
                    foreach (r_edge_delta2[i]) r_edge_delta2[i] <= '0;
                    r_area <= '0;
                    o_dv <= '0;
                end

                STAGE1: begin
                    r_edge_val0 <= edge_function(r_v0[0], r_v0[1], r_v1[0], r_v1[1], P0[0], P0[1]);
                    r_edge_val1 <= edge_function(r_v1[0], r_v1[1], r_v2[0], r_v2[1], P0[0], P0[1]);
                    r_edge_val2 <= edge_function(r_v2[0], r_v2[1], r_v0[0], r_v0[1], P0[0], P0[1]);
                    r_edge_delta0 <= '{r_v1[1] - r_v0[1], -(r_v1[0] - r_v0[0])};
                    r_edge_delta1 <= '{r_v2[1] - r_v1[1], -(r_v2[0] - r_v1[0])};
                    r_edge_delta2 <= '{r_v0[1] - r_v2[1], -(r_v0[0] - r_v2[0])};
                    r_area <= edge_function(r_v0[0], r_v0[1], r_v1[0], r_v1[1], r_v2[0], r_v2[1]);

                    foreach (r_bb_tl[i]) r_bb_tl[i] <= w_bb_tl[i];
                    foreach (r_bb_br[i]) r_bb_br[i] <= w_bb_br[i];
                    r_bb_valid <= w_bb_valid;
                end

                STAGE2: begin
                    if (w_area_division_done) begin
                        foreach (bb_tl[i]) bb_tl[i] <= r_bb_tl[i];
                        foreach (bb_br[i]) bb_br[i] <= r_bb_br[i];
                        edge_val0 <= r_edge_val0;
                        edge_val1 <= r_edge_val1;
                        edge_val2 <= r_edge_val2;

                        foreach (edge_delta0[i]) edge_delta0[i] <= r_edge_delta0[i];
                        foreach (edge_delta1[i]) edge_delta1[i] <= r_edge_delta1[i];
                        foreach (edge_delta2[i]) edge_delta2[i] <= r_edge_delta2[i];
                        area_inv <= w_area_reciprocal;

                        o_dv <= '1;
                    end
                end

                DONE: begin
                    if (next) begin
                        o_dv <= '1;
                    end
                end

                default: begin
                end
            endcase
        end
    end

endmodule
