`timescale 1ns / 1ps

module vertex_shader_new #(
    parameter unsigned DATAWIDTH = 24,
    parameter unsigned FRACBITS = 13
) (
    input logic clk,
    input logic rstn,

    output logic o_ready,
    output logic o_vertex_ready,

    input logic i_ready,

    input logic signed [DATAWIDTH-1:0] i_mvp[4][4],
    input logic i_mvp_valid,

    input logic signed [DATAWIDTH-1:0] i_vertex[3],
    input logic i_vertex_valid,

    output logic signed [DATAWIDTH-1:0] o_vertex[4],
    output logic o_vertex_valid,
    output logic o_finished
);

    localparam logic signed [DATAWIDTH-1:0] FixedPointOne = 1 << FRACBITS;

    // Store MVP matrix
    logic signed [DATAWIDTH-1:0] r_mvp_mat[4][4];

    // Input and output signals for MATVEC-MUL
    logic signed [DATAWIDTH-1:0] r_vertex[4];
    logic r_vertex_dv = 1'b0;
    logic r_vertex_last = 1'b0;

    // Output data is held until new data is placed on input
    logic signed [DATAWIDTH-1:0] w_transformed_vertex[4];
    logic w_transformed_vertex_valid;

    // Control signals for MATVEC MUL
    logic matvec_mul_start = '0;
    logic w_matvec_mul_ready;

    // TODO: Add instantiation of new MATVEC-MUL

    // State
    typedef enum logic [1:0] {
        IDLE,
        COMPUTE_VERTEX,
        COMPUTE_VERTEX_DONE,
        FINISHED
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
        o_vertex_ready = 1'b0;
        o_finished = 1'b0;
        matvec_mul_start = 1'b0;

        case (current_state)
            IDLE: begin
                if (i_mvp_valid) begin
                    next_state = COMPUTE_VERTEX;
                end
                o_ready = 1'b1;
            end

            COMPUTE_VERTEX: begin
                if (w_matvec_mul_ready) begin
                    o_vertex_ready = 1'b1;
                end

                if (r_vertex_valid && w_matvec_mul_ready) begin
                    next_state = COMPUTE_VERTEX_DONE;
                    matvec_mul_start = 1'b1;
                end
            end

            COMPUTE_VERTEX_DONE: begin
                if (w_transformed_vertex_valid) begin
                    if (i_ready) begin
                        if (r_vertex_last) begin
                            next_state = FINISHED;
                        end else begin
                            next_state = COMPUTE_VERTEX;
                        end
                    end
                end
            end

            FINISHED: begin
                next_state = IDLE;
                o_finished = 1'b1;
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

    always_ff @(posedge clk) begin
        if (~rstn) begin
            foreach (r_mvp_mat[i,j]) r_mvp_mat[i][j] <= '0;
            r_mvp_valid <= 1'b0;

            // Input and output signals for MATVEC-MUL
            foreach (r_vertex[i]) r_vertex[i] <= '0;
            r_vertex_dv <= 1'b0;
            r_vertex_last <= 1'b0;
        end else begin
            case (current_state)
                IDLE: begin
                    if (i_mvp_valid) begin
                        foreach (r_mvp_mat[i,j]) r_mvp_mat[i][j] <= i_mvp[i][j];
                    end
                end

                COMPUTE_VERTEX: begin
                    r_vertex[0] <= i_vertex[0];
                    r_vertex[1] <= i_vertex[1];
                    r_vertex[2] <= i_vertex[2];
                    r_vertex[3] <= FixedPointOne;
                    r_vertex_dv <= i_vertex_valid;

                    foreach (o_vertex[i]) o_vertex[i] <= '0;
                    o_vertex_valid <= 1'b0;
                end

                COMPUTE_VERTEX_DONE: begin
                    if (w_transformed_vertex_valid) begin
                        foreach (o_vertex[i]) o_vertex[i] <= w_transformed_vertex[i];
                        o_vertex_valid <= 1'b1;
                    end
                end

                default: begin
                end
            endcase
        end
    end

endmodule
