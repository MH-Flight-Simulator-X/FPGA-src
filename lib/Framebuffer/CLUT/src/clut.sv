// Create a color lookup table from a file

`timescale 1ps / 1ps

module clut#(
    parameter SIZE,
    parameter COLOR_WIDTH,
    parameter FILE,
    localparam ADDR_WIDTH = $clog2(SIZE)
    ) (
    input wire clk,
    input wire [ADDR_WIDTH-1:0] addr,
    output reg [COLOR_WIDTH-1:0] color
    );

    logic [COLOR_WIDTH-1:0] colors [0:SIZE-1];

    initial begin
        $readmemh(FILE, colors);
    end

    always_ff @(clk) begin
        color <= colors[addr]; 
    end

endmodule
