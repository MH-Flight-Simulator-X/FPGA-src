`timescale 1ns / 1ps

/* verilator lint_off DECLFILENAME */
module edge_compute #(
    parameter unsigned DATAWIDTH
    ) (
    input logic signed [DATAWIDTH-1:0] v1[2],
    input logic signed [DATAWIDTH-1:0] v2[2],
    input logic signed [DATAWIDTH-1:0] p[2],

    output logic signed [2*DATAWIDTH-1:0] edge_function,
    output logic signed [DATAWIDTH-1:0] edge_delta[2]
    );

    /* verilator lint_off WIDTH */
    always_comb begin
        edge_function = ((p[0] - v1[0]) * (v2[1] - v1[1])) - ((p[1] - v1[1]) * (v2[0] - v1[0]));
        edge_delta = '{v2[1] - v1[1], -(v2[0] - v1[0])};
    end
    /* verilator lint_on WIDTH */
endmodule
/* verilator lint_on DECLFILENAME */

module rasterizer_frontend #(
    parameter unsigned DATAWIDTH = 12,
    parameter signed [DATAWIDTH-1:0] SCREEN_WIDTH = 320,
    parameter signed [DATAWIDTH-1:0] SCREEN_HEIGHT = 320
    ) (
    input logic clk,
    input logic rstn,

    output logic ready,
    input  logic next,   // Can safely output next triangle

    input logic signed [DATAWIDTH-1:0] i_v0[3],
    input logic signed [DATAWIDTH-1:0] i_v1[3],
    input logic signed [DATAWIDTH-1:0] i_v2[3],
    input logic i_triangle_dv,

    output logic signed [DATAWIDTH-1:0] bb_tl[2],
    output logic signed [DATAWIDTH-1:0] bb_br[2],
    output logic signed [2*DATAWIDTH-1:0] edge_val0,
    output logic signed [2*DATAWIDTH-1:0] edge_val1,
    output logic signed [2*DATAWIDTH-1:0] edge_val2,

    output logic signed [DATAWIDTH-1:0] edge_delta0[2],
    output logic signed [DATAWIDTH-1:0] edge_delta1[2],
    output logic signed [DATAWIDTH-1:0] edge_delta2[2],
    output logic signed [2*DATAWIDTH-1:0] area_inv,
    output logic signed [2*DATAWIDTH-1:0] o_area,
    output logic o_dv
    );

    // For now, just set sample point at (0,0)
    localparam logic signed [DATAWIDTH-1:0] P0[2] = '{0, 0};

    // Register input data
    logic signed [DATAWIDTH-1:0] r_v0[3];
    logic signed [DATAWIDTH-1:0] r_v1[3];
    logic signed [DATAWIDTH-1:0] r_v2[3];

    // Edge function data registers
    /* verilator lint_off UNUSED */
    logic signed [2 * DATAWIDTH-1:0] r_edge_val0;
    logic signed [2 * DATAWIDTH-1:0] r_edge_val1;
    logic signed [2 * DATAWIDTH-1:0] r_edge_val2;
    /* verilator lint_on UNUSED */
    logic signed [DATAWIDTH-1:0] r_edge_delta0[2];
    logic signed [DATAWIDTH-1:0] r_edge_delta1[2];
    logic signed [DATAWIDTH-1:0] r_edge_delta2[2];
    logic signed [2 * DATAWIDTH-1:0] r_area;

    // Edge function compute
    logic signed [DATAWIDTH-1:0] r_edge_function_v1[2];
    logic signed [DATAWIDTH-1:0] r_edge_function_v2[2];
    logic signed [DATAWIDTH-1:0] r_edge_function_p[2];
    logic signed [2*DATAWIDTH-1:0] w_edge_function_val;
    logic signed [DATAWIDTH-1:0] w_edge_function_delta[2];

    edge_compute #(
        .DATAWIDTH(DATAWIDTH)
    ) edge_compute_inst (
        .v1(r_edge_function_v1),
        .v2(r_edge_function_v2),
        .p(r_edge_function_p),
        .edge_function(w_edge_function_val),
        .edge_delta(w_edge_function_delta)
    );

    // Bounding box coumpute
    logic signed [DATAWIDTH-1:0] w_bb_tl[2];
    logic signed [DATAWIDTH-1:0] w_bb_br[2];
    logic w_bb_valid;

    logic signed [DATAWIDTH-1:0] r_bb_tl[2];
    logic signed [DATAWIDTH-1:0] r_bb_br[2];
    logic r_bb_valid;

    bounding_box #(
        .TILE_MIN_X (0),
        .TILE_MAX_X (SCREEN_WIDTH),
        .TILE_MIN_Y (0),
        .TILE_MAX_Y (SCREEN_HEIGHT),
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
    logic w_area_division_ready = '0;
    logic [2*DATAWIDTH-1:0] r_area_division_in_A;
    logic r_area_division_in_A_dv;

    logic [2*DATAWIDTH-1:0] w_area_reciprocal;
    logic w_area_reciprocal_dv;

    fast_inverse #(
        .DATAWIDTH(2 * DATAWIDTH),
        .NUM_ITERATIONS(2)
    ) fast_inverse_inst (
        .clk (clk),
        .rstn(rstn),

        .ready(w_area_division_ready),
        .A(r_area_division_in_A),
        .A_dv(r_area_division_in_A_dv),

        .A_inv(w_area_reciprocal),
        .A_inv_dv(w_area_reciprocal_dv)
    );

    // ========== STATE ==========
    typedef enum logic [2:0] {
        IDLE,
        COMPUTE_AREA,
        COMPUTE_EDGE_0, // Also starts computation of area reciprocal
        COMPUTE_EDGE_1,
        COMPUTE_EDGE_2,
        REGISTER_AREA_RECIPROCAL,
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
                    next_state = COMPUTE_AREA;
                end else begin
                    ready = 1'b1;
                end
            end

            COMPUTE_AREA: begin
                next_state = COMPUTE_EDGE_0;
            end

            COMPUTE_EDGE_0: begin
                if (r_area <= '0 || ~r_bb_valid) begin
                    next_state = IDLE;
                end else if (w_area_division_ready) begin
                    next_state = COMPUTE_EDGE_1;
                end
            end

            COMPUTE_EDGE_1: begin
                next_state = COMPUTE_EDGE_2;
            end

            COMPUTE_EDGE_2: begin
                next_state = REGISTER_AREA_RECIPROCAL;
            end

            REGISTER_AREA_RECIPROCAL: begin
                if (w_area_reciprocal_dv) begin
                    next_state = DONE;
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

            r_area_division_in_A_dv <= 1'b0;
            r_area_division_in_A <= '0;

            foreach (r_edge_function_v1[i]) r_edge_function_v1[i] <= '0;
            foreach (r_edge_function_v2[i]) r_edge_function_v2[i] <= '0;
            foreach (r_edge_function_p[i] ) r_edge_function_p[i]  <= '0;

            r_edge_val0 <= '0;
            r_edge_val1 <= '0;
            r_edge_val2 <= '0;
            foreach (r_edge_delta0[i]) r_edge_delta0[i] <= '0;
            foreach (r_edge_delta1[i]) r_edge_delta1[i] <= '0;
            foreach (r_edge_delta2[i]) r_edge_delta2[i] <= '0;
            r_area <= '0;
            o_dv   <= '0;
        end else begin
            case (current_state)
                IDLE: begin
                    if (i_triangle_dv) begin
                        foreach (r_v0[i]) r_v0[i] <= i_v0[i];
                        foreach (r_v1[i]) r_v1[i] <= i_v1[i];
                        foreach (r_v2[i]) r_v2[i] <= i_v2[i];

                        // Add values to register in order to compute area
                        r_edge_function_v1 <= '{i_v0[0], i_v0[1]};
                        r_edge_function_v2 <= '{i_v1[0], i_v1[1]};
                        r_edge_function_p  <= '{i_v2[0], i_v2[1]};
                    end

                    r_edge_val0 <= '0;
                    r_edge_val1 <= '0;
                    r_edge_val2 <= '0;
                    foreach (r_edge_delta0[i]) r_edge_delta0[i] <= '0;
                    foreach (r_edge_delta1[i]) r_edge_delta1[i] <= '0;
                    foreach (r_edge_delta2[i]) r_edge_delta2[i] <= '0;
                    r_area <= '0;
                    o_dv   <= '0;
                end

                COMPUTE_AREA: begin
                    r_area <= w_edge_function_val;

                    // Bounding box
                    foreach (r_bb_tl[i]) r_bb_tl[i] <= w_bb_tl[i];
                    foreach (r_bb_br[i]) r_bb_br[i] <= w_bb_br[i];
                    r_bb_valid <= w_bb_valid;

                    // For next compute
                    r_edge_function_v1 <= '{r_v0[0], r_v0[1]};
                    r_edge_function_v2 <= '{r_v1[0], r_v1[1]};
                    r_edge_function_p  <= P0;
                end

                COMPUTE_EDGE_0: begin
                    r_edge_val0 <= w_edge_function_val;
                    r_edge_delta0 <= w_edge_function_delta;

                    // Area reciprocal compute
                    if (w_area_division_ready) begin
                        r_area_division_in_A <= r_area;
                        r_area_division_in_A_dv <= 1'b1;
                    end else begin
                        r_area_division_in_A_dv <= 1'b0;
                    end

                    // For next compute
                    r_edge_function_v1 <= '{r_v1[0], r_v1[1]};
                    r_edge_function_v2 <= '{r_v2[0], r_v2[1]};
                    r_edge_function_p  <= P0;
                end

                COMPUTE_EDGE_1: begin
                    r_edge_val1 <= w_edge_function_val;
                    r_edge_delta1 <= w_edge_function_delta;

                    // For next compute
                    r_edge_function_v1 <= '{r_v2[0], r_v2[1]};
                    r_edge_function_v2 <= '{r_v0[0], r_v0[1]};
                    r_edge_function_p  <= P0;
                end

                COMPUTE_EDGE_2: begin
                    r_edge_val2 <= w_edge_function_val;
                    r_edge_delta2 <= w_edge_function_delta;
                end

                REGISTER_AREA_RECIPROCAL: begin
                    if (w_area_reciprocal_dv) begin
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
                    end else begin
                        o_dv <= '0;
                    end
                end

                DONE: begin
                    if (next) begin
                        o_dv <= '0;
                    end
                end

                default: begin
                end
            endcase
        end
    end

    // DEBUG
    assign o_area = r_area;

endmodule
