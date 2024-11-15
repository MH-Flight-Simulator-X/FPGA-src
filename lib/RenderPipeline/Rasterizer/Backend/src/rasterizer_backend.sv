`timescale 1ns / 1ps

module rasterizer_backend #(
    parameter unsigned DATAWIDTH = 12,
    parameter unsigned COLORWIDTH = 4,
    parameter unsigned [DATAWIDTH-1:0] SCREEN_WIDTH = 160,
    parameter unsigned [DATAWIDTH-1:0] SCREEN_HEIGHT = 160,
    parameter unsigned ADDRWIDTH = $clog2(SCREEN_WIDTH + SCREEN_HEIGHT)
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

    input logic [ADDRWIDTH-1:0] addr_start,    // The address of the top left corner of the BBox
    input logic i_dv,

    output logic [ADDRWIDTH-1:0] o_fb_addr_write,
    output logic o_fb_write_en,

    output logic [DATAWIDTH-1:0] depth_data,
    output logic [COLORWIDTH-1:0] color_data,

    output logic ready,
    output logic done
    );

    logic signed [ADDRWIDTH-1:0] r_x, r_y;
    logic signed [DATAWIDTH-1:0] r_z, r_z_row_start;

    logic [ADDRWIDTH-1:0] r_addr_delta_y;
    logic [ADDRWIDTH-1:0] r_addr;

    logic signed [2*DATAWIDTH-1:0] r_edge0, r_edge1, r_edge2;
    logic signed [2*DATAWIDTH-1:0] r_edge_row_start0, r_edge_row_start1, r_edge_row_start2;

    // ========== STATE ==========
    typedef enum logic [1:0] {
        IDLE,
        RASTERIZE,
        DONE
    } state_t;
    state_t current_state = IDLE, next_state = IDLE;

    always_ff @(posedge clk) begin
        if (~rstn) begin
            current_state <= IDLE;
        end
        else begin
            current_state <= next_state;
            o_fb_addr_write <= r_addr; // Delay output addr by 1
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
                end else begin
                    ready = 1'b1;
                end
            end

            RASTERIZE: begin
                if (r_x >= bb_br[0] && r_y >= bb_br[1]) begin
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

    // Compute
    always_ff @(posedge clk) begin
        case (current_state)
            IDLE: begin
                r_x <= bb_tl[0];
                r_y <= bb_tl[1];

                r_edge0 <= edge_val0;
                r_edge1 <= edge_val1;
                r_edge2 <= edge_val2;

                r_edge_row_start0 <= edge_val0;
                r_edge_row_start1 <= edge_val1;
                r_edge_row_start2 <= edge_val2;

                r_z <= z;
                r_z_row_start <= z;

                r_addr <= addr_start;
                r_addr_delta_y <= SCREEN_WIDTH[ADDRWIDTH-1:0] - (bb_br[0][ADDRWIDTH-1:0] - bb_tl[0][ADDRWIDTH-1:0]);
            end

            RASTERIZE: begin
                if (r_x < bb_br[0]) begin
                    // Increment in x-direction
                    r_addr <= r_addr + 1;

                    r_edge0 <= r_edge0 + edge_delta0[0];
                    r_edge1 <= r_edge1 + edge_delta1[0];
                    r_edge2 <= r_edge2 + edge_delta2[0];

                    r_x <= r_x + 1;

                    r_z <= r_z + z_delta[0];
                end
                else begin
                    // Increment in y-direction
                    r_edge0 <= r_edge_row_start0 + edge_delta0[1];
                    r_edge_row_start0 <= r_edge_row_start0 + edge_delta0[1];

                    r_edge1 <= r_edge_row_start1 + edge_delta1[1];
                    r_edge_row_start1 <= r_edge_row_start1 + edge_delta1[1];

                    r_edge2 <= r_edge_row_start2 + edge_delta2[1];
                    r_edge_row_start2 <= r_edge_row_start2 + edge_delta2[1];

                    r_y <= r_y + 1;
                    r_addr <= r_addr + r_addr_delta_y[ADDRWIDTH-1:0];

                    r_x <= bb_tl[0];

                    r_z_row_start <= r_z_row_start + z_delta[1];
                    r_z <= r_z_row_start + z_delta[1];
                end

                // Check if point is inside triangle
                if (r_edge0 > 0 && r_edge1 > 0 && r_edge2 > 0) begin
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

    assign depth_data = $unsigned(r_z[DEPTH_WIDTH-1:0]);

endmodule
