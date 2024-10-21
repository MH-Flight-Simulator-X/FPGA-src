// Create a color lookup table from a file

`timescale 1ns / 1ps

module clut#(
    parameter unsigned SIZE,
    parameter unsigned COLOR_WIDTH,
    parameter string FILE,
    parameter unsigned ADDR_WIDTH = $clog2(SIZE)
    ) (
    input wire clk,
    input wire [ADDR_WIDTH-1:0] addr,
    output reg [COLOR_WIDTH-1:0] color
    );

    logic [COLOR_WIDTH-1:0] colors [SIZE];

    initial begin
        $readmemh(FILE, colors);
    end

    always_ff @(posedge clk) begin
        color <= colors[addr];
    end

endmodule
