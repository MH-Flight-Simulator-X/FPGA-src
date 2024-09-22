// Framebuffer for a display of custom size

`timescale 1ps / 1ps

module framebuffer #(
    parameter SCREEN_WIDTH,
    parameter SCREEN_HEIGHT,
    parameter INDEX_WIDTH,
    localparam BUFFER_SIZE = SCREEN_WIDTH*SCREEN_HEIGHT,
    localparam ADDR_WIDTH = $clog2(BUFFER_SIZE)
    ) (
    input wire clk_write,
    input wire clk_read,
    input wire write_enable,
    input wire rst,
    input wire [ADDR_WIDTH-1:0] addr_write,
    input wire [ADDR_WIDTH-1:0] addr_read,
    input wire [INDEX_WIDTH-1:0] data_in, 
    output reg [INDEX_WIDTH-1:0] data_out
    );

    logic [INDEX_WIDTH-1:0] buffer [0:BUFFER_SIZE-1]; 

    always_ff @(posedge clk_write or posedge rst) begin
        if (rst) begin
            integer i;
            for (i = 0; i < BUFFER_SIZE; i = i + 1) begin
                buffer[i] <= '0;
            end
        end else if (write_enable) begin
            buffer[addr_write] <= data_in;
        end
    end

    always_ff @(posedge clk_read) begin
        data_out <= buffer[addr_read]; 
    end

endmodule
