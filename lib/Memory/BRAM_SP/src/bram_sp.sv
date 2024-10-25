// This is a pseudo single ported bram

`timescale 1ns / 1ps

module bram_sp #(
    parameter unsigned WIDTH = 36,
    parameter unsigned DEPTH = 1024
    ) (
    input logic clk,
    input logic en,
    input logic rw,     // rw = 1 -> write, rw = 0 -> read

    input logic [$clog2(DEPTH)-1:0] addr,
    input logic [WIDTH-1:0] data_in,
    output logic [WIDTH-1:0] data_out
    );

    logic [WIDTH-1:0] memory [DEPTH];

    always_ff @(posedge clk) begin
        if (en) begin
            if (rw) begin
                memory[addr] <= data_in;
            end else begin
                data_out <= memory[addr];
            end
        end
    end
endmodule
