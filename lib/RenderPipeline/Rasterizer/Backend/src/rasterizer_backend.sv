`timescale 1ns / 1ps

module rasterizer_backend #(
    parameter unsigned DATA_WIDTH = 16,
    parameter unsigned DEPTH_WIDTH = 16,
    parameter unsigned ADDR_WIDTH = 15,
    parameter unsigned [DATA_WIDTH-1:0] FB_WIDTH = 160
    ) (
    input logic clk,
    input logic rstn,
    input logic signed [DATA_WIDTH-1:0] bb_tl[2],
    input logic signed [DATA_WIDTH-1:0] bb_br[2],
    input logic signed [DATA_WIDTH-1:0] edge0,
    input logic signed [DATA_WIDTH-1:0] edge1,
    input logic signed [DATA_WIDTH-1:0] edge2,

    input logic signed [DATA_WIDTH-1:0] edge_delta0[2],
    input logic signed [DATA_WIDTH-1:0] edge_delta1[2],
    input logic signed [DATA_WIDTH-1:0] edge_delta2[2],

    input logic signed [DATA_WIDTH-1:0] z,
    input logic signed [DATA_WIDTH-1:0] z_delta[2],

    input logic [ADDR_WIDTH-1:0] addr_start,

    output logic [ADDR_WIDTH-1:0] o_addr,
    output logic signed [DEPTH_WIDTH-1:0] depth_data,

    output logic inside_triangle,
    output logic done
    );

    logic signed [DATA_WIDTH-1:0] r_x, r_y;
    logic signed [DATA_WIDTH-1:0] r_z, r_z_row_start;

    logic signed [DATA_WIDTH-1:0] r_edge0, r_edge1, r_edge2;
    logic signed [DATA_WIDTH-1:0] r_edge_row_start0, r_edge_row_start1, r_edge_row_start2;

    logic [ADDR_WIDTH-1:0] r_addr_line_jump_val;

    logic [ADDR_WIDTH-1:0] r_addr;

    assign depth_data = r_z[DEPTH_WIDTH-1:0];

    // ========== STATE ==========
    typedef enum logic [1:0] {
        STAGE1,
        RASTERIZE,
        DONE
    } state_t;
    state_t current_state = DONE, next_state;

    always_ff @(posedge clk) begin
        o_addr <= r_addr; // Delay output addr by 1

        if (~rstn) begin
            current_state <= STAGE1;
        end
        else begin
            current_state <= next_state;
        end
    end


    always_comb begin
        case (current_state)
            STAGE1: begin
                next_state = RASTERIZE;
                done = 1'b0;
            end

            RASTERIZE: begin
                if (r_x >= bb_br[0] && r_y >= bb_br[1])
                next_state = DONE;
                done = 1'b0;
            end

            DONE: begin
                if (~rstn) begin
                    next_state = STAGE1;
                end
                else begin
                    next_state = DONE;
                end
                done = 1'b1;
            end

            default: begin
                next_state = DONE;
            end
        endcase  
    end

    always_ff @(posedge clk) begin
        case (current_state)
            STAGE1: begin
                r_x <= bb_tl[0];
                r_y <= bb_tl[1];

                r_edge0 <= edge0;
                r_edge1 <= edge1;
                r_edge2 <= edge2;

                r_edge_row_start0 <= edge0;
                r_edge_row_start1 <= edge1;
                r_edge_row_start2 <= edge2;
                
                r_z <= z;
                r_z_row_start <= z;

                r_addr <= addr_start;
                r_addr_line_jump_val <= FB_WIDTH[ADDR_WIDTH-1:0] - (bb_br[0][ADDR_WIDTH-1:0] - bb_tl[0][ADDR_WIDTH-1:0]);
            end

            RASTERIZE: begin
                if (r_x < bb_br[0]) begin
                    r_addr <= r_addr + 1;
                    
                    r_edge0 <= r_edge0 + edge_delta0[0];
                    r_edge1 <= r_edge1 + edge_delta1[0];
                    r_edge2 <= r_edge2 + edge_delta2[0];

                    r_x <= r_x + 1;

                    r_z <= r_z + z_delta[0];

                    if (r_edge0 > 0 && r_edge1 > 0 && r_edge2 > 0) begin
                        inside_triangle <= 1'b1;
                    end
                    else begin
                        inside_triangle <= 1'b0;
                    end
                end
                else begin
                    if (r_y < bb_br[1]) begin
                        r_edge0 <= r_edge_row_start0 + edge_delta0[1];
                        r_edge_row_start0 <= r_edge_row_start0 + edge_delta0[1];
                        
                        r_edge1 <= r_edge_row_start1 + edge_delta1[1];
                        r_edge_row_start1 <= r_edge_row_start1 + edge_delta1[1];
                        
                        r_edge2 <= r_edge_row_start2 + edge_delta2[1];
                        r_edge_row_start2 <= r_edge_row_start2 + edge_delta2[1];

                        r_y <= r_y + 1;
                        r_addr <= r_addr + r_addr_line_jump_val[ADDR_WIDTH-1:0];

                        r_x <= bb_tl[0];

                        r_z_row_start <= r_z_row_start + z_delta[1];
                        r_z <= r_z_row_start + z_delta[1];

                        if (r_edge0 > 0 && r_edge1 > 0 && r_edge2 > 0) begin
                            inside_triangle <= 1'b1;
                        end
                        else begin
                            inside_triangle <= 1'b0;
                        end
                    end
                end
            end

            DONE: begin
            end
            
            default begin 
            end 
        endcase
    end

endmodule
