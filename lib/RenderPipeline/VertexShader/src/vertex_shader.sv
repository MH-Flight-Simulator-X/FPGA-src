`timescale 1ns / 1ps

typedef enum logic [1:0] {
    VERTEX_SHADER_IDLE,
    VERTEX_SHADER_COMPUTING,
    VERTEX_SHADER_FINISHED
} vertex_shader_state_t;

module vertex_shader #(
        parameter unsigned DATAWIDTH = 18,
        parameter unsigned FRACBITS = 12
    )(
        input clk,
        input logic rstn,

        // Control signals
        output logic o_ready,    // Ready to process vertexes (i.e. mvp matrix set)
        output logic o_finished,

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
    vertex_shader_state_t current_state = VERTEX_SHADER_IDLE, next_state = VERTEX_SHADER_IDLE;

    // Store the mvp matrix
    logic signed [DATAWIDTH-1:0] r_mvp_mat[4][4];
    logic r_mvp_valid = 1'b0;

    // Input and output signals for matrix vector multiplier
    logic signed [DATAWIDTH-1:0] r_mat_vec_x[4];
    logic r_mat_vec_i_dv = 1'b0;

    // Shift register for the vertex_last -- will set state to VERTEX_SHADER_FINISHED when
    // this input vertex is finnished processing
    logic [4:0] vertex_last_finished = '0;

    // Matrix Vector Multiplication Unit Instance
    mat_vec_mul #(
        .DATAWIDTH(DATAWIDTH),
        .FRACBITS(FRACBITS)
        ) mat_vec_mul_inst (
        .clk(clk),
        .rstn(rstn),

        .A(r_mvp_mat),
        .x(r_mat_vec_x),
        .i_dv(r_mat_vec_i_dv),

        .y(o_vertex),
        .o_dv(o_vertex_dv)
    );

    // Set input matrix registers
    always_ff @(posedge clk) begin
        if (~rstn) begin
            // Reset vertex last finished
            vertex_last_finished <= '0;

            // Reset MVP Matrix
            foreach (r_mvp_mat[i,j]) r_mvp_mat[i][j] <= '0;
            r_mvp_valid <= 1'b0;
        end else begin
            // Propagate finished signal
            vertex_last_finished[0] <= i_vertex_last;
            vertex_last_finished[1] <= vertex_last_finished[0];
            vertex_last_finished[2] <= vertex_last_finished[1];
            vertex_last_finished[3] <= vertex_last_finished[2];
            vertex_last_finished[4] <= vertex_last_finished[3];

            // Set MVP Matrix
            if (current_state == VERTEX_SHADER_FINISHED) begin
                foreach (r_mvp_mat[i,j]) r_mvp_mat[i][j] <= '0;
                r_mvp_valid <= 1'b0;
            end else if (i_mvp_dv) begin
                foreach (r_mvp_mat[i,j]) r_mvp_mat[i][j] <= i_mvp_mat[i][j];
                r_mvp_valid <= 1'b1;
            end

            r_mat_vec_i_dv <= i_vertex_dv;
            r_mat_vec_x[0] <= i_vertex[0];
            r_mat_vec_x[1] <= i_vertex[1];
            r_mat_vec_x[2] <= i_vertex[2];
            r_mat_vec_x[3] <= FixedPointOne;
        end
    end


    // State
    always_ff @(posedge clk) begin
        if (~rstn) begin
            // Reset State
            current_state <= VERTEX_SHADER_IDLE;

        end else begin
            // Assign state
            current_state <= next_state;
        end
    end

    always_comb begin
        o_finished = 1'b0;
        o_ready = 1'b0;

        case (current_state)
            VERTEX_SHADER_IDLE: begin
                if (r_mvp_valid) begin
                    next_state = VERTEX_SHADER_COMPUTING;
                end else begin
                    next_state = VERTEX_SHADER_IDLE;
                end
            end

            VERTEX_SHADER_COMPUTING: begin
                if (vertex_last_finished[4]) begin
                    next_state = VERTEX_SHADER_FINISHED;
                end else begin
                    next_state = VERTEX_SHADER_COMPUTING;
                end

                o_ready = 1'b1;
            end

            VERTEX_SHADER_FINISHED: begin
                next_state = VERTEX_SHADER_IDLE;

                o_finished = 1'b1;
            end

            default: begin
                next_state = VERTEX_SHADER_IDLE;
            end
        endcase
    end

endmodule
