`timescale 1ns / 1ps

module primitive_assembler #(
        parameter unsigned INPUT_VERTEX_DATAWIDTH = 24,
        parameter unsigned INPUT_VERTEX_FRACBITS = 13,

        parameter unsigned OUTPUT_VERTEX_DATAWIDTH = 12,
        parameter unsigned OUTPUT_VERTEX_DEPTH_FRACBITS = 12,   // Unsigned Q0.12 format

        parameter unsigned MAX_TRIANGLE_COUNT = 2048
    ) (
        input logic clk,
        input logic rstn,

        input logic start,
        output logic ready,

        // Index buffer size
        input logic [$clog2(MAX_TRIANGLE_COUNT)-1:0] i_num_triangles,
        output logic [$clog2(MAX_TRIANGLE_COUNT)-1:0] o_triangle_addr,
        output logic o_triangle_read_en,

        input logic [$clog2(3 * MAX_TRIANGLE_COUNT)-1:0] i_triangle_idx[3],

        output logic [$clog2(3 * MAX_TRIANGLE_COUNT)-1:0] o_vertex_addr,
        output logic o_vertex_read_en,
        input logic signed [INPUT_VERTEX_DATAWIDTH - 1:0] i_vertex[3][3],

        // Output primitive
        output logic signed [OUTPUT_VERTEX_DATAWIDTH-1:0] o_vertex_pixel[3][2],
        output logic unsigned [OUTPUT_VERTEX_DEPTH_FRACBITS-1:0] o_vertex_z[3],
        output logic o_vertex_dv
    );

endmodule
