`timescale 1ns / 1ps

typedef enum logic [2:0] {
    VERETX_SHADER_IDLE,
    VERETX_SHADER_VIEW_PROJ_CALC,
    VERETX_SHADER_MVP_CALC,
    VERTEX_SHADER_COMPUTE,
    VERTEX_SHADER_FINISHED
} vertex_shader_state_t;

module vertex_shader #(
        parameter unsigned NUM_CORES = 1,
        parameter unsigned DATAWIDTH = 18,
        parameter unsigned FRACBITS = 12
    )(
        input clk,
        input rstn,

        // Control signals
        output logic o_vertex_ready,    // Ready to process vertexes (i.e. mat_mul finished)
        output logic o_dv,
        output logic o_finished,

        // Matrix Data
        input logic signed [DATAWIDTH-1:0] model_mat[4][4],
        input logic signed [DATAWIDTH-1:0] view_mat[4][4],
        input logic signed [DATAWIDTH-1:0] proj_mat[4][4],

        input logic i_model_dv,
        input logic i_view_dv,

        // Vertex Data
        input logic signed [DATAWIDTH-1:0] vertex_data[3],
        input logic i_vertex_dv,
        input logic i_vertex_last,

        // Output Data
        output logic signed [DATAWIDTH-1:0] vertex_out[4]
    );

    // Vertex Shader State
    vertex_shader_state_t current_state = VERTEX_SHADER_IDLE, next_state = VERTEX_SHADER_IDLE;

    // Control signals
    logic r_vertex_ready;
    logic r_o_dv;
    logic r_finished;

    // Input and output signals for matrix multiplier
    logic signed [DATAWIDTH-1:0] r_mat_a[4][4];
    logic signed [DATAWIDTH-1:0] r_mat_b[4][4];
    logic r_mat_mul_i_dv;

    logic signed [DATAWIDTH-1:0] w_mat_c[4][4];
    logic w_mat_mul_o_dv;
    logic w_mat_mul_o_ready;

    // Store the model and view matricies
    logic signed [DATAWIDTH-1:0] r_model_mat[4][4];
    logic signed [DATAWIDTH-1:0] r_view_mat[4][4];
    logic r_model_valid;
    logic r_view_valdi;

    // Finished matricies
    logic signed [DATAWIDTH-1:0] r_view_proj_mat;
    logic signed [DATAWIDTH-1:0] r_mvp_mat;
    logic mvp_valid;

    // Input and output signals for matrix vector multiplier
    logic signed [DATAWIDTH-1:0] r_mat_vec_x[4];
    logic r_mat_vec_i_dv;

    logic signed [DATAWIDTH-1:0] w_mat_vec_y[4];
    logic w_mat_vec_o_dv;

    // Set input matrix registers
    always_ff @(posedge clk) begin
        if (~rstn) begin
            foreach (r_model_mat[i,j]) r_model_mat[i][j] <= '0;
            foreach (r_view_mat[i,j]) r_view_mat[i][j] <= '0;
            r_model_valid <= 1'b0;
            r_view_valid <= 1'b0;
        end else begin
            if (i_model_dv) begin
                r_model_valid <= 1'b1;
                r_model_mat[0] <= model_mat[0];
                r_model_mat[1] <= model_mat[1];
                r_model_mat[2] <= model_mat[2];
                r_model_mat[3] <= model_mat[3];
            end
            if (i_view_dv) begin
                r_view_valid <= 1'b1;
                r_view_mat[0] <= view_mat[0];
                r_view_mat[1] <= view_mat[1];
                r_view_mat[2] <= view_mat[2];
                r_view_mat[3] <= view_mat[3];
            end
        end
    end

    // Matrix Matrix Multiplication Unit Instance
    mat_mul #(
        .DATAWIDTH(DATAWIDTH),
        .FRACBITS(FRACBITS)
    ) mat_mul_inst (
        .clk(clk),
        .rstn(rstn),

        .A(r_mat_a),
        .B(r_mat_b),
        .i_dv(r_mat_mul_i_dv),

        .C(w_mat_c),
        .o_dv(w_mat_mul_o_dv),
        .o_ready(w_mat_mul_o_ready)
    );

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

        .y(w_mat_vec_y),
        .o_dv(w_mat_vec_o_dv)
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
        case (current_state)
            VERTEX_SHADER_IDLE: begin

            end

            default: begin
                next_state = VERTEX_SHADER_IDLE;
            end
        endcase
    end

endmodule
