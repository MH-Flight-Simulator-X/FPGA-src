// Module for multiplying a 4x4 matrix by a 4-dim vector of fixed-point data

`timescale 1ns / 1ps

typedef enum logic [1:0] {
    IDLE = 2'b00,
    PROCESSING = 2'b01,
    DONE = 2'b10
} mat_vec_mul_state_t /*verilator public*/;

module mat_vec_mul_dim_4
    #(
    parameter unsigned DATAWIDTH = 32
    ) (
    input clk,
    input rstn,

    // Input Data
    input logic [DATAWIDTH-1:0] A [4][4],   // Input matrix
    input logic [DATAWIDTH-1:0] x [4],      // Input vector
    input logic i_dv,

    // Output Data
    output logic [DATAWIDTH-1:0] y [4],     // Output Vector
    output logic o_dv,
    output logic o_ready
    );

    reg [1:0] index = 2'b00;
    reg i_dv_r;
    reg o_dv_r;
    reg o_ready_r;
    reg [DATAWIDTH-1:0] A_r [4][4];
    reg [DATAWIDTH-1:0] x_r [4];
    reg [DATAWIDTH-1:0] y_r [4];

    mat_vec_mul_state_t current_state = IDLE, next_state = IDLE;

    always_ff @(posedge clk or negedge rstn) begin
        if (~rstn) begin
            foreach (A_r[i,j]) A_r[i][j] <= '0;
            foreach (x_r[i]) x_r[i] <= '0;

            i_dv_r <= 1'b0;
            current_state <= IDLE;

        end else begin
            current_state <= next_state;

            if (i_dv && o_ready) begin
                // Assign input data to registers
                A_r[0] <= A[0];
                A_r[1] <= A[1];
                A_r[2] <= A[2];
                A_r[3] <= A[3];
                x_r <= x;
                foreach (y_r[i]) y_r[i] <= '0;

                i_dv_r <= i_dv;
            end
        end
    end

    // State machine
    always_comb begin
        o_ready = 1'b0;
        o_dv = 1'b0;
        next_state = current_state;

        case (current_state)
            IDLE: begin
                o_ready = 1'b1;
                if (i_dv_r == 1'b1) begin
                    next_state = PROCESSING;
                end
            end

            PROCESSING: begin
                if (index == 2'b11) begin
                    next_state = DONE;
                end
            end

            DONE: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Compute the matrix vector product
    always_ff @(posedge clk or negedge rstn) begin
        if (~rstn) begin
            index <= 2'b00;
            foreach (y_r[i]) y_r[i] <= '0;
        end else if (current_state == PROCESSING) begin
            // DO COMPUTATION
            y_r[0] <= y_r[0] + (A_r[0][index] * x_r[index]);
            y_r[1] <= y_r[1] + (A_r[1][index] * x_r[index]);
            y_r[2] <= y_r[2] + (A_r[2][index] * x_r[index]);
            y_r[3] <= y_r[3] + (A_r[3][index] * x_r[index]);

            index <= index + 1'b1;
        end
    end

    // Register outputs
    always_ff @(posedge clk or negedge rstn) begin
        if (~rstn) begin
            foreach (y[i]) y[i] <= '0;
        end else if (current_state == DONE) begin
            y <= y_r;
            o_ready_r <= 1'b1;
            o_dv_r <= 1'b1;
            i_dv_r <= 1'b0;
        end else begin
            o_ready_r <= 1'b0;
            o_dv_r <= 1'b0;
        end
    end

    assign o_ready = o_ready_r;
    assign o_dv = o_dv_r;
endmodule
