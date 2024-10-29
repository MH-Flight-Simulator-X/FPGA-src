`timescale 1ns / 1ps

module mh_fpga_test(
    input logic clk,
    output logic led
);

    // Create a 16 bit counter that sets the led on when the MSB is 1
    logic [23:0] counter;
    always_ff @(posedge clk) begin
        counter <= counter + 1;
        led <= counter[23];
    end
endmodule
