module buffer #(
    parameter unsigned WIDTH = 16,
    parameter unsigned DEPTH = 32,
    parameter string FILE = ""
) (
    input logic clk_write,
    input logic clk_read,

    input logic write_enable,
    input logic clear,
    output logic ready,

    input logic [ADDR_WIDTH-1:0] addr_write,
    input logic [ADDR_WIDTH-1:0] addr_read,

    input logic [WIDTH-1:0] clear_value,
    input logic [WIDTH-1:0] data_in,
    output logic [WIDTH-1:0] data_out
);

    localparam ADDR_WIDTH = $clog2(DEPTH);

    // State Machine States
    typedef enum logic {
        IDLE,               // Idle state, normal operation
        CLEARING            // Clearing state, clearing the framebuffer
    } state_t;
    state_t state = IDLE;

    logic [ADDR_WIDTH-1:0] clear_counter;

    logic [ADDR_WIDTH-1:0] bram_addr_write;
    logic [WIDTH-1:0] bram_data_write;
    logic bram_write_en;

    always_comb begin
        ready = 1'b0;

        case (state)
            IDLE: begin
                bram_addr_write = addr_write;
                bram_data_write = data_in;
                bram_write_en = write_enable;
                ready = 1'b1;
            end

            CLEARING: begin
                bram_addr_write = clear_counter;
                bram_data_write = clear_value;
                bram_write_en = 1;
            end

            default: begin
            end
        endcase
    end

    bram_dp #(
        .WIDTH(WIDTH),
        .DEPTH(DEPTH),
        .FILE(FILE)
    ) bram_dp_inst (
        .clk_write(clk_write),
        .clk_read(clk_read),
        .write_enable(bram_write_en),
        .addr_write(bram_addr_write),
        .addr_read(addr_read),
        .data_in(bram_data_write),
        .data_out(data_out)
    );

    // State Machine for controlling the clear logic
    always_ff @(posedge clk_write) begin
        case (state)
            IDLE: begin
                if (clear) begin
                    state <= CLEARING;
                    clear_counter <= 0;
                end
            end
            CLEARING: begin
                if (clear_counter < ADDR_WIDTH'(DEPTH - 1)) begin
                    clear_counter <= clear_counter + 1;
                end else begin
                    state <= IDLE;
                end
            end

            default: begin
                state <= IDLE;
            end
        endcase
    end

endmodule
