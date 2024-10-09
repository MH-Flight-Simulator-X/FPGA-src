module hex_display (
    input clk,
    input  logic [15:0] i_byte,
    output logic [6:0] seg,
    output logic [3:0] an
);

    logic [3:0] current_digit;
    logic [1:0] anode_sel;
    logic [19:0] refresh_counter;

    wire [3:0] hex_digits[4];
    assign hex_digits[0] = i_byte[3:0];
    assign hex_digits[1] = i_byte[7:4];
    assign hex_digits[2] = i_byte[11:8];
    assign hex_digits[3] = i_byte[15:12];

    function automatic logic [6:0] hex_to_7seg(input logic [3:0] hex);
        case (hex)
            4'h0: hex_to_7seg = 7'b1000000;
            4'h1: hex_to_7seg = 7'b1111001;
            4'h2: hex_to_7seg = 7'b0100100;
            4'h3: hex_to_7seg = 7'b0110000;
            4'h4: hex_to_7seg = 7'b0011001;
            4'h5: hex_to_7seg = 7'b0010010;
            4'h6: hex_to_7seg = 7'b0000010;
            4'h7: hex_to_7seg = 7'b1111000;
            4'h8: hex_to_7seg = 7'b0000000;
            4'h9: hex_to_7seg = 7'b0010000;
            4'hA: hex_to_7seg = 7'b0001000;
            4'hB: hex_to_7seg = 7'b0000011;
            4'hC: hex_to_7seg = 7'b1000110;
            4'hD: hex_to_7seg = 7'b0100001;
            4'hE: hex_to_7seg = 7'b0000110;
            4'hF: hex_to_7seg = 7'b0001110;
            default: hex_to_7seg = 7'b1111111;  // Blank display
        endcase
    endfunction

    always_ff @(posedge clk) begin
        refresh_counter <= refresh_counter + 1;
    end

    always_ff @(posedge clk) begin
        anode_sel <= refresh_counter[19:18];
    end

    always_comb begin
        case (anode_sel)
            2'b00: begin
                an = 4'b1110;
                current_digit = hex_digits[0];
            end
            2'b01: begin
                an = 4'b1101;
                current_digit = hex_digits[1];
            end
            2'b10: begin
                an = 4'b1011;
                current_digit = hex_digits[2];
            end
            2'b11: begin
                an = 4'b0111;
                current_digit = hex_digits[3];
            end
            default: begin
                an = 4'b1111;
            end
        endcase

        seg = hex_to_7seg(current_digit);
    end
endmodule
