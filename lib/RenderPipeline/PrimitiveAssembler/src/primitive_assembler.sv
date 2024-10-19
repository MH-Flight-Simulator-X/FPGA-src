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
        input logic 

        input logic signed [INPUT_VERTEX_DATAWIDTH - 1:0] ,

        // Output primitive
        output logic signed [OUTPUT_VERTEX_DATAWIDTH-1:0] o_vertex_pixel[3][2],
        output logic unsigned [OUTPUT_VERTEX_DEPTH_FRACBITS-1:0] o_vertex_z[3],
        output logic o_vertex_dv
    );

endmodule
