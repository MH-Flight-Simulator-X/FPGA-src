`timescale 1ns / 1ps

module rasterizer_backend #(
    parameter unsigned DATAWIDTH = 12,
    parameter unsigned COLORWIDTH = 4,
    parameter unsigned [DATAWIDTH-1:0] SCREEN_WIDTH = 320,
    parameter unsigned [DATAWIDTH-1:0] SCREEN_HEIGHT = 320,
    parameter unsigned ADDRWIDTH = 16
    ) (
    input logic clk,
    input logic rstn,

    input logic signed [DATAWIDTH-1:0] bb_tl[2],
    input logic signed [DATAWIDTH-1:0] bb_br[2],

    input logic signed [2*DATAWIDTH-1:0] edge_val0,
    input logic signed [2*DATAWIDTH-1:0] edge_val1,
    input logic signed [2*DATAWIDTH-1:0] edge_val2,

    input logic signed [DATAWIDTH-1:0] edge_delta0[2],
    input logic signed [DATAWIDTH-1:0] edge_delta1[2],
    input logic signed [DATAWIDTH-1:0] edge_delta2[2],

    input logic signed [DATAWIDTH-1:0] z,
    input logic signed [DATAWIDTH-1:0] z_delta[2],
    input logic i_dv,
    input logic i_last,

    output logic [ADDRWIDTH-1:0] o_fb_addr_write,
    output logic o_fb_write_en,

    output logic [DATAWIDTH-1:0] depth_data,
    output logic [COLORWIDTH-1:0] color_data,

    output logic ready,
    output logic done
    );

    // Register later used input signals
    logic signed [DATAWIDTH-1:0] r_bb_tl[2];
    logic signed [DATAWIDTH-1:0] r_bb_br[2];

    logic signed [DATAWIDTH-1:0] r_edge_delta0[2];
    logic signed [DATAWIDTH-1:0] r_edge_delta1[2];
    logic signed [DATAWIDTH-1:0] r_edge_delta2[2];

    logic signed [ADDRWIDTH-1:0] r_x, r_y;
    logic signed [DATAWIDTH-1:0] r_z, r_z_row_start;

    logic [ADDRWIDTH-1:0] r_addr_delta_y;
    logic [ADDRWIDTH-1:0] r_addr;

    logic signed [2*DATAWIDTH-1:0] r_edge0, r_edge1, r_edge2;
    logic signed [2*DATAWIDTH-1:0] r_edge_row_start0, r_edge_row_start1, r_edge_row_start2;

    logic r_is_last = '0;

    // ========== STATE ==========
    typedef enum logic [1:0] {
        IDLE,
        RASTERIZE,
        DONE
    } state_t;
    state_t current_state = IDLE, next_state;

    always_ff @(posedge clk) begin
        if (~rstn) begin
            current_state <= IDLE;
            o_fb_addr_write <= '0;
        end
        else begin
            current_state <= next_state;
            o_fb_addr_write <= r_addr;
        end
    end

    always_comb begin
        next_state = current_state;
        ready = 1'b0;
        done = 1'b0;

        case (current_state)
            IDLE: begin
                if (i_dv) begin
                    next_state = RASTERIZE;
                end
                ready = 1'b1;
            end

            RASTERIZE: begin
                if (r_x >= {{(ADDRWIDTH-DATAWIDTH){1'b0}}, r_bb_br[0]} && r_y >= {{(ADDRWIDTH-DATAWIDTH){1'b0}}, r_bb_br[1]}) begin
                    next_state = DONE;
                end
            end

            DONE: begin
                next_state = IDLE;
                done = 1'b1;
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

    // Calculate start address
    logic [ADDRWIDTH-1:0] w_addr_start;
    logic [2*DATAWIDTH-1:0] w_addr_start_y;
    logic [DATAWIDTH-1:0]   w_addr_start_x;
    always_comb begin
        w_addr_start_y = r_bb_tl[1] * SCREEN_WIDTH;
        if (r_bb_tl[0] == 0) begin
            w_addr_start_x = 0;
        end else begin
            w_addr_start_x = r_bb_tl[0] - 1;
        end
        w_addr_start = w_addr_start_y[ADDRWIDTH-1:0] + {{(ADDRWIDTH-DATAWIDTH){1'b0}}, w_addr_start_x};
    end

    // Compute
    always_ff @(posedge clk) begin
        case (current_state)
            IDLE: begin
                r_bb_tl[0] <= bb_tl[0]; r_bb_tl[1] <= bb_tl[1];
                r_bb_br[0] <= bb_br[0]; r_bb_br[1] <= bb_br[1];

                r_edge_delta0[0] <= edge_delta0[0]; r_edge_delta0[1] <= edge_delta0[1];
                r_edge_delta1[0] <= edge_delta1[0]; r_edge_delta1[1] <= edge_delta1[1];
                r_edge_delta2[0] <= edge_delta2[0]; r_edge_delta2[1] <= edge_delta2[1];

                r_x <= {{(ADDRWIDTH-DATAWIDTH){bb_tl[0][DATAWIDTH-1]}}, bb_tl[0]};
                r_y <= {{(ADDRWIDTH-DATAWIDTH){bb_tl[1][DATAWIDTH-1]}}, bb_tl[1]};

                r_edge0 <= edge_val0;
                r_edge1 <= edge_val1;
                r_edge2 <= edge_val2;

                r_edge_row_start0 <= edge_val0;
                r_edge_row_start1 <= edge_val1;
                r_edge_row_start2 <= edge_val2;

                r_z <= z;
                r_z_row_start <= z;

                r_addr <= w_addr_start;
                r_addr_delta_y <= {{(ADDRWIDTH-DATAWIDTH){1'b0}}, SCREEN_WIDTH - (bb_br[0] - bb_tl[0])};
            end

            RASTERIZE: begin
                if (r_x < {{(ADDRWIDTH-DATAWIDTH){r_bb_br[0][DATAWIDTH-1]}}, r_bb_br[0]}) begin
                    // Increment in x-direction
                    r_addr <= r_addr + 1;

                    r_edge0 <= r_edge0 + {{DATAWIDTH{r_edge_delta0[0][DATAWIDTH-1]}}, r_edge_delta0[0]};
                    r_edge1 <= r_edge1 + {{DATAWIDTH{r_edge_delta1[0][DATAWIDTH-1]}}, r_edge_delta1[0]};
                    r_edge2 <= r_edge2 + {{DATAWIDTH{r_edge_delta2[0][DATAWIDTH-1]}}, r_edge_delta2[0]};

                    r_x <= r_x + 1;
                    r_z <= r_z + z_delta[0];
                end
                else begin
                    // Increment in y-direction
                    r_edge0 <= r_edge_row_start0 + {{DATAWIDTH{r_edge_delta0[1][DATAWIDTH-1]}}, r_edge_delta0[1]};
                    r_edge_row_start0 <= r_edge_row_start0 + {{DATAWIDTH{r_edge_delta0[1][DATAWIDTH-1]}}, r_edge_delta0[1]};

                    r_edge1 <= r_edge_row_start1 + {{DATAWIDTH{r_edge_delta1[1][DATAWIDTH-1]}}, r_edge_delta1[1]};
                    r_edge_row_start1 <= r_edge_row_start1 + {{DATAWIDTH{r_edge_delta1[1][DATAWIDTH-1]}}, r_edge_delta1[1]};

                    r_edge2 <= r_edge_row_start2 + {{DATAWIDTH{r_edge_delta2[1][DATAWIDTH-1]}}, r_edge_delta2[1]};
                    r_edge_row_start2 <= r_edge_row_start2 + {{DATAWIDTH{r_edge_delta2[1][DATAWIDTH-1]}}, r_edge_delta2[1]};

                    r_y <= r_y + 1;
                    r_addr <= r_addr + r_addr_delta_y;

                    r_x <= {{(ADDRWIDTH-DATAWIDTH){r_bb_tl[0][DATAWIDTH-1]}}, r_bb_tl[0]};

                    r_z_row_start <= r_z_row_start + z_delta[1];
                    r_z <= r_z_row_start + z_delta[1];
                end

                // Check if point is inside triangle
                if ($signed(r_edge0) > $signed({(2*DATAWIDTH){1'b0}}) && $signed(r_edge1) > $signed({(2*DATAWIDTH){1'b0}}) && $signed(r_edge2) > $signed({(2*DATAWIDTH){1'b0}})) begin
                    o_fb_write_en <= 1'b1;
                end
                else begin
                    o_fb_write_en <= 1'b0;
                end
            end

            default begin
            end
        endcase
    end

    // ASSIGN COLOR TO OUTPUT -- FOR NOW JUST ASSIGN BASED ON ORDER OF
    // RENDERING
    logic [COLORWIDTH-1:0] r_color;
    always_ff @(posedge clk) begin
        if (~rstn) begin
            r_color <= '0;
            r_is_last <= '0;
        end else begin
            case (current_state)
                IDLE: begin
                    if (i_dv) begin
                        r_color <= r_color + 1;
                        r_is_last <= i_last;
                    end
                end

                DONE: begin
                    if (r_is_last) begin
                        r_color <= '0;
                    end
                end

                default: begin
                end
            endcase
        end
    end

    assign depth_data = $unsigned(r_z[DATAWIDTH-1:0]);
    assign color_data = r_color;

endmodule
