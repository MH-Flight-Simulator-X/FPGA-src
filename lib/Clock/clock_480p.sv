// Project F Library - 640x480p60 Clock Generation (XC7)
// Copyright Will Green, open source hardware released under the MIT License
// Learn more at https://projectf.io

`default_nettype none
`timescale 1ns / 1ps

// Generate 25.2 MHz (640x480 60 Hz) with 100 MHz input clock
// MMCME2_BASE and BUFG are documented in Xilinx UG472

`ifdef VERILATOR
module clock_480p (
    input  wire logic clk_100m,       // input clock (100 MHz)
    input  wire logic rst,            // reset
    output      logic clk_pix,        // pixel clock
    output      logic clk_pix_5x,     // 5x clock for 10:1 DDR SerDes
    output      logic clk_pix_locked  // pixel clock locked?
);
    assign clk_pix = clk_100m;
    assign clk_pix_5x = clk_100m;
    assign clk_pix_locked = 1'b1;
endmodule

`else

module clock_480p (
    input  wire logic clk_100m,       // input clock (100 MHz)
    input  wire logic rst,            // reset
    output      logic clk_pix,        // pixel clock
    output      logic clk_pix_5x,     // 5x clock for 10:1 DDR SerDes
    output      logic clk_pix_locked  // pixel clock locked?
    );

    localparam MULT_MASTER=31.5;  // master clock multiplier (2.000-64.000)
    localparam DIV_MASTER=5;      // master clock divider (1-106)
    localparam DIV_5X=5.0;        // 5x pixel clock divider
    localparam DIV_1X=25;         // pixel clock divider
    localparam IN_PERIOD=10.0;    // period of master clock in ns (10 ns == 100 MHz)

    logic feedback;          // internal clock feedback
    logic clk_pix_unbuf;     // unbuffered pixel clock
    logic clk_pix_5x_unbuf;  // unbuffered 5x pixel clock
    logic locked;            // unsynced lock signal

    MMCME2_BASE #(
        .CLKFBOUT_MULT_F(MULT_MASTER),
        .CLKIN1_PERIOD(IN_PERIOD),
        .CLKOUT0_DIVIDE_F(DIV_5X),
        .CLKOUT1_DIVIDE(DIV_1X),
        .DIVCLK_DIVIDE(DIV_MASTER)
    ) MMCME2_BASE_inst (
        .CLKIN1(clk_100m),
        .RST(rst),
        .CLKOUT0(clk_pix_5x_unbuf),
        .CLKOUT1(clk_pix_unbuf),
        .LOCKED(locked),
        .CLKFBOUT(feedback),
        .CLKFBIN(feedback),
        /* verilator lint_off PINCONNECTEMPTY */
        .CLKOUT0B(),
        .CLKOUT1B(),
        .CLKOUT2(),
        .CLKOUT2B(),
        .CLKOUT3(),
        .CLKOUT3B(),
        .CLKOUT4(),
        .CLKOUT5(),
        .CLKOUT6(),
        .CLKFBOUTB(),
        .PWRDWN()
        /* verilator lint_on PINCONNECTEMPTY */
    );

    // explicitly buffer output clocks
    BUFG bufg_clk(.I(clk_pix_unbuf), .O(clk_pix));
    BUFG bufg_clk_5x(.I(clk_pix_5x_unbuf), .O(clk_pix_5x));

    // ensure clock lock is synced with pixel clock
    logic locked_sync_0;
    always_ff @(posedge clk_pix) begin
        locked_sync_0 <= locked;
        clk_pix_locked <= locked_sync_0;
    end
endmodule

`endif
