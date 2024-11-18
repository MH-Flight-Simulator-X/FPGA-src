// Module for multiplying a 4x4 matrix by a 4-dim vector of fixed-point data
// Version: 1.0

`timescale 1ns / 1ps

module mat_vec_mul #(
    parameter unsigned DATAWIDTH = 18,
    parameter unsigned FRACBITS = 12
    ) (
    input clk,
    input rstn,

    // Pipeline enable signal
    // Data will not progress unless enable is high
    input logic i_enable,

    // Input Data
    input signed [DATAWIDTH-1:0] A [4][4],   // Input matrix
    input signed [DATAWIDTH-1:0] x [4],      // Input vector
    input logic i_dv,

    // Output Data
    output logic signed [DATAWIDTH-1:0] y [4],     // Output Vector
    output logic o_dv
    );

    localparam unsigned OutputRangeStart = FRACBITS;
    localparam unsigned OutputRangeEnd = DATAWIDTH + OutputRangeStart - 1;

    logic [3:0] i_dv_r;
    logic signed [DATAWIDTH-1:0] A_r_0 [4][4];
    logic signed [DATAWIDTH-1:0] x_r_0 [4];

    logic signed [DATAWIDTH-1:0] A_r_1 [4][4];
    logic signed [DATAWIDTH-1:0] x_r_1 [4];
    logic signed [2 * DATAWIDTH:0] y_r_1 [4];

    logic signed [DATAWIDTH-1:0] A_r_2 [4][4];
    logic signed [DATAWIDTH-1:0] x_r_2 [4];
    logic signed [2 * DATAWIDTH:0] y_r_2 [4];

    logic signed [DATAWIDTH-1:0] A_r_3 [4][4];
    logic signed [DATAWIDTH-1:0] x_r_3 [4];
    logic signed [2 * DATAWIDTH:0] y_r_3 [4];

    logic signed [2 * DATAWIDTH:0] y_inter_0 [4];
    logic signed [2 * DATAWIDTH:0] y_inter_1 [4];
    logic signed [2 * DATAWIDTH:0] y_inter_2 [4];
    logic signed [2 * DATAWIDTH:0] y_inter_3 [4];

    always_ff @(posedge clk) begin
        if (~rstn) begin
            foreach (A_r_0[i,j]) A_r_0[i][j] <= '0;
            foreach (x_r_0[i]) x_r_0[i] <= '0;

            foreach (A_r_1[i,j]) A_r_1[i][j] <= '0;
            foreach (x_r_1[i]) x_r_1[i] <= '0;
            foreach (y_r_1[i]) y_r_1[i] <= '0;

            foreach (A_r_2[i,j]) A_r_2[i][j] <= '0;
            foreach (x_r_2[i]) x_r_2[i] <= '0;
            foreach (y_r_2[i]) y_r_2[i] <= '0;

            foreach (A_r_3[i,j]) A_r_3[i][j] <= '0;
            foreach (x_r_3[i]) x_r_3[i] <= '0;
            foreach (y_r_3[i]) y_r_3[i] <= '0;

            i_dv_r <= '0;
        end else begin
            if (i_enable) begin
                i_dv_r[0] <= i_dv;
                i_dv_r[1] <= i_dv_r[0];
                i_dv_r[2] <= i_dv_r[1];
                i_dv_r[3] <= i_dv_r[2];

                A_r_0[0] <= A[0];
                A_r_0[1] <= A[1];
                A_r_0[2] <= A[2];
                A_r_0[3] <= A[3];
                x_r_0    <= x;

                A_r_1[0] <= A_r_0[0];
                A_r_1[1] <= A_r_0[1];
                A_r_1[2] <= A_r_0[2];
                A_r_1[3] <= A_r_0[3];
                x_r_1    <= x_r_0;

                A_r_2[0] <= A_r_1[0];
                A_r_2[1] <= A_r_1[1];
                A_r_2[2] <= A_r_1[2];
                A_r_2[3] <= A_r_1[3];
                x_r_2    <= x_r_1;

                A_r_3[0] <= A_r_2[0];
                A_r_3[1] <= A_r_2[1];
                A_r_3[2] <= A_r_2[2];
                A_r_3[3] <= A_r_2[3];
                x_r_3    <= x_r_2;
            end
        end
    end

    // Compute the matrix vector product
    always_comb begin
        foreach (y_inter_0[i]) y_inter_0[i] = '0;
        foreach (y_inter_1[i]) y_inter_1[i] = '0;
        foreach (y_inter_2[i]) y_inter_2[i] = '0;
        foreach (y_inter_3[i]) y_inter_3[i] = '0;

        if (i_enable) begin
            if (i_dv_r[0]) begin
                y_inter_0[0] = A_r_0[0][0] * x_r_0[0];
                y_inter_0[1] = A_r_0[1][0] * x_r_0[0];
                y_inter_0[2] = A_r_0[2][0] * x_r_0[0];
                y_inter_0[3] = A_r_0[3][0] * x_r_0[0];
            end
            if (i_dv_r[1]) begin
                y_inter_1[0] = y_r_1[0] + A_r_1[0][1] * x_r_1[1];
                y_inter_1[1] = y_r_1[1] + A_r_1[1][1] * x_r_1[1];
                y_inter_1[2] = y_r_1[2] + A_r_1[2][1] * x_r_1[1];
                y_inter_1[3] = y_r_1[3] + A_r_1[3][1] * x_r_1[1];
            end
            if (i_dv_r[2]) begin
                y_inter_2[0] = y_r_2[0] + A_r_2[0][2] * x_r_2[2];
                y_inter_2[1] = y_r_2[1] + A_r_2[1][2] * x_r_2[2];
                y_inter_2[2] = y_r_2[2] + A_r_2[2][2] * x_r_2[2];
                y_inter_2[3] = y_r_2[3] + A_r_2[3][2] * x_r_2[2];
            end
            if (i_dv_r[3]) begin
                y_inter_3[0] = y_r_3[0] + A_r_3[0][3] * x_r_3[3];
                y_inter_3[1] = y_r_3[1] + A_r_3[1][3] * x_r_3[3];
                y_inter_3[2] = y_r_3[2] + A_r_3[2][3] * x_r_3[3];
                y_inter_3[3] = y_r_3[3] + A_r_3[3][3] * x_r_3[3];
            end
        end
    end

    // Register outputs
    always_ff @(posedge clk) begin
        if (~rstn) begin
            foreach (y[i]) y[i] <= '0;
            o_dv <= '0;
        end else begin
            if (i_enable) begin
                y_r_1 <= y_inter_0;
                y_r_2 <= y_inter_1;
                y_r_3 <= y_inter_2;

                y[0] <= {y_inter_3[0][2*DATAWIDTH], y_inter_3[0][OutputRangeEnd-1:OutputRangeStart]};
                y[1] <= {y_inter_3[1][2*DATAWIDTH], y_inter_3[1][OutputRangeEnd-1:OutputRangeStart]};
                y[2] <= {y_inter_3[2][2*DATAWIDTH], y_inter_3[2][OutputRangeEnd-1:OutputRangeStart]};
                y[3] <= {y_inter_3[3][2*DATAWIDTH], y_inter_3[3][OutputRangeEnd-1:OutputRangeStart]};


                o_dv <= i_dv_r[3];
            end

            if (o_dv & i_enable) begin
                $display("y[0] = %b", y[0]);
                $display("y[1] = %b", y[1]);
                $display("y[2] = %b", y[2]);
                $display("y[3] = %b", y[3]);
                $display("\n");
            end
        end
    end
endmodule
