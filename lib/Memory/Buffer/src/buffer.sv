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

    bram_dp #(
        .WIDTH(WIDTH),
        .DEPTH(DEPTH),
        .FILE(FILE)
    ) bram_dp_inst (
        .clk_write(clk_write),
        .clk_read(clk_read),
        .write_enable(write_enable || (state == CLEARING)),
        .addr_write((state == CLEARING) ? clear_counter : addr_write),
        .addr_read(addr_read),
        .data_in((state == CLEARING) ? clear_value : data_in),
        .data_out(data_out)
    );

    logic [ADDR_WIDTH-1:0] clear_counter;

    // State Machine for controlling the clear logic
    always_ff @(posedge clk_write) begin
        case (state)
            IDLE: begin
                ready <= 1'b1;
                if (clear) begin
                    state <= CLEARING;
                    ready <= 1'b0;
                    clear_counter <= 0;
                end
            end
            CLEARING: begin
                if (clear_counter < ADDR_WIDTH'(WIDTH - 1)) begin
                    clear_counter <= clear_counter + 1;
                end else begin
                    state <= IDLE;
                    ready <= 1'b1;
                end
            end

            default: begin
                state <= IDLE;
            end
        endcase
    end

endmodule
