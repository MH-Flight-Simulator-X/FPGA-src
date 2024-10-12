// Syncronous FIFO Module

`timescale 1ns/1ps

module sync_fifo #(
    parameter unsigned DATAWIDTH,
    parameter unsigned DEPTH
    ) (
    input logic rstn,

    input logic write_clk,
    input logic read_clk,
    input logic read_en,
    input logic write_en,

    output logic read_prev,

    input logic  [DATAWIDTH-1:0] data_in,
    output logic [DATAWIDTH-1:0] data_out,

    output logic empty,
    output logic full
    );

    // Read/Write data pointers
    logic [$clog2(DEPTH)-1:0] write_ptr;
    logic [$clog2(DEPTH)-1:0] read_ptr;

    // Data declaration
    logic [DATAWIDTH-1:0] fifo[DEPTH];

    // Write logic
    always_ff @(posedge write_clk) begin
        if (~rstn) begin
            write_ptr <= 0;
        end else begin
            if (write_en & ~full) begin
                fifo[write_ptr] <= data_in;
                write_ptr <= write_ptr + 1;
            end
        end
    end

    // Read logic
    always_ff @(posedge read_clk) begin
        if (~rstn) begin
            read_ptr <= 0;
            read_prev <= 0;
        end else begin
            if (read_en & ~empty) begin
                data_out <= fifo[read_ptr];
                read_ptr <= read_ptr + 1;
            end
            read_prev <= read_en;
        end
    end

    assign full = ((write_ptr + 1) == read_ptr);
    assign empty = (write_ptr == read_ptr);
endmodule
