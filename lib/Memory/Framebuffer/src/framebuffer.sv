module framebuffer #(
    parameter FB_WIDTH,
    parameter FB_HEIGHT,
    parameter DATA_WIDTH,
    parameter FILE = "",
    localparam FB_SIZE = FB_WIDTH * FB_HEIGHT,
    localparam ADDR_WIDTH = $clog2(FB_SIZE)
) (
    input wire clk_write,
    input wire clk_read,
    input wire write_enable,
    input wire clear,
    input wire [DATA_WIDTH-1:0] clear_value,
    input wire [ADDR_WIDTH-1:0] addr_write,
    input wire [ADDR_WIDTH-1:0] addr_read,
    input wire [DATA_WIDTH-1:0] data_in, 
    output wire [DATA_WIDTH-1:0] data_out,
    output reg clearing
);

    // State Machine States
    typedef enum logic {
        IDLE,               // Idle state, normal operation
        CLEAR               // Clearing state, clearing the framebuffer
    } state_t;
    state_t state = IDLE;

    bram_dp #(
        .WIDTH(DATA_WIDTH),
        .DEPTH(FB_SIZE),
        .FILE(FILE)
    ) bram_inst (
        .clk_write(clk_write),
        .clk_read(clk_read),
        .write_enable(write_enable || (state == CLEAR)),
        .addr_write((state == CLEAR) ? clear_counter : addr_write),
        .addr_read(addr_read),
        .data_in((state == CLEAR) ? clear_value : data_in),
        .data_out(data_out)
    );

    reg [ADDR_WIDTH-1:0] clear_counter;

    // State Machine for controlling the clear logic
    always_ff @(posedge clk_write) begin
        case (state)
            IDLE: begin
                clearing <= 1'b0;
                if (clear) begin
                    state <= CLEAR;
                    clearing <= 1'b1;
                    clear_counter <= 0;
                end
            end
            CLEAR: begin
                if (clear_counter < ADDR_WIDTH'(FB_SIZE - 1)) begin
                    clear_counter <= clear_counter + 1;
                end else begin
                    state <= IDLE;
                    clearing <= 1'b0;
                end
            end
        endcase
    end

endmodule
