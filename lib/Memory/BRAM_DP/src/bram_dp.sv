module bram_dp #(
    parameter unsigned WIDTH = 16,
    parameter unsigned DEPTH = 32,
    parameter string FILE = ""
) (
    input wire clk_write,
    input wire clk_read,
    input wire write_enable,
    input wire [$clog2(DEPTH)-1:0] addr_write,
    input wire [$clog2(DEPTH)-1:0] addr_read,
    input wire [WIDTH-1:0] data_in,
    output reg [WIDTH-1:0] data_out
);

    logic [WIDTH-1:0] memory [DEPTH];

    initial begin
        if (FILE != "") begin
            $readmemh(FILE, memory);
        end
    end

    always_ff @(posedge clk_write) begin
        if (write_enable) begin
            memory[addr_write] <= data_in;
        end
    end

    always_ff @(posedge clk_read) begin
        data_out <= memory[addr_read];
    end

endmodule
