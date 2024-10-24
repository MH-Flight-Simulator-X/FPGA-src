`timescale 1ns / 1ps

module bram_qp #(
    parameter unsigned DATAWIDTH = 8,
    parameter unsigned DEPTH = 16,
    parameter string FILE = ""
    ) (
    input logic rstn,

    input logic clk_write,
    input logic write_en,

    input logic clk_read_port_0,
    input logic read_en_port_0,

    input logic clk_read_port_1,
    input logic read_en_port_1,

    input logic clk_read_port_2,
    input logic read_en_port_2,

    input logic [$clog2(DEPTH)-1:0] addr_write,
    input logic [$clog2(DEPTH)-1:0] addr_read_port_0,
    input logic [$clog2(DEPTH)-1:0] addr_read_port_1,
    input logic [$clog2(DEPTH)-1:0] addr_read_port_2,

    input logic [DATAWIDTH-1:0] write_data,
    output logic [DATAWIDTH-1:0] read_data_port_0,
    output logic [DATAWIDTH-1:0] read_data_port_1,
    output logic [DATAWIDTH-1:0] read_data_port_2,

    output logic read_dv_port_0,
    output logic read_dv_port_1,
    output logic read_dv_port_2
    );

    logic [WIDTH-1:0] bram [DEPTH];

    initial begin
        if (FILE != "") begin
            $readmemh(FILE, bram);
        end
    end

    always_ff @(posedge clk_write) begin
        if (write_enable) begin
            bram[addr_write] <= write_data;
        end
    end

    always_ff @(posedge clk_read_port_0) begin
        if (read_en_port_0) begin
            read_data_port_0 <= bram[addr_read_port_0];
            read_dv_port_0 <= '1;
        end else begin
            read_dv_port_0 <= '0;
        end
    end

    always_ff @(posedge clk_read_port_1) begin
        if (read_en_port_1) begin
            read_data_port_1 <= bram[addr_read_port_1];
            read_dv_port_1 <= '1;
        end else begin
            read_dv_port_1 <= '0;
        end
    end

    always_ff @(posedge clk_read_port_2) begin
        if (read_en_port_2) begin
            read_data_port_2 <= bram[addr_read_port_2];
            read_dv_port_2 <= '1;
        end else begin
            read_dv_port_2 <= '0;
        end
    end

endmodule
