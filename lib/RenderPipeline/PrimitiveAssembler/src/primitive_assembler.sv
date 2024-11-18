/* verilator lint_off UNUSED */

`timescale 1ns / 1ps

typedef enum logic [2:0] {
    PA_IDLE,
    PA_ASSEMBLE_READ_INDEX,
    PA_ASSEMBLE_READ_VERTEX,
    PA_ASSEMBLE_READ_VERTEX_WAIT_DATA,
    PA_ASSEMBLE_DONE,
    PA_DONE
} pa_state_t;

module primitive_assembler #(
        parameter unsigned DATAWIDTH = 12,
        parameter logic signed [DATAWIDTH-1:0] SCREEN_WIDTH = 320,
        parameter logic signed [DATAWIDTH-1:0] SCREEN_HEIGHT = 320,
        parameter unsigned MAX_TRIANGLE_COUNT = 16384,
        parameter unsigned MAX_VERTEX_COUNT   = 16384
    ) (
        input logic clk,
        input logic rstn,

        input logic start,
        input logic i_ready,    // Whether the next stage can take in a new triangle

        output logic o_ready,
        output logic finished,

        // Index Buffer
        output logic o_index_buff_read_en,
        input logic [$clog2(MAX_VERTEX_COUNT)-1:0] i_index_data[3],
        input logic i_index_dv,
        input logic i_index_last,

        // Vertex Transform Buffer
        output logic [$clog2(MAX_VERTEX_COUNT)-1:0] o_vertex_addr[3], // Do 3 reads at a time
        output logic o_vertex_read_en,

        input logic signed [DATAWIDTH - 1:0] i_v0[3],
        input logic i_v0_invalid,                                   // Vertex invalid flag
                                                                    // if 1, don't render primitive
        input logic signed [DATAWIDTH - 1:0] i_v1[3],
        input logic i_v1_invalid,                                   // Vertex invalid flag
                                                                    // if 1, don't render primitive
        input logic signed [DATAWIDTH - 1:0] i_v2[3],
        input logic i_v2_invalid,                                   // Vertex invalid flag
        input logic i_vertex_dv,

        // Output primitive
        output logic signed [DATAWIDTH-1:0] o_v0[3],
        output logic signed [DATAWIDTH-1:0] o_v1[3],
        output logic signed [DATAWIDTH-1:0] o_v2[3],

        output logic o_dv,
        output logic o_last
    );

    // Buffer address
    logic [$clog2(MAX_TRIANGLE_COUNT)-1:0] r_index_buff_addr = '0;
    logic r_triangle_last = '0;

    // State
    pa_state_t current_state = PA_IDLE, next_state = PA_IDLE;
    always_ff @(posedge clk) begin
        if (~rstn) begin
            current_state <= PA_IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    logic [31:0] num_triangles = 0;
    always_comb begin
        next_state = current_state;

        finished = 0;
        o_ready = 0;

        case (current_state)
            PA_IDLE: begin
                if (start & i_ready) begin
                    next_state = PA_ASSEMBLE_READ_INDEX;
                end else begin
                    o_ready = 1;
                end
            end

            PA_ASSEMBLE_READ_INDEX: begin
                next_state = PA_ASSEMBLE_READ_VERTEX;
            end

            PA_ASSEMBLE_READ_VERTEX: begin
                next_state = PA_ASSEMBLE_READ_VERTEX_WAIT_DATA;
            end

            PA_ASSEMBLE_READ_VERTEX_WAIT_DATA: begin
                if (i_vertex_dv) begin
                    next_state = PA_ASSEMBLE_DONE;
                end
            end

            PA_ASSEMBLE_DONE: begin
                if (r_triangle_last) begin
                    next_state = PA_DONE;
                end else begin
                    if (i_ready) begin
                        next_state = PA_ASSEMBLE_READ_INDEX;
                    end
                end
            end

            PA_DONE: begin
                finished = 1;
                next_state = PA_IDLE;
            end

            default: begin
                next_state = PA_IDLE;
            end
        endcase
    end

    always_ff @(posedge clk) begin
        if (~rstn) begin
            r_triangle_last <= '0;

            o_index_buff_read_en <= '0;
            foreach (o_vertex_addr[i]) o_vertex_addr[i] <= '0;
            o_vertex_read_en <= '0;

            foreach (o_v0[i]) o_v0[i] <= '0;
            foreach (o_v1[i]) o_v1[i] <= '0;
            foreach (o_v2[i]) o_v2[i] <= '0;

            o_dv <= '0;
            o_last <= '0;

        end else begin
            case (current_state)
                PA_IDLE: begin
                    r_triangle_last <= '0;
                    o_index_buff_read_en <= 0;
                end

                PA_ASSEMBLE_READ_INDEX: begin
                    o_index_buff_read_en <= 1;
                end

                PA_ASSEMBLE_READ_VERTEX: begin
                    o_index_buff_read_en <= 0;

                    if (i_index_last) r_triangle_last <= '1;
                    foreach (o_vertex_addr[i]) o_vertex_addr[i] <= i_index_data[i];
                    o_vertex_read_en <= 1;
                end

                PA_ASSEMBLE_READ_VERTEX_WAIT_DATA: begin
                    o_vertex_read_en <= 0;
                    if (i_vertex_dv) begin
                        foreach (o_v0[i]) o_v0[i] <= i_v0[i];
                        foreach (o_v1[i]) o_v1[i] <= i_v1[i];
                        foreach (o_v2[i]) o_v2[i] <= i_v2[i];
                        o_dv <= '1;
                        o_last <= r_triangle_last;
                        num_triangles <= num_triangles + 1;
                    end else begin
                        o_dv <= '0;
                        o_last <= '0;
                    end
                end

                PA_ASSEMBLE_DONE: begin
                    o_dv <= '0;
                    o_last <= '0;
                end

                default: begin
                    o_index_buff_read_en <= 0;
                    o_vertex_read_en <= 0;
                    r_triangle_last <= 0;
                end
            endcase
        end
    end
endmodule
