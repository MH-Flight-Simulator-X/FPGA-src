// read only memory

`timescale 1ns / 1ps

module rom#(
    parameter unsigned WIDTH = 12,
    parameter unsigned DEPTH = 16,
    parameter string FILE = "data.mem"
    ) (
    input wire clk,
    input wire [$clog2(WIDTH)-1:0] addr,
    output reg [DEPTH-1:0] data
    );

    logic [DEPTH-1:0] memory [WIDTH];

    initial begin
        $readmemh(FILE, memory);
    end

    always_ff @(posedge clk) begin
        data <= memory[addr];
    end

endmodule
