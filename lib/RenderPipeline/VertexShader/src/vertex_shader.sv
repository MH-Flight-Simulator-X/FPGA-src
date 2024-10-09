`timescale 1ns / 1ps

module vertex_shader #(
        parameter unsigned NUM_CORES = 1,
        parameter unsigned DATAWIDTH = 18,
        parameter unsigned FRACBITS = 12
    )(
        input clk,
        input rstn,

        input logic signed [DATAWIDTH-1:0] model_mat[4][4],
        input logic signed [DATAWIDTH-1:0] view_mat[4][4],
        input logic signed [DATAWIDTH-1:0] proj_mat[4][4],
        input logic i_mat_dv
    );

    // Input and output signals for matrix multiplier
    logic signed [DATAWIDTH-1:0] r_mat_a[4][4];
    logic signed [DATAWIDTH-1:0] r_mat_b[4][4];
    logic r_mat_mul_i_dv;

    logic signed [DATAWIDTH-1:0] w_mat_c[4][4];
    logic w_mat_mul_o_dv;
    logic w_mat_mul_o_ready;

    // Finished matricies
    logic signed [DATAWIDTH-1:0] r_view_proj_mat;
    logic signed [DATAWIDTH-1:0] r_mvp_mat;
    logic mvp_valid;

    // Matrix Matrix Multiplication Unit Instance
    mat_mul #(
        .DATAWIDTH(DATAWIDTH),
        .FRACBITS(FRACBITS)
    ) mat_mul_inst (
        .clk(clk),
        .rstn(rstn),

        .A(r_mat_a),
        .B(r_mat_b),
        .i_dv(r_mat_mul_i_dv),

        .C(w_mat_c),
        .o_dv(w_mat_mul_o_dv),
        .o_ready(w_mat_mul_o_ready)
    );

    // Matrix Vector Multiplication Unit Instance
    mat_vec_mul #(
        .DATAWIDTH(DATAWIDTH),
        .FRACBITS(FRACBITS)
    ) mat_vec_mul_inst (
        .clk(clk),
        .rstn(rstn),


    );

endmodule
