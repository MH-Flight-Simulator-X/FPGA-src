// Framebuffer for a display of custom size

`timescale 1ns / 1ps

module framebuffer #(
    parameter FB_WIDTH,
    parameter FB_HEIGHT,
    parameter DATA_WIDTH,
    localparam FB_SIZE = FB_WIDTH*FB_HEIGHT,
    localparam ADDR_WIDTH = $clog2(FB_SIZE)
    ) (
    input wire clk_write,
    input wire clk_read,
    input wire write_enable,
    input wire rst,
    input wire [ADDR_WIDTH-1:0] addr_write,
    input wire [ADDR_WIDTH-1:0] addr_read,
    input wire [DATA_WIDTH-1:0] data_in, 
    output reg [DATA_WIDTH-1:0] data_out
    );

    logic [DATA_WIDTH-1:0] buffer [0:FB_SIZE-1];

    always_ff @(posedge clk_write or posedge rst) begin
        if (rst) begin
            integer i;
            for (i = 0; i < FB_SIZE; i = i + 1) begin
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

