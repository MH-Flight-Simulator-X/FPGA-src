`timescale 1ns / 1ps

module spi_test(
    input clk,
    input rst,

    input SCK,
    output reg MISO,
    input MOSI,
    input CSn,

    output logic [6:0] seg,
    output logic [3:0] an,
    output logic [4:0] LED,

    output logic [7:0] ByteLED
    );

    logic [7:0] w_RX_Byte;
    logic w_RX_DV;

    logic [7:0] most_recent_byte;

    wire SCK_IBUF;
    IBUFG sck_ibuf_inst (.I(SCK), .O(SCK_IBUF));

    spi_slave spi_slave_instance (
        .clk(clk),
        .rstn(~rst),
        .o_RX_Byte(w_RX_Byte),
        .o_RX_DV(w_RX_DV),

        .i_TX_DV(),
        .i_TX_Byte(),

        .SCK(SCK_IBUF),
        .MISO(MISO),
        .MOSI(MOSI),
        .CSn(CSn)
    );

    logic valid_data_display = '0;
    logic [15:0] display_bytes = '0;

    always_ff @(posedge w_RX_DV) begin
        valid_data_display <= 1;
        display_bytes <= {display_bytes[7:0], w_RX_Byte};
        most_recent_byte <= w_RX_Byte;
    end

    hex_display hex_display_instance (
        .clk(clk),
        .i_byte(display_bytes),
        .seg(seg),
        .an(an)
    );

    assign LED[0] = valid_data_display;
    assign LED[1] = rst;
    assign LED[2] = SCK_IBUF;
    assign LED[3] = MOSI;
    assign LED[4] = CSn;

    assign ByteLED = most_recent_byte;
endmodule
