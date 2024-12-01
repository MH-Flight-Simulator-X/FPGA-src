`timescale 1ns / 1ps

module mat_vec_mul_new #(
    parameter unsigned DATAWIDTH = 24,
    parameter unsigned FRACBITS = 13
) (
    input logic clk,
    input logic rstn,

    input logic start,
    input logic i_ready,
    output logic o_ready,

    input signed [DATAWIDTH-1:0] A[4][4],
    input signed [DATAWIDTH-1:0] x[4],

    output logic signed [DATAWIDTH-1:0] y[4],
    output logic o_valid
);
    // For getting the correct bits from the wider intermediate values
    localparam unsigned OutputRangeStart = FRACBITS;
    localparam unsigned OutputRangeEnd = DATAWIDTH + OutputRangeStart - 1;

    logic [1:0] iter = '0;

    logic signed [DATAWIDTH-1:0] r_A[4][4];
    logic signed [DATAWIDTH-1:0] r_x[4];
    logic signed [2*DATAWIDTH:0] r_y[4];

    typedef enum logic [1:0] {
        IDLE,
        COMPUTE,
        DONE
    } state_t;
    state_t current_state = IDLE, next_state;

    always_ff @(posedge clk) begin
        if (~rstn) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    always_comb begin
        next_state = current_state;
        o_ready = 1'b0;

        case (current_state)
            IDLE: begin
                if (start) begin
                    next_state = COMPUTE;
                end else begin
                    o_ready = 1'b1;
                end
            end

            COMPUTE: begin
                if (iter == 3) begin
                    next_state = DONE;
                end
            end

            DONE: begin
                if (i_ready) begin
                    next_state = IDLE;
                end
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

    always_ff @(posedge clk) begin
        if (~rstn) begin
            iter <= '0;

            foreach (r_A[i, j]) r_A[i][j] <= '0;
            foreach (r_x[i]) r_x[i] <= '0;
            foreach (r_y[i]) r_y[i] <= '0;

            foreach (y[i]) y[i] <= '0;
            o_valid <= 0;

        end else begin
            case (current_state)
                IDLE: begin
                    iter <= '0;

                    if (start) begin
                        foreach (r_A[i, j]) r_A[i][j] <= A[i][j];
                        foreach (r_x[i]) r_x[i] <= x[i];
                        foreach (r_y[i]) r_y[i] <= '0;

                    end
                    foreach (y[i]) y[i] <= '0;
                    o_valid <= 0;
                end

                COMPUTE: begin
                    iter <= iter + 1;

                    r_y[0] <= r_y[0] + r_A[0][iter] * r_x[iter];
                    r_y[1] <= r_y[1] + r_A[1][iter] * r_x[iter];
                    r_y[2] <= r_y[2] + r_A[2][iter] * r_x[iter];
                    r_y[3] <= r_y[3] + r_A[3][iter] * r_x[iter];
                end

                DONE: begin
                    foreach (y[i]) y[i] <= {r_y[i][2*DATAWIDTH], r_y[i][OutputRangeEnd-1:OutputRangeStart]};
                    o_valid <= 1;
                end

                default: begin
                end
            endcase
        end
    end

endmodule
