// read only memory

`timescale 1ns / 1ps

module rom#(
    parameter unsigned WIDTH = 12,
    parameter unsigned DEPTH = 16,
    parameter string FILE = "data.mem"
    ) (
    input logic clk,
    input logic read_en,
    input logic [$clog2(DEPTH)-1:0] addr,
    output logic [WIDTH-1:0] data,
    output logic dv
    );

    logic [WIDTH-1:0] memory [DEPTH];

    initial begin
        $readmemh(FILE, memory);
    end

    always_ff @(posedge clk) begin
        data <= memory[addr];
        if (read_en) begin
            dv <= 1'b1;
        end else begin
            dv <= 1'b0;
        end
    end

endmodule
