`timescale 1ns / 1ps
/* verilator lint_off UNUSED */

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

    output logic signed [DATAWIDTH-1:0] z_coeff,
    output logic signed [DATAWIDTH-1:0] z_coeff_delta[2],

    output logic o_dv
    );

    // Register input data
    logic signed [DATAWIDTH-1:0] r_v0[3];
    logic signed [DATAWIDTH-1:0] r_v1[3];
    logic signed [DATAWIDTH-1:0] r_v2[3];

    // Edge function data registers
    logic signed [2 * DATAWIDTH-1:0] r_edge_val0;
    logic signed [2 * DATAWIDTH-1:0] r_edge_val1;
    logic signed [2 * DATAWIDTH-1:0] r_edge_val2;
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

    logic [DATAWIDTH-1:0] r_area_reciprocal;

    fast_inverse #(
        .DATAWIDTH(2 * DATAWIDTH),
        .NUM_ITERATIONS(4)
    ) fast_inverse_inst (
        .clk (clk),
        .rstn(rstn),

        .ready(w_area_division_ready),
        .A(r_area_division_in_A),
        .A_dv(r_area_division_in_A_dv),

        .A_inv(w_area_reciprocal),
        .A_inv_dv(w_area_reciprocal_dv)
    );

    // Barycentric coordinate compute
    logic signed [3*DATAWIDTH:0] barycentric_weight[3];
    logic signed [2*DATAWIDTH:0] barycentric_weight_delta[3][2];

    // z_coeff: A signed Q0.12 fixed-point number
    logic signed [3*DATAWIDTH:0] z;

    // z_dx and z_dy: Delta coefficients for z, also Q0.12 fixed-point numbers
    logic signed [3*DATAWIDTH:0] z_dx;
    logic signed [3*DATAWIDTH:0] z_dy;

    // ========== STATE ==========
    typedef enum logic [3:0] {
        IDLE,
        COMPUTE_AREA,
        COMPUTE_EDGE_0, // Also starts computation of area reciprocal
        COMPUTE_EDGE_1,
        COMPUTE_EDGE_2,
        REGISTER_AREA_RECIPROCAL,
        COMPUTE_BARYCENTRIC,
        COMPUTE_Z,
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
                if ($signed(r_area) <= $signed({(2*DATAWIDTH){1'b0}}) || ~r_bb_valid) begin
                    $display("Invalid triangle. Back-face culling");
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
                    next_state = COMPUTE_BARYCENTRIC;
                end
            end

            COMPUTE_BARYCENTRIC: begin
                next_state = COMPUTE_Z;
            end

            COMPUTE_Z: begin
                next_state = DONE;
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

            z_coeff <= '0;
            z_coeff_delta[0] <= '0;
            z_coeff_delta[1] <= '0;

            o_dv <= '0;

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
                    r_edge_function_p  <= w_bb_tl;
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
                    r_edge_function_p  <= r_bb_tl;
                end

                COMPUTE_EDGE_1: begin
                    r_edge_val1 <= w_edge_function_val;
                    r_edge_delta1 <= w_edge_function_delta;

                    // For next compute
                    r_edge_function_v1 <= '{r_v2[0], r_v2[1]};
                    r_edge_function_v2 <= '{r_v0[0], r_v0[1]};
                    r_edge_function_p  <= r_bb_tl;
                end

                COMPUTE_EDGE_2: begin
                    r_edge_val2 <= w_edge_function_val;
                    r_edge_delta2 <= w_edge_function_delta;
                end

                REGISTER_AREA_RECIPROCAL: begin
                    if (w_area_reciprocal_dv) begin
                        r_area_reciprocal <= w_area_reciprocal[2*DATAWIDTH-1:DATAWIDTH];
                    end
                end

                COMPUTE_BARYCENTRIC: begin
                    barycentric_weight[0] <= r_edge_val0 * $unsigned(r_area_reciprocal);
                    barycentric_weight[1] <= r_edge_val1 * $unsigned(r_area_reciprocal);
                    barycentric_weight[2] <= r_edge_val2 * $unsigned(r_area_reciprocal);

                    barycentric_weight_delta[0] <= '{
                        r_edge_delta0[0] * $signed({1'b0, r_area_reciprocal}),
                        r_edge_delta0[1] * $signed({1'b0, r_area_reciprocal})
                    };
                    barycentric_weight_delta[1] <= '{
                        r_edge_delta1[0] * $signed({1'b0, r_area_reciprocal}),
                        r_edge_delta1[1] * $signed({1'b0, r_area_reciprocal})
                    };
                    barycentric_weight_delta[2] <= '{
                        r_edge_delta2[0] * $signed({1'b0, r_area_reciprocal}),
                        r_edge_delta2[1] * $signed({1'b0, r_area_reciprocal})
                    };
                end

                COMPUTE_Z: begin

                    z <= ($signed(barycentric_weight[0]) * $unsigned(r_v0[2]) +
                          $signed(barycentric_weight[1]) * $unsigned(r_v1[2]) +
                          $signed(barycentric_weight[2]) * $unsigned(r_v2[2])
                         ) >>> DATAWIDTH;

                    // Compute z_dx as the sum of barycentric_weight_delta[x][0] * r_vX[2]
                    z_dx <= ($signed(barycentric_weight_delta[0][0]) * $unsigned(r_v0[2]) +
                             $signed(barycentric_weight_delta[1][0]) * $unsigned(r_v1[2]) +
                             $signed(barycentric_weight_delta[2][0]) * $unsigned(r_v2[2])
                            ) >>> DATAWIDTH;

                    // Compute z_dy as the sum of barycentric_weight_delta[x][1] * r_vX[2]
                    z_dy <= ($signed(barycentric_weight_delta[0][1]) * $unsigned(r_v0[2]) +
                             $signed(barycentric_weight_delta[1][1]) * $unsigned(r_v1[2]) +
                             $signed(barycentric_weight_delta[2][1]) * $unsigned(r_v2[2])
                            ) >>> DATAWIDTH;
                end

                DONE: begin
                    foreach (bb_tl[i]) bb_tl[i] <= r_bb_tl[i];
                    foreach (bb_br[i]) bb_br[i] <= r_bb_br[i];
                    edge_val0 <= r_edge_val0;
                    edge_val1 <= r_edge_val1;
                    edge_val2 <= r_edge_val2;

                    z_coeff <= z[DATAWIDTH-1:0];
                    z_coeff_delta[0] <= z_dx[DATAWIDTH:1];
                    z_coeff_delta[1] <= z_dy[DATAWIDTH:1];

                    foreach (edge_delta0[i]) edge_delta0[i] <= r_edge_delta0[i];
                    foreach (edge_delta1[i]) edge_delta1[i] <= r_edge_delta1[i];
                    foreach (edge_delta2[i]) edge_delta2[i] <= r_edge_delta2[i];

                    o_dv <= '1;
                end

                default: begin
                end
            endcase
        end
    end
endmodule
