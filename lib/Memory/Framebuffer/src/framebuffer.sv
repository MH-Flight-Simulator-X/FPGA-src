module framebuffer #(
    parameter FB_WIDTH,
    parameter FB_HEIGHT,
    parameter DATA_WIDTH,
    parameter FILE = ""
) (
    input logic clk_write,
    input logic clk_read,

    input logic write_enable,
    input logic clear,
    output logic ready,

    input logic [ADDR_WIDTH-1:0] addr_write,
    input logic [ADDR_WIDTH-1:0] addr_read,

    input logic [DATA_WIDTH-1:0] clear_value,
    input logic [DATA_WIDTH-1:0] data_in, 
    output logic [DATA_WIDTH-1:0] data_out
);

    localparam FB_SIZE = FB_WIDTH * FB_HEIGHT;
    localparam ADDR_WIDTH = $clog2(FB_SIZE);

    // State Machine States
    typedef enum logic {
        IDLE,               // Idle state, normal operation
        CLEARING            // Clearing state, clearing the framebuffer
    } state_t;
    state_t state = IDLE;

    bram_dp #(
        .WIDTH(DATA_WIDTH),
        .DEPTH(FB_SIZE),
        .FILE(FILE)
    ) bram_inst (
        .clk_write(clk_write),
        .clk_read(clk_read),
        .write_enable(write_enable || (state == CLEARING)),
        .addr_write((state == CLEARING) ? clear_counter : addr_write),
        .addr_read(addr_read),
        .data_in((state == CLEARING) ? clear_value : data_in),
        .data_out(data_out)
    );

    reg [ADDR_WIDTH-1:0] clear_counter;

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
                if (clear_counter < ADDR_WIDTH'(FB_SIZE - 1)) begin
                    clear_counter <= clear_counter + 1;
                end else begin
                    state <= IDLE;
                    ready <= 1'b1;
                end
            end
        endcase
    end

endmodule
