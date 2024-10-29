`timescale 1ns / 1ps

typedef enum logic [2:0] {
    GBUFF_READ_IDLE,
    GBUFF_READ_VERT0,
    GBUFF_READ_VERT1,
    GBUFF_READ_VERT2,
    GBUFF_READ_DONE
} g_buffer_state_t;

module g_buffer #(
    parameter unsigned VERTEX_DATAWIDTH = 12,   // For each x, y, z
    parameter unsigned MAX_VERTEX_COUNT = 1024
    ) (
    input logic clk,
    input logic rstn,

    output logic ready,

    input logic write_en,
    input logic read_en,

    input logic [$clog2(MAX_VERTEX_COUNT)-1:0] addr_write,
    input logic [$clog2(MAX_VERTEX_COUNT)-1:0] addr_read_port0,
    input logic [$clog2(MAX_VERTEX_COUNT)-1:0] addr_read_port1,
    input logic [$clog2(MAX_VERTEX_COUNT)-1:0] addr_read_port2,

    input logic  [3 * VERTEX_DATAWIDTH-1:0] data_write,
    output logic [3 * VERTEX_DATAWIDTH-1:0] data_read_port0,
    output logic [3 * VERTEX_DATAWIDTH-1:0] data_read_port1,
    output logic [3 * VERTEX_DATAWIDTH-1:0] data_read_port2,
    output logic dv
    );

    // Choose between addresses
    logic [$clog2(MAX_VERTEX_COUNT)-1:0] w_current_addr;
    logic [3 * VERTEX_DATAWIDTH-1:0] r_read_data[3];
    logic [3 * VERTEX_DATAWIDTH-1:0] w_bram_data_out;
    logic w_bram_dv;

    logic w_bram_en;
    logic w_bram_rw;

    // Register addresses
    logic [$clog2(MAX_VERTEX_COUNT)-1:0] r_read_addr[3];

    bram_sp #(
        .WIDTH(3 * VERTEX_DATAWIDTH),
        .DEPTH(MAX_VERTEX_COUNT)
    ) bram_sp_inst (
        .clk(clk),
        .en(w_bram_en),

        .rw(w_bram_rw),
        .addr(w_current_addr),

        .data_in(data_write),
        .data_out(w_bram_data_out),
        .o_dv(w_bram_dv)
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
        w_current_addr = 0;
        ready = 0;

        w_bram_en = 0;
        w_bram_rw = 0;

        dv = 0;

        case (current_state)
            GBUFF_READ_IDLE: begin
                if (write_en) begin
                    w_current_addr = addr_write;
                    ready = 1;
                    w_bram_en = 1;
                    w_bram_rw = 1;
                end else if (read_en) begin
                    next_state = GBUFF_READ_VERT0;
                    ready = 0;
                end else begin
                    ready = 1;
                end
            end

            GBUFF_READ_VERT0: begin
                if (w_bram_dv) begin
                    next_state = GBUFF_READ_VERT1;
                end else begin
                    w_bram_en = 1;
                    w_bram_rw = 0;
                    w_current_addr = r_read_addr[0];
                end
            end

            GBUFF_READ_VERT1: begin
                if (w_bram_dv) begin
                    next_state = GBUFF_READ_VERT2;
                end else begin
                    w_bram_en = 1;
                    w_bram_rw = 0;
                    w_current_addr = r_read_addr[1];
                end
            end

            GBUFF_READ_VERT2: begin
                if (w_bram_dv) begin
                    next_state = GBUFF_READ_DONE;
                end else begin
                    w_bram_en = 1;
                    w_bram_rw = 0;
                    w_current_addr = r_read_addr[2];
                end
            end

            GBUFF_READ_DONE: begin
                next_state = GBUFF_READ_IDLE;
                dv = 1;
            end

            default: begin
                next_state = GBUFF_READ_IDLE;
            end
        endcase
    end

    always_ff @(posedge clk) begin
        if (~rstn) begin
            r_read_addr[0] <= '0;
            r_read_addr[1] <= '0;
            r_read_addr[2] <= '0;

            r_read_data[0] <= '0;
            r_read_data[1] <= '0;
            r_read_data[2] <= '0;
        end else begin
            case (current_state)
                GBUFF_READ_IDLE: begin
                    r_read_addr[0] <= addr_read_port0;
                    r_read_addr[1] <= addr_read_port1;
                    r_read_addr[2] <= addr_read_port2;
                end

                GBUFF_READ_VERT0: begin
                    if (w_bram_dv) begin
                        r_read_data[0] <= w_bram_data_out;
                    end
                end

                GBUFF_READ_VERT1: begin
                    if (w_bram_dv) begin
                        r_read_data[1] <= w_bram_data_out;
                    end
                end

                GBUFF_READ_VERT2: begin
                    if (w_bram_dv) begin
                        r_read_data[2] <= w_bram_data_out;
                    end
                end

                GBUFF_READ_DONE: begin
                    r_read_addr[0] <= '0;
                    r_read_addr[1] <= '0;
                    r_read_addr[2] <= '0;
                    r_read_data[0] <= '0;
                    r_read_data[1] <= '0;
                    r_read_data[2] <= '0;
                end

                default: begin
                    r_read_addr[0] <= '0;
                    r_read_addr[1] <= '0;
                    r_read_addr[2] <= '0;
                    r_read_data[0] <= '0;
                    r_read_data[1] <= '0;
                    r_read_data[2] <= '0;
                end
            endcase
        end
    end

    assign data_read_port0 = r_read_data[0];
    assign data_read_port1 = r_read_data[1];
    assign data_read_port2 = r_read_data[2];

endmodule
