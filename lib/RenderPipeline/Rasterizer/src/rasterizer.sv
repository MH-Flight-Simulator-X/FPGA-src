// Top level module for the rasterizer. Incorporates both the rasterizer
// front-end and back-end.

`timescale 1ns / 1ps

module rasterizer #(
    parameter unsigned DATAWIDTH = 12,
    parameter unsigned SCREEN_WIDTH = 320,
    parameter unsigned SCREEN_HEIGHT = 320
    ) (
    input logic clk,
    input logic rstn,

    output logic ready,

    input logic signed [DATAWIDTH-1:0] i_v0[3],
    input logic signed [DATAWIDTH-1:0] i_v1[3],
    input logic signed [DATAWIDTH-1:0] i_v2[3],
    input logic i_triangle_dv,
    input logic i_triangle_last

    // OUPUT SIGNALS FROM THE RASTERIZER BACKEND
    );

    // Is the rasterizer backend ready for a new triangle
    logic w_rasterizer_backend_ready;

    // Output signals from rasterizer frontend
    logic signed [DATAWIDTH-1:0] w_bb_tl[2];
    logic signed [DATAWIDTH-1:0] w_bb_br[2];

    logic signed [2*DATAWIDTH-1:0] w_edge_val0;
    logic signed [2*DATAWIDTH-1:0] w_edge_val1;
    logic signed [2*DATAWIDTH-1:0] w_edge_val2;

    logic signed [DATAWIDTH-1:0] w_edge_delta0[2];
    logic signed [DATAWIDTH-1:0] w_edge_delta1[2];
    logic signed [DATAWIDTH-1:0] w_edge_delta2[2];
    logic unsigned [2*DATAWIDTH-1:0] w_area_inv;
    logic w_rasterizer_frontend_o_dv;

    rasterizer_frontend #(
        .DATAWIDTH(DATAWIDTH),
        .SCREEN_MIN_X(0),
        .SCREEN_MAX_X(SCREEN_WIDTH),
        .SCREEN_MIN_Y(0),
        .SCREEN_MAX_Y(SCREEN_HEIGHT)
    ) rasterizer_frontend_inst (
        .clk(clk),
        .rstn(rstn),

        .ready(ready),
        .next(w_rasterizer_backend_ready),

        .i_v0(i_v0),
        .i_v1(i_v1),
        .i_v2(i_v2),
        .i_triangle_dv(i_triangle_dv),

        .bb_tl(w_bb_tl),
        .bb_br(w_bb_br),

        .edge_val0(w_edge_val0),
        .edge_val1(w_edge_val1),
        .edge_val2(w_edge_val2),

        .edge_delta0(w_edge_delta0),
        .edge_delta1(w_edge_delta1),
        .edge_delta2(w_edge_delta2),
        .area_inv(w_area_inv),
        .o_dv(w_rasterizer_frontend_o_dv)
    );

    always_ff @(posedge clk) begin
        if (~rstn) begin
        end else begin
        end
    end

endmodule
