`timescale 1ns / 1ps

typedef enum logic [1:0] {
    GBUFF_READ_IDLE,
    GBUFF_READ_VERT0,
    GBUFF_READ_VERT1,
    GBUFF_READ_VERT2
} g_buffer_state_t;

module g_buffer #(
    parameter unsigned VERTEX_DATAWIDTH = 12,   // Per x, y, z
    parameter unsigned MAX_NUM_VERTEXES = 1024
    ) (
    input logic clk,
    input logic rstn,

    output logic ready,

    input logic en,
    input logic rw,

    input logic [$clog2(MAX_NUM_VERTEXES)-1:0] addr_write,
    input logic [$clog2(MAX_NUM_VERTEXES)-1:0] addr_read_port0,
    input logic [$clog2(MAX_NUM_VERTEXES)-1:0] addr_read_port1,
    input logic [$clog2(MAX_NUM_VERTEXES)-1:0] addr_read_port2,

    input logic  [3 * VERTEX_DATAWIDTH-1:0] data_write,
    output logic [3 * VERTEX_DATAWIDTH-1:0] data_read_port0,
    output logic [3 * VERTEX_DATAWIDTH-1:0] data_read_port1,
    output logic [3 * VERTEX_DATAWIDTH-1:0] data_read_port2,
    output logic dv
    );

    // Choose between addresses
    logic [$clog2(MAX_NUM_VERTEXES)-1:0] w_current_addr;
    logic [3 * VERTEX_DATAWIDTH-1:0] r_read_data[3];
    logic [3 * VERTEX_DATAWIDTH-1:0] w_bram_data_out;

    bram_sp #(
        .WIDTH(3 * VERTEX_DATAWIDTH),
        .DEPTH(MAX_NUM_VERTEXES)
    ) bram_sp_inst (
        .clk(clk),
        .en(en),

        .rw(rw),
        .addr(w_current_addr),

        .data_in(data_write),
        .data_out(w_bram_data_out)
    );

    // Mealy Machine -- TODO: Look at making it a Moore machine
    g_buffer_state_t current_state, next_state;
    always_ff @(posedge clk) begin
        if (~rstn) begin
            current_state <= GBUFF_READ_IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    always_comb begin
        next_state = current_state;
        ready = 0;

        case (current_state)
            GBUFF_READ_IDLE: begin
                if (en & rw) begin      // Write data
                    w_current_addr = addr_write;
                end

                if (en & !rw) begin
                    next_state = GBUFF_READ_VERT0;
                    w_current_addr = addr_read_port0;
                end

                ready = 1;
            end

            GBUFF_READ_VERT0: begin
                w_current_addr = addr_read_port1;
                next_state = GBUFF_READ_VERT1;
            end

            GBUFF_READ_VERT1: begin
                w_current_addr = addr_read_port2;
                next_state = GBUFF_READ_VERT2;
            end

            GBUFF_READ_VERT2: begin
                next_state = GBUFF_READ_IDLE;
            end

            default: begin
                next_state = GBUFF_READ_IDLE;
            end
        endcase
    end

    always_ff @(posedge clk) begin
        if (~rstn) begin
            dv <= '0;
        end else begin
            case (current_state)
                GBUFF_READ_VERT0: begin
                    r_read_data[0] <= w_bram_data_out;
                    dv <= '0;
                end

                GBUFF_READ_VERT1: begin
                    r_read_data[1] <= w_bram_data_out;
                    dv <= '0;
                end

                GBUFF_READ_VERT2: begin
                    r_read_data[2] <= w_bram_data_out;
                    dv <= '1;
                end

                default: begin
                    dv <= '0;
                end
            endcase
        end
    end

    assign data_read_port0 = r_read_data[0];
    assign data_read_port1 = r_read_data[1];
    assign data_read_port2 = r_read_data[2];

endmodule
