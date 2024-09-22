`timescale 1ns / 1ps

module top_MH_FPGA
    (
        input clk,
        input rstn,
        output signed [17:0] C[4][4],
        output o_dv,
        output o_ready
    );

    logic signed [17:0] A [4][4];
    logic signed [17:0] B [4][4];
    logic i_dv = '0;

    mat_mat_mul_dim_4 #(
        .DATAWIDTH(18)
    ) dut (
        .clk(clk),
        .rstn(rstn),
        .A(A),
        .B(B),
        .i_dv(i_dv),
        .C(C),
        .o_dv(o_dv),
        .o_ready(o_ready)
    );

    always @(posedge clk) begin
        foreach (A[i, j]) A[i][j] <= A[i][j] + 1;
        foreach (B[i, j]) B[i][j] <= A[i][j] + 2 * B[i][j];
    end

    always @(posedge clk) begin
        if (o_ready) begin
            i_dv <= 1'b1;
        end else begin
            i_dv <= 1'b1;
        end
    end

endmodule
