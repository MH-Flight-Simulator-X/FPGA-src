`default_nettype none
`timescale 1ns / 1ps

// Generate 100 MHz with 20 MHz input clock
module clock_100Mhz (
    input  wire logic clk_20m,        // input clock (20 MHz)
    input  wire logic rst,            // reset
    output      logic clk_100m,       // 100 MHz clock
    output      logic clk_100m_5x,    // 5x clock (600 MHz from VCO)
    output      logic clk_100m_locked // clock locked
    );

    // Parameters for generating 100 MHz from 20 MHz
    localparam MULT_MASTER = 30;      // Multiply by 30
    localparam DIV_MASTER = 1;        // No division for VCO
    localparam DIV_5X = 1;            // Pass-through VCO frequency (600 MHz) to clk_100m_5x
    localparam DIV_1X = 6;            // Divide by 6 to get 100 MHz for clk_100m
    localparam IN_PERIOD = 50.0;      // Period of 20 MHz input clock in ns

    logic feedback;            // Internal clock feedback
    logic clk_100m_unbuf;      // Unbuffered 100 MHz clock
    logic clk_100m_5x_unbuf;   // Unbuffered 5x clock (600 MHz VCO frequency)
    logic locked;              // Unsynced lock signal

    MMCME2_BASE #(
        .CLKFBOUT_MULT_F(MULT_MASTER),
        .CLKIN1_PERIOD(IN_PERIOD),
        .CLKOUT0_DIVIDE_F(DIV_5X),   // Output 600 MHz directly for clk_100m_5x
        .CLKOUT1_DIVIDE(DIV_1X),     // Divide by 6 for 100 MHz
        .DIVCLK_DIVIDE(DIV_MASTER)
    ) MMCME2_BASE_inst (
        .CLKIN1(clk_20m),
        .RST(rst),
        .CLKOUT0(clk_100m_5x_unbuf),
        .CLKOUT1(clk_100m_unbuf),
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

    // Buffer output clocks
    BUFG bufg_clk(.I(clk_100m_unbuf), .O(clk_100m));
    BUFG bufg_clk_5x(.I(clk_100m_5x_unbuf), .O(clk_100m_5x));

    // Synchronize the lock signal with clk_100m
    logic locked_sync_0;
    always_ff @(posedge clk_100m) begin
        locked_sync_0 <= locked;
        clk_100m_locked <= locked_sync_0;
    end
endmodule

