module sin_cos_lu #(
    parameter unsigned DATA_WIDTH = 24,
    parameter unsigned ADDR_WIDTH = 12
) (
    input logic clk,
    input logic [ADDR_WIDTH-1:0] angle,
    output logic signed [DATA_WIDTH-1:0] sine,
    output logic signed [DATA_WIDTH-1:0] cosine
);

    logic signed [DATA_WIDTH-1:0] sine_rom [1 << ADDR_WIDTH];
    logic signed [DATA_WIDTH-1:0] cosine_rom [1 << ADDR_WIDTH];

    initial begin
        $readmemh("sine_lut.mem", sine_rom);
        $readmemh("cosine_lut.mem", cosine_rom);
    end

    always_ff @(posedge clk) begin
        sine <= sine_rom[angle];
        cosine <= cosine_rom[angle];
    end
endmodule
