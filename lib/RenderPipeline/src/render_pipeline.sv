`timescale 1ns / 1ps

module render_pipeline #(
    parameter unsigned INPUT_DATAWIDTH = 24,
    parameter unsigned INPUT_FRACBITS  = 13,
    parameter unsigned OUTPUT_DATAWIDTH = 12,

    parameter unsigned MAX_TRIANGLE_COUNT = 4096,
    parameter unsigned MAX_VERTEX_COUNT   = 4096,

    parameter unsigned SCREEN_WIDTH  = 320,
    parameter unsigned SCREEN_HEIGHT = 320,

    parameter real ZFAR = 100.0,
    parameter real ZNEAR = 0.1
    ) (
    input logic clk,
    input logic rstn
    );

    // Vertex shader
    vertex_shader #(
        .DATAWIDTH(INPUT_DATAWIDTH),
        .FRACBITS(INPUT_FRACBITS)
    ) vertex_shader_inst (
        .clk(clk),
        .rstn(rstn),
    );

    // Vertex Post Processor
    vertex_post_processor #(
        .IV_DATAWIDTH(INPUT_DATAWIDTH),
        .IV_FRACBITS(INPUT_FRACBITS),
        .OV_DATAWIDTH(OUTPUT_DATAWIDTH),

        .WIDTH(SCREEN_WIDTH),
        .HEIGHT(SCREEN_HEIGHT),

        .ZFAR(ZFAR),
        .ZNEAR(ZNEAR)
    ) vertex_post_processor_inst (
        .clk(clk),
        .rstn(rstn),
    );

    // Geometry buffer
    g_buffer #(
        .VERTEX_DATAWIDTH(OUTPUT_DATAWIDTH),
        .MAX_VERTEX_COUNT(MAX_VERTEX_COUNT)
    ) g_buffer_inst (
        .clk(clk),
        .rstn(rstn),
    );

    // Primitive assembler
    primitive_assembler #(
        .DATAWIDTH(OUTPUT_DATAWIDTH),
        .SCREEN_WIDTH(SCREEN_WIDTH),
        .MAX_TRIANGLE_COUNT(MAX_TRIANGLE_COUNT),
        .MAX_VERTEX_COUNT(MAX_VERTEX_COUNT)
    ) primitive_assembler_inst (
        .clk(clk),
        .rstn(rstn),
    );

    // TODO: Replace with finished Rasterizer
    rasterizer_frontend #(
        .DATAWIDTH(OUTPUT_DATAWIDTH),
        .SCREEN_WIDTH(SCREEN_WIDTH),
        .SCREEN_HEIGHT(SCREEN_HEIGHT)
    ) rasterizer_frontend_inst (
        .clk(clk),
        .rstn(rstn),
    );

endmodule
