module framebuffer #(
    parameter FB_WIDTH,
    parameter FB_HEIGHT,
    parameter DATA_WIDTH,
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
    output reg [DATA_WIDTH-1:0] data_out,
    output reg clearing
);

    (* ram_style = "block" *) logic [DATA_WIDTH-1:0] buffer [0:FB_SIZE-1]; 

    // Internal counter for clearing the buffer
    reg [ADDR_WIDTH-1:0] clear_counter = 0;

    always_ff @(posedge clk_write) begin
        if (clear) begin
            clearing <= 1'b1;
            buffer[clear_counter] <= clear_value;
            if (clear_counter == ADDR_WIDTH'(FB_SIZE-1)) begin
                clearing <= 1'b0;
                clear_counter <= 0;
            end
            else begin
                clear_counter <= clear_counter + 1;
            end
        end 
        else if (write_enable) begin
            buffer[addr_write] <= data_in;
        end
    end

    always_ff @(posedge clk_read) begin
        data_out <= buffer[addr_read];
    end

endmodule
