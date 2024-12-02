// read only memory

`timescale 1ps / 1ps

module rom #(
    parameter unsigned WIDTH = 12,
    parameter unsigned DEPTH = 16,
    parameter string FILE = "data.mem",
    parameter unsigned BIN = 0
    ) (
    input logic clk,
    input logic [$clog2(DEPTH)-1:0] addr,
    output logic [WIDTH-1:0] data
    );

    logic [WIDTH-1:0] memory [DEPTH];

    initial begin
        if (BIN == 1) begin
            $readmemb(FILE, memory);
        end else begin
            $readmemh(FILE, memory);
        end
    end

    always_ff @(posedge clk) begin
        data <= memory[addr];
    end

endmodule
