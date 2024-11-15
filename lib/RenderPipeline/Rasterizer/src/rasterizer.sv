// Top level module for the rasterizer. Incorporates both the rasterizer
// front-end and back-end.

`timescale 1ns / 1ps

module rasterizer #(
    parameter unsigned DATAWIDTH = 12,
    parameter unsigned COLORWIDTH = 4,
    parameter unsigned SCREEN_WIDTH = 320,
    parameter unsigned SCREEN_HEIGHT = 320,
    parameter unsigned ADDRWIDTH = $clog2(SCREEN_WIDTH + SCREEN_HEIGHT)
    ) (
    input logic clk,
    input logic rstn,

    output logic ready,

    // INPUT SIGNALS TO THE RASTERIZER FRONTEND
    input logic signed [DATAWIDTH-1:0] i_v0[3],
    input logic signed [DATAWIDTH-1:0] i_v1[3],
    input logic signed [DATAWIDTH-1:0] i_v2[3],
    input logic i_triangle_dv,
    input logic i_triangle_last,

    // OUPUT SIGNALS FROM THE RASTERIZER BACKEND
    output logic [ADDRWIDTH-1:0] o_fb_addr_write,
    output logic o_fb_write_en,

    output logic [DATAWIDTH-1:0] o_fb_depth_data,
    output logic [COLORWIDTH-1:0] o_fb_color_data,

    output logic finished
    );

    // ========== RASTERIZER FRONTEND ==========
    logic signed [DATAWIDTH-1:0] w_bb_tl[2];
    logic signed [DATAWIDTH-1:0] w_bb_br[2];

    logic signed [2*DATAWIDTH-1:0] w_edge_val0;
    logic signed [2*DATAWIDTH-1:0] w_edge_val1;
    logic signed [2*DATAWIDTH-1:0] w_edge_val2;

    logic signed [DATAWIDTH-1:0] w_edge_delta0[2];
    logic signed [DATAWIDTH-1:0] w_edge_delta1[2];
    logic signed [DATAWIDTH-1:0] w_edge_delta2[2];

    logic signed [DATAWIDTH-1:0] w_z_coeff;
    logic signed [DATAWIDTH-1:0] w_z_coeff_delta[2];

    logic w_rasterizer_frontend_o_dv;

    rasterizer_frontend #(
        .DATAWIDTH(DATAWIDTH),
        .SCREEN_WIDTH(SCREEN_WIDTH),
        .SCREEN_HEIGHT(SCREEN_HEIGHT)
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

        .z_coeff(w_z_coeff),
        .z_coeff_delta(w_z_coeff_delta),

        .o_dv(w_rasterizer_frontend_o_dv)
    );

    // ========== RASTERIZER BACKEND ==========
    logic w_rasterizer_backend_ready;
    logic w_rasterizer_backend_done;

    rasterizer_backend #(
        .DATAWIDTH(DATAWIDTH),
        .COLORWIDTH(COLORWIDTH),
        .SCREEN_WIDTH(SCREEN_WIDTH),
        .SCREEN_HEIGHT(SCREEN_HEIGHT)
    ) rasterizer_backend_inst (
        .clk(clk),
        .rsnt(rstn),

        .bb_tl(w_bb_tl),
        .bb_br(w_bb_br),

        .edge_val0(w_edge_val0),
        .edge_val1(w_edge_val1),
        .edge_val2(w_edge_val2),

        .edge_delta0(w_edge_delta0),
        .edge_delta1(w_edge_delta1),
        .edge_delta2(w_edge_delta2),

        .z(w_z_coeff),
        .z_delta(w_z_coeff_delta),

        .addr_start(w_addr_start),
        .i_dv(w_rasterizer_frontend_o_dv),

        .o_fb_addr_write(o_fb_addr_write),
        .o_fb_write_en(o_fb_write_en),

        .o_fb_depth_data(o_fb_depth_data),
        .o_fb_color_data(o_fb_color_data),

        .ready(w_rasterizer_backend_ready),
        .done(w_rasterizer_backend_done)
    );

    // Check if we are finished
    logic last_triangle_last;
    always_ff @(posedge clk) begin
        if (~rstn) begin
            finished <= '0;
        end else begin
            if (i_triangle_dv) begin
                last_triangle_last <= i_triangle_last;
            end

            if (w_rasterizer_backend_done) begin
                if (i_triangle_dv) begin
                    finished <= 1'b1;
                end else begin
                    finished <= 1'b0;
                end
            end else begin
                finished <= 1'b0;
            end
        end
    end

endmodule
