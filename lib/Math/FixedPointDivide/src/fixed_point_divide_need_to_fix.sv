`timescale 1ns / 1ps

typedef enum logic [2:0] {
    FIXED_POINT_DIVIDE_IDLE,
    FIXED_POINT_DIVIDE_INIT,
    FIXED_POINT_DIVIDE_CALC,
    FIXED_POINT_DIVIDE_ROUND,
    FIXED_POINT_DIVIDE_SIGN
} fixed_point_divide_state_t;

module fixed_point_divide #(
        parameter unsigned WIDTH = 18,
        parameter unsigned FRACBITS = 12
    ) (
        input logic clk,
        input logic rstn,

        // Control signals
        input logic start,
        output logic busy,
        output logic done,
        output logic valid,

        // Output flags
        output logic dbz,       // Divide by zero flag
        output logic ovf,       // Overflow flag

        // Input data
        input logic signed [WIDTH-1:0] a, // Dividend (top)
        input logic signed [WIDTH-1:0] b, // Divisor  (bottom)

        // Output data
        output logic signed [WIDTH-1:0] val
    );

    // Make sure that the widths are valid
    if (WIDTH <= 0) begin: g_WIDTH_CHECK
        $fatal("WIDTH must be greater than 0");
    end

    if (FRACBITS >= WIDTH & FRACBITS > 0) begin: g_FRACBITS_CHECK
        $fatal("FRACBITS must be less than WIDTH and greater than 0");
    end

    // Constants
    localparam unsigned WIDTHU = WIDTH - 1;                 // Unsigned width
    localparam unsigned SMALLEST = {1'b1, {WIDTHU{1'b0}}};  // Smallest number

    localparam unsigned ITER = WIDTHU + FRACBITS;           // Number of iterations
    logic [$clog2(ITER)-1:0] iter;                          // Iteration counter

    // Internal signals
    logic a_sign, b_sign, sign_diff;                        // Sign bits & if they are different
    logic [WIDTHU-1:0] a_u, b_u;                            // Unsigned versions of a and b
    logic [WIDTHU-1:0] quo, quo_next;                       // Quotient
    logic [WIDTHU:0] acc, acc_next;                       // Accumulator

    // Input signs
    always_comb begin
        a_sign = a[WIDTHU];
        b_sign = b[WIDTHU];
    end

    // Division algorithm iteration
    always_comb begin
        if (acc >= {1'b0, b_u}) begin
            acc_next = acc - b_u;
            {acc_next, quo_next} = {acc_next[WIDTHU-1:0], quo, 1'b0};
        end else begin
            {acc_next, quo_next} = {acc, quo} << 1;
        end
    end

    // State
    fixed_point_divide_state_t state;
    always_ff @(posedge clk) begin
        done <= 0;
        case (state)
            FIXED_POINT_DIVIDE_IDLE: begin
                state <= FIXED_POINT_DIVIDE_CALC;
                ovf <= 0;
                iter <= 0;
                {acc, quo} <= {{WIDTHU{1'b0}}, a_u, 1'b0};
            end

            FIXED_POINT_DIVIDE_CALC: begin
                if (iter == WIDTHU-1 && quo_next[WIDTHU-1:WIDTHU-FRACBITS] != 0) begin
                    state <= FIXED_POINT_DIVIDE_IDLE;
                    busy <= 0;
                    done <= 1;
                    ovf <= 1;
                end else begin
                    if (iter == ITER - 1) begin
                        state <= FIXED_POINT_DIVIDE_ROUND;
                    end
                    iter <= iter + 1;
                    acc <= acc_next;
                    quo <= quo_next;
                end
            end

            FIXED_POINT_DIVIDE_ROUND: begin
                state <= FIXED_POINT_DIVIDE_SIGN;
                if (quo_next[0] == 1'b1) begin
                    if (quo[0] == 1'b1 || acc_next[WIDTHU:1] != 0) begin
                        quo <= quo + 1;
                    end
                end
            end

            FIXED_POINT_DIVIDE_SIGN: begin
                state <= FIXED_POINT_DIVIDE_IDLE;
                if (quo != 0) begin
                    val <= (sign_diff) ? {1'b1, -quo} : {1'b0, quo};
                end
                busy <= 0;
                done <= 1;
                valid <= 1;
            end

            default: begin
                if (start) begin
                    valid <= 0;

                    if (b == 0) begin
                        state <= FIXED_POINT_DIVIDE_IDLE;
                        busy <= 0;
                        done <= 1;
                        dbz <= 1;
                        ovf <= 0;
                    end else if (a == SMALLEST || b == SMALLEST) begin
                        state <= FIXED_POINT_DIVIDE_IDLE;
                        busy <= 0;
                        done <= 1;
                        dbz <= 0;
                        ovf <= 1;
                    end else begin
                        state <= FIXED_POINT_DIVIDE_INIT;
                        a_u <= (a_sign) ? -a[WIDTHU-1:0] : a[WIDTHU-1:0];
                        b_u <= (b_sign) ? -b[WIDTHU-1:0] : b[WIDTHU-1:0];
                        sign_diff <= (a_sign ^ b_sign);
                        busy <= 1;
                        dbz <= 0;
                        ovf <= 0;
                    end
                end
            end
        endcase
        if (~rstn) begin
            state <= FIXED_POINT_DIVIDE_IDLE;
            busy <= 0;
            done <= 0;
            valid <= 0;
            dbz <= 0;
            ovf <= 0;
            val <= 0;
        end
    end
endmodule
