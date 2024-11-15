// read only memory

`timescale 1ns / 1ps

module rom#(
    parameter unsigned WIDTH = 12,
    parameter unsigned DEPTH = 16,
    parameter string FILE = "data.mem"
    ) (
    input logic clk,
    input logic [$clog2(DEPTH)-1:0] addr,
    output logic [WIDTH-1:0] data
    );

    logic [WIDTH-1:0] memory [DEPTH];

    initial begin
        $readmemh(FILE, memory);
    end

    always_ff @(posedge clk) begin
        data <= memory[addr];
    end

endmodule
