// Module for multiplying a 4x4 matrix by a 4-dim vector of fixed-point data
// Currently configured for Q10.8
// Version: 0.1

`timescale 1ns / 1ps

typedef enum logic [1:0] {
    MAT_MUL_IDLE = 2'b00,
    MAT_MUL_PROCESSING = 2'b01,
    MAT_MUL_DONE = 2'b10
} mat_mat_mul_state_t /*verilator public*/;

module mat_mul #(
    parameter unsigned DATAWIDTH = 18,
    parameter unsigned FRACBITS = 12
    ) (
    input clk,
    input rstn,

    // Input Data
    input signed [DATAWIDTH-1:0] A [4][4],   // 1. Input matrix
    input signed [DATAWIDTH-1:0] B [4][4],   // 2. Input matrix
    input logic i_dv,

    // Output Data
    output logic signed [DATAWIDTH-1:0] C [4][4],  // Output matrix
    output logic o_dv,
    output logic o_ready
    );

    localparam unsigned OutputRangeStart = FRACBITS;
    localparam unsigned OutputRangeEnd = DATAWIDTH + OutputRangeStart - 1;

    reg [1:0] index = 2'b00;
    reg i_dv_r;
    reg o_dv_r;
    reg o_ready_r;
    reg signed [DATAWIDTH-1:0] A_r [4][4];
    reg signed [DATAWIDTH-1:0] B_r [4][4];
    reg signed [2 * DATAWIDTH:0] C_r [4][4];        // Double data width to account for precision
                                                    // loss. Could be worth experimenting
                                                    // with only using DATAWIDTH for
                                                    // intermediate calculation

    mat_mat_mul_state_t current_state = MAT_MUL_IDLE, next_state;

    always_ff @(posedge clk) begin
        if (~rstn) begin
            foreach (A_r[i,j]) A_r[i][j] <= '0;
            foreach (B_r[i,j]) B_r[i][j] <= '0;

            i_dv_r <= 1'b0;
            current_state <= MAT_MUL_IDLE;

        end else begin
            current_state <= next_state;

            if (i_dv && o_ready) begin
                // Cssign input data to registers
                A_r[0] <= A[0];
                A_r[1] <= A[1];
                A_r[2] <= A[2];
                A_r[3] <= A[3];

                B_r[0] <= B[0];
                B_r[1] <= B[1];
                B_r[2] <= B[2];
                B_r[3] <= B[3];

            end

            i_dv_r <= i_dv;
        end
    end

    // State machine
    always_comb begin
        next_state = current_state;

        case (current_state)
            MAT_MUL_IDLE: begin
                if (i_dv_r == 1'b1) begin
                    next_state = MAT_MUL_PROCESSING;
                end
            end

            MAT_MUL_PROCESSING: begin
                if (index == 2'b11) begin
                    next_state = MAT_MUL_DONE;
                end
            end

            MAT_MUL_DONE: begin
                next_state = MAT_MUL_IDLE;
            end

            default: next_state = MAT_MUL_IDLE;
        endcase
    end

    // Compute the matrix vector product
    always_ff @(posedge clk) begin
        if (~rstn) begin
            index <= 2'b00;
            foreach (C_r[i,j]) C_r[i][j] <= '0;
        end else if (current_state == MAT_MUL_IDLE) begin
            index <= 2'b00;
            foreach (C_r[i,j]) C_r[i][j] <= '0;
        end else if (current_state == MAT_MUL_PROCESSING) begin
            // DO COMPUTATION
            C_r[0][0] <= C_r[0][0] + (A_r[0][index] * B_r[index][0]);
            C_r[0][1] <= C_r[0][1] + (A_r[0][index] * B_r[index][1]);
            C_r[0][2] <= C_r[0][2] + (A_r[0][index] * B_r[index][2]);
            C_r[0][3] <= C_r[0][3] + (A_r[0][index] * B_r[index][3]);

            C_r[1][0] <= C_r[1][0] + (A_r[1][index] * B_r[index][0]);
            C_r[1][1] <= C_r[1][1] + (A_r[1][index] * B_r[index][1]);
            C_r[1][2] <= C_r[1][2] + (A_r[1][index] * B_r[index][2]);
            C_r[1][3] <= C_r[1][3] + (A_r[1][index] * B_r[index][3]);

            C_r[2][0] <= C_r[2][0] + (A_r[2][index] * B_r[index][0]);
            C_r[2][1] <= C_r[2][1] + (A_r[2][index] * B_r[index][1]);
            C_r[2][2] <= C_r[2][2] + (A_r[2][index] * B_r[index][2]);
            C_r[2][3] <= C_r[2][3] + (A_r[2][index] * B_r[index][3]);

            C_r[3][0] <= C_r[3][0] + (A_r[3][index] * B_r[index][0]);
            C_r[3][1] <= C_r[3][1] + (A_r[3][index] * B_r[index][1]);
            C_r[3][2] <= C_r[3][2] + (A_r[3][index] * B_r[index][2]);
            C_r[3][3] <= C_r[3][3] + (A_r[3][index] * B_r[index][3]);

            index <= index + 1'b1;
        end
    end

    // Register outputs
    always_ff @(posedge clk) begin
        if (~rstn) begin
            o_dv_r <= 1'b0;
            o_ready_r <= 1'b1;
        end
        else begin
            if (current_state == MAT_MUL_IDLE) begin
                o_ready_r <= 1'b1;
                o_dv_r <= 1'b0;
                foreach (C[i, j]) C[i][j] <= '0;
            end else if (current_state == MAT_MUL_PROCESSING) begin
                foreach (C[i, j]) C[i][j] <= '0;
                o_ready_r <= 1'b0;
                o_dv_r <= 1'b0;
            end
            else begin
                C[0][0] <= {C_r[0][0][2*DATAWIDTH-1], C_r[0][0][OutputRangeEnd-1:OutputRangeStart]};
                C[0][1] <= {C_r[0][1][2*DATAWIDTH-1], C_r[0][1][OutputRangeEnd-1:OutputRangeStart]};
                C[0][2] <= {C_r[0][2][2*DATAWIDTH-1], C_r[0][2][OutputRangeEnd-1:OutputRangeStart]};
                C[0][3] <= {C_r[0][3][2*DATAWIDTH-1], C_r[0][3][OutputRangeEnd-1:OutputRangeStart]};

                C[1][0] <= {C_r[1][0][2*DATAWIDTH-1], C_r[1][0][OutputRangeEnd-1:OutputRangeStart]};
                C[1][1] <= {C_r[1][1][2*DATAWIDTH-1], C_r[1][1][OutputRangeEnd-1:OutputRangeStart]};
                C[1][2] <= {C_r[1][2][2*DATAWIDTH-1], C_r[1][2][OutputRangeEnd-1:OutputRangeStart]};
                C[1][3] <= {C_r[1][3][2*DATAWIDTH-1], C_r[1][3][OutputRangeEnd-1:OutputRangeStart]};

                C[2][0] <= {C_r[2][0][2*DATAWIDTH-1], C_r[2][0][OutputRangeEnd-1:OutputRangeStart]};
                C[2][1] <= {C_r[2][1][2*DATAWIDTH-1], C_r[2][1][OutputRangeEnd-1:OutputRangeStart]};
                C[2][2] <= {C_r[2][2][2*DATAWIDTH-1], C_r[2][2][OutputRangeEnd-1:OutputRangeStart]};
                C[2][3] <= {C_r[2][3][2*DATAWIDTH-1], C_r[2][3][OutputRangeEnd-1:OutputRangeStart]};

                C[3][0] <= {C_r[3][0][2*DATAWIDTH-1], C_r[3][0][OutputRangeEnd-1:OutputRangeStart]};
                C[3][1] <= {C_r[3][1][2*DATAWIDTH-1], C_r[3][1][OutputRangeEnd-1:OutputRangeStart]};
                C[3][2] <= {C_r[3][2][2*DATAWIDTH-1], C_r[3][2][OutputRangeEnd-1:OutputRangeStart]};
                C[3][3] <= {C_r[3][3][2*DATAWIDTH-1], C_r[3][3][OutputRangeEnd-1:OutputRangeStart]};

                o_dv_r <= 1'b1;
                o_ready_r <= 1'b1;
            end
        end
    end

    assign o_ready = o_ready_r;
    assign o_dv = o_dv_r;
endmodule
