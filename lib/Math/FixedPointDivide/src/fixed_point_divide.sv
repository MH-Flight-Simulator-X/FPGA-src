// This module is heavily based on: projectf.io/verilog-lib

`timescale 1ns / 1ps

typedef enum logic [2:0] {
    FPD_IDLE,
    FPD_INIT,
    FPD_CALC,
    FPD_ROUND,
    FPD_SIGN
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
        input logic signed [WIDTH-1:0] A, // Dividend (top)
        input logic signed [WIDTH-1:0] B, // Divisor  (bottom)

        // Output data
        output logic signed [WIDTH-1:0] Q  // Quotient
    );

    localparam unsigned UWIDTH = WIDTH - 1;                     // Unsigned width
    localparam unsigned SMALLEST = {1'b1, {UWIDTH{1'b0}}};      // Smallest fixed point number

    localparam unsigned ITER = UWIDTH + FRACBITS;
    logic [$clog2(ITER):0] i;

    logic A_sign, B_sign, sign_difference;
    logic [UWIDTH-1:0] A_u, B_u;            // Unsigned versions of inputs
    logic [UWIDTH-1:0] quo, quo_next;       // Intermediate quotients (unsigned)
    logic [UWIDTH:0] acc, acc_next;         // Accumulator

    // Get signs
    always_comb begin
        A_sign = A[WIDTH-1+:1];
        B_sign = B[WIDTH-1+:1];
    end

    // Division algorithm iteration
    always_comb begin
        if (acc >= {1'b0, B_u}) begin
            acc_next = acc - B_u;
            {acc_next, quo_next} = {acc_next[UWIDTH-1:0], quo, 1'b1};
        end else begin
            {acc_next, quo_next} = {acc, quo} << 1;
        end
    end

    // State machine
    fixed_point_divide_state_t state = FPD_IDLE;
    always_ff @(posedge clk) begin
        if (~rstn) begin
            // Reset state
            state <= FPD_IDLE;

            // Control signals
            busy <= 0;
            done <= 0;
            valid <= 0;
            dbz <= 0;
            ovf <= 0;
            Q <= 0;

        end else begin
            done <= 0;
            case (state)
                FPD_IDLE: begin
                    valid <= 0;
                    if (start) begin
                        Q <= 0;

                        if (B == 0) begin
                            // Divide by zero
                            state <= FPD_IDLE;

                            busy <= 0;
                            done <= 1;
                            dbz <= 1;
                            ovf <= 0;
                        end else if (A == SMALLEST || B == SMALLEST) begin
                            // Overflow
                            state <= FPD_IDLE;

                            busy <= 0;
                            done <= 1;
                            dbz <= 0;
                            ovf <= 1;
                        end else begin
                            // Start computation
                            state <= FPD_INIT;

                            A_u <= (A_sign) ? -A[UWIDTH-1:0] : A[UWIDTH-1:0];
                            B_u <= (B_sign) ? -B[UWIDTH-1:0] : B[UWIDTH-1:0];

                            // Register sign difference to be used later when
                            // correcting for sign
                            sign_difference <= (A_sign ^ B_sign);

                            // Control signals
                            busy <= 1;
                            dbz <= 0;
                            ovf <= 0;
                        end
                    end
                end

                FPD_INIT: begin
                    state <= FPD_CALC;
                    ovf <= 0;
                    i <= 0;

                    // Initialize calculation
                    {acc, quo} <= {{UWIDTH{1'b0}}, A_u, 1'b0};
                end

                FPD_CALC: begin
                    if (i == UWIDTH-1 && quo_next[UWIDTH-1:UWIDTH-FRACBITS] != 0) begin
                        state <= FPD_IDLE;
                        busy <= 0;
                        done <= 1;
                        ovf <= 1;
                    end else begin
                        if (i == ITER-1) begin
                            state <= FPD_ROUND; // Calculation complete next iteration
                        end
                        i <= i + 1;
                        acc <= acc_next;
                        quo <= quo_next;
                    end
                end

                FPD_ROUND: begin
                    state <= FPD_SIGN;

                    if (quo_next[0] == 1'b1) begin
                        // Round up if quotient is odd or remainder is non-zero
                        if (quo[0] == 1'b1 || acc_next[UWIDTH:1] != 0) begin
                            quo <= quo + 1;
                        end
                    end
                end

                FPD_SIGN: begin
                    state <= FPD_IDLE;

                    if (quo != 0) begin
                        // Assign output
                        Q <= (sign_difference) ? {1'b1, -quo} : {1'b0, quo};
                    end

                    // Control signals
                    busy <= 0;
                    done <= 1;
                    valid <= 1;
                end

                default: begin
                    state <= FPD_IDLE;
                end
            endcase
        end
    end
endmodule
