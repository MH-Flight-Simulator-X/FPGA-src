`timescale 1ns / 1ps

typedef enum logic [1:0] {
    VERTEX_SHADER_IDLE,
    VERTEX_SHADER_COMPUTING,
    VERTEX_SHADER_FINISHED
} vertex_shader_state_t;

module vertex_shader #(
        parameter unsigned DATAWIDTH = 24,
        parameter unsigned FRACBITS = 13
    )(
        input clk,
        input logic rstn,

        // Control signals
        output logic o_ready,    // Ready to process vertexes (i.e. mvp matrix set)
        output logic o_finished,

        // Whether or not to enable the pipeline
        // Will halt if i_enable = 0
        input logic i_enable,

        // Matrix Data
        input logic signed [DATAWIDTH-1:0] i_mvp_mat[4][4],
        input logic i_mvp_dv,

        // Vertex Data
        input logic signed [DATAWIDTH-1:0] i_vertex[3],
        input logic i_vertex_dv,
        input logic i_vertex_last,

        // Output Data
        output logic signed [DATAWIDTH-1:0] o_vertex[4],
        output logic o_vertex_dv
    );

    localparam logic signed [DATAWIDTH-1:0] FixedPointOne = 1 << FRACBITS;

    // Vertex Shader State
    vertex_shader_state_t current_state = VERTEX_SHADER_IDLE, next_state;

    // Store the mvp matrix
    logic signed [DATAWIDTH-1:0] r_mvp_mat[4][4];
    logic r_mvp_valid = 1'b0;

    // Input and output signals for matrix vector multiplier
    logic signed [DATAWIDTH-1:0] r_vertex[4];
    logic r_vertex_dv = 1'b0;
    logic [5:0] vertex_last_finished = '0;

    logic signed [DATAWIDTH-1:0] w_transformed_vertex[4];
    logic w_transformed_vertex_dv;

    // Matrix Vector Multiplication Unit Instance
    mat_vec_mul #(
        .DATAWIDTH(DATAWIDTH),
        .FRACBITS(FRACBITS)
        ) mat_vec_mul_inst (
        .clk(clk),
        .rstn(rstn),

        .i_enable(i_enable),

        .A(r_mvp_mat),
        .x(r_vertex),
        .i_dv(r_vertex_dv),

        .y(w_transformed_vertex),
        .o_dv(w_transformed_vertex_dv)
    );

    // State
    always_ff @(posedge clk) begin
        if (~rstn) begin
            current_state <= VERTEX_SHADER_IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    always_comb begin
        next_state = current_state;
        o_ready = 1'b0;
        o_finished = 1'b0;

        case (current_state)
            VERTEX_SHADER_IDLE: begin
                if (r_mvp_valid) begin
                    next_state = VERTEX_SHADER_COMPUTING;
                end
            end

            VERTEX_SHADER_COMPUTING: begin
                if (vertex_last_finished[5]) begin
                    next_state = VERTEX_SHADER_FINISHED;
                end else begin
                    if (i_enable) begin
                        o_ready = 1'b1;
                    end
                end
            end

            VERTEX_SHADER_FINISHED: begin
                o_finished = 1'b1;
                if (i_enable) begin
                    next_state = VERTEX_SHADER_IDLE;
                end
            end

            default: begin
                next_state = VERTEX_SHADER_IDLE;
            end
        endcase
    end

    // Set input matrix registers
    always_ff @(posedge clk) begin
        if (~rstn) begin
            vertex_last_finished <= '0;
            foreach (r_mvp_mat[i,j]) r_mvp_mat[i][j] <= '0;
            foreach (r_vertex[i]) r_vertex[i] <= '0;
            r_mvp_valid <= 1'b0;
        end else begin
            case (current_state)
                VERTEX_SHADER_IDLE: begin
                    if (i_mvp_dv) begin
                        foreach (r_mvp_mat[i,j]) r_mvp_mat[i][j] <= i_mvp_mat[i][j];
                        r_mvp_valid <= 1'b1;
                    end
                    foreach (r_vertex[i]) r_vertex[i] <= '0;
                    vertex_last_finished <= '0;
                end

                VERTEX_SHADER_COMPUTING: begin
                    if (i_enable) begin
                        vertex_last_finished[0] <= i_vertex_last;
                        vertex_last_finished[1] <= vertex_last_finished[0];
                        vertex_last_finished[2] <= vertex_last_finished[1];
                        vertex_last_finished[3] <= vertex_last_finished[2];
                        vertex_last_finished[4] <= vertex_last_finished[3];
                        vertex_last_finished[5] <= vertex_last_finished[4];

                        r_vertex_dv <= i_vertex_dv;
                        if (i_vertex_dv) begin
                            r_vertex[0] <= i_vertex[0];
                            r_vertex[1] <= i_vertex[1];
                            r_vertex[2] <= i_vertex[2];
                            r_vertex[3] <= FixedPointOne;
                        end
                    end
                end

                VERTEX_SHADER_FINISHED: begin
                    foreach (r_mvp_mat[i,j]) r_mvp_mat[i][j] <= '0;
                    r_mvp_valid <= 1'b0;
                    foreach (r_vertex[i]) r_vertex[i] <= '0;
                    r_vertex_dv <= '0;
                end

                default: begin
                end
            endcase
        end
    end

    assign o_vertex = w_transformed_vertex;
    assign o_vertex_dv = w_transformed_vertex_dv & i_enable;

endmodule
