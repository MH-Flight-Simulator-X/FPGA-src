// Framebuffer for a display of custom size

`timescale 1ps / 1ps

module framebuffer #(
    parameter SCREEN_WIDTH,
    parameter SCREEN_HEIGHT,
    parameter INDEX_WIDTH,
    localparam BUFFER_WIDTH = $clog2(SCREEN_WIDTH*SCREEN_HEIGHT)
    ) (
    input wire logic clk_write,
    input wire logic clk_read,
    input wire logic write_enable,
    input wire logic rst,
    input wire logic [BUFFER_WIDTH-1:0] addr_write,
    input wire logic [BUFFER_WIDTH-1:0] addr_read,
    input wire logic [INDEX_WIDTH-1:0] data_in,
    
    output [INDEX_WIDTH-1:0] data_out
    );

    logic [INDEX_WIDTH-1:0] buffer [0:BUFFER_WIDTH]; 

    always_ff @(posedge clk_write or posedge rst) begin
        if (rst) begin
            integer i;
            for (i = 0; i < BUFFER_WIDTH; i = i + 1) begin
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
