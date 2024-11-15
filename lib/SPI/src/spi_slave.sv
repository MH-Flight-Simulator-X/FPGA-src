// Module for SPI Slave
// Based on https://github.com/nandland/spi-slave
// Ensure clk input is at least 4x SCK

`timescale 1ns / 1ps

module spi_slave (
    input clk,
    // input rstn,

    // Data signals
    output reg o_RX_DV,
    output reg [7:0] o_RX_Byte,
    // input i_TX_DV,           // TODO: Implement TX
    // input [7:0] i_TX_Byte,

    // SPI Signals
    input SCK,
    output reg MISO,
    input MOSI,
    input CSn
    );

    logic [2:0] r_RX_Bit_Count;
    /* verilator lint_off UNUSED */
    logic [7:0] r_Intermediate_RX_Byte; // Will be used to ensure MSB when byte is finished
    /* verilator lint_on UNUSED */
    logic [7:0] r_RX_Byte;
    logic r_RX_Done, r_RX_Done_1, r_RX_Done_2; // Shift register for CDC from SPI to system

    always_ff @(posedge SCK or posedge CSn) begin
        if (CSn) begin
            r_RX_Bit_Count <= '0;
            r_RX_Done <= 1'b0;
        end else begin
            r_RX_Bit_Count <= r_RX_Bit_Count + 1;
            r_Intermediate_RX_Byte <= {r_Intermediate_RX_Byte[6:0], MOSI};

            if (r_RX_Bit_Count == 3'b111) begin
                r_RX_Done <= 1'b1;
                r_RX_Byte <= {r_Intermediate_RX_Byte[6:0], MOSI};
            end else if (r_RX_Bit_Count == 3'b010) begin
                r_RX_Done <= 1'b0;
            end
        end
    end

    // Cross from SPI Clock domain to system clock domain
    always_ff @(posedge clk) begin
        //if (~rstn) begin
        //    r_RX_Done_1 <= 1'b0;
        //    r_RX_Done_2 <= 1'b0;
        //    o_RX_Byte <= '0;
        //    o_RX_DV <= 1'b0;
        //end else begin
        //end
        // Shift RX_Done signal
        r_RX_Done_1 <= r_RX_Done;
        r_RX_Done_2 <= r_RX_Done_1;

        if (r_RX_Done_2 == 1'b0 & r_RX_Done_1 == 1'b1) begin
            // Rising edge
            o_RX_DV <= 1'b1;
            o_RX_Byte <= r_RX_Byte;
        end else begin
            o_RX_DV <= 1'b0;
        end
    end
endmodule
