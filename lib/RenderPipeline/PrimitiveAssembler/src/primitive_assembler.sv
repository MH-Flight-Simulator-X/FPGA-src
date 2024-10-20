`timescale 1ns / 1ps

typedef enum logic [2:0] {
    PA_IDLE,
    PA_ASSEMBLE,
    PA_WAIT_LAST,
    PA_DONE
} pa_state_t;

module primitive_assembler #(
        parameter unsigned IV_DATAWIDTH = 12,
        parameter unsigned IV_DEPTH_FRACBITS = 12,   // Unsigned Q0.12 format

        parameter logic signed [IV_DATAWIDTH-1:0] SCREEN_WIDTH = 320,
        parameter logic signed [IV_DATAWIDTH-1:0] SCREEN_HEIGHT = 320,

        parameter unsigned MAX_TRIANGLE_COUNT = 2048
    ) (
        input logic clk,
        input logic rstn,

        input logic start,
        output logic ready,
        output logic finished,

        // Number of triangles to be rendered for this model
        input logic [$clog2(MAX_TRIANGLE_COUNT)-1:0] i_num_triangles,

        // Index Buffer
        output logic [$clog2(MAX_TRIANGLE_COUNT)-1:0] o_index_buff_addr,
        output logic o_index_buff_read_en,

        input logic [$clog2(3 * MAX_TRIANGLE_COUNT)-1:0] i_vertex_idxs[3],

        // Vertex Transform Buffer
        output logic [$clog2(3 * MAX_TRIANGLE_COUNT)-1:0] o_vertex_addr[3], // Do 3 reads at a time
        output logic o_vertex_read_en,

        input logic signed [IV_DATAWIDTH - 1:0] i_v0[2],
        input logic signed [IV_DEPTH_FRACBITS-1:0] i_v0_z,
        input logic i_v0_invalid,                                   // Vertex invalid flag
                                                                    // if 1, don't render primitive
        input logic signed [IV_DATAWIDTH - 1:0] i_v1[2],
        input logic signed [IV_DEPTH_FRACBITS-1:0] i_v1_z,
        input logic i_v1_invalid,                                   // Vertex invalid flag
                                                                    // if 1, don't render primitive
        input logic signed [IV_DATAWIDTH - 1:0] i_v2[2],
        input logic signed [IV_DEPTH_FRACBITS-1:0] i_v2_z,
        input logic i_v2_invalid,                                   // Vertex invalid flag
                                                                    // if 1, don't render primitive

        // Output primitive
        output logic signed [IV_DATAWIDTH-1:0] o_vertex_pixel[3][2],
        output logic unsigned [IV_DEPTH_FRACBITS-1:0] o_vertex_z[3],

        // Primitive bounding box
        output logic signed [IV_DATAWIDTH-1:0] bb_tl[2],
        output logic signed [IV_DATAWIDTH-1:0] bb_br[2],

        output logic o_dv
    );

    logic [$clog2(MAX_TRIANGLE_COUNT)-1:0] r_num_triangles = '0;
    logic [$clog2(MAX_TRIANGLE_COUNT)-1:0] r_triangle_cnt = '0;

    // Check if triangle index buffer was read last clk
    logic r_index_buff_read_last = '0;
    logic r_vertex_read_last = '0;
    logic r_finished_wait_last = '0;

    // Calculate primitive bounding box
    logic [IV_DATAWIDTH-1:0] w_bb_tl[2];
    logic [IV_DATAWIDTH-1:0] w_bb_br[2];
    logic w_bb_valid;

    bounding_box #(
        .TILE_MIN_X(0),
        .TILE_MAX_X(SCREEN_WIDTH),
        .TILE_MIN_Y(0),
        .TILE_MAX_Y(SCREEN_HEIGHT),
        .COORD_WIDTH(IV_DATAWIDTH)
    ) bb_inst (
        .x0(i_v0[0]),
        .y0(i_v0[1]),
        .x1(i_v1[0]),
        .y1(i_v1[1]),
        .x2(i_v2[0]),
        .y2(i_v2[1]),

        .min_x(w_bb_tl[0]),
        .max_x(w_bb_br[0]),
        .min_y(w_bb_tl[1]),
        .max_y(w_bb_br[1]),

        .valid(w_bb_valid)
    );

    // State
    pa_state_t current_state = PA_IDLE, next_state = PA_IDLE;
    always_ff @(posedge clk) begin
        if (~rstn) begin
            current_state <= PA_IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    always_comb begin
        next_state = current_state;

        finished = 0;
        ready = 0;

        case (current_state)
            PA_IDLE: begin
                if (start) begin
                    next_state = PA_ASSEMBLE;
                end else begin
                    ready = 1;
                end
            end

            PA_ASSEMBLE: begin
                if (r_triangle_cnt == r_num_triangles) begin
                    next_state = PA_WAIT_LAST;
                end
            end

            PA_WAIT_LAST: begin
                if (r_finished_wait_last) begin
                    next_state = PA_DONE;
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
            r_num_triangles <= '0;
            r_triangle_cnt <= '0;

            o_index_buff_read_en <= '0;
            r_index_buff_read_last <= '0;

            foreach (o_vertex_addr[i]) o_vertex_addr[i] <= '0;
            o_vertex_read_en <= '0;

            r_vertex_read_last <= '0;
            r_finished_wait_last <= '0;

            foreach (o_vertex_pixel[i,j]) o_vertex_pixel[i][j] <= '0;
            foreach (o_vertex_pixel[i,j]) o_vertex_pixel[i][j] <= '0;
            foreach (o_vertex_z[i]) o_vertex_z[i] <= '0;
            o_dv <= '0;
        end else begin
            case (current_state)
                PA_IDLE: begin
                    if (start) begin
                        r_num_triangles <= i_num_triangles;
                    end
                    r_triangle_cnt <= '0;
                    r_vertex_read_last <= '0;
                end

                PA_ASSEMBLE: begin
                    r_triangle_cnt <= r_triangle_cnt + 1;
                    o_index_buff_addr <= r_triangle_cnt;
                    o_index_buff_read_en <= '1;
                    r_index_buff_read_last <= '1;

                    if (r_index_buff_read_last) begin
                        foreach (o_vertex_addr[i]) o_vertex_addr[i] <= i_vertex_idxs[i];
                        o_vertex_read_en <= '1;
                        r_vertex_read_last <= '1;
                    end else begin
                        r_vertex_read_last <= '0;
                        o_vertex_read_en <= '0;
                    end

                    if (r_vertex_read_last) begin
                        o_vertex_pixel[0][0] <= i_v0[0];
                        o_vertex_pixel[0][1] <= i_v0[1];
                        o_vertex_z[0] <= i_v0_z;

                        o_vertex_pixel[1][0] <= i_v1[0];
                        o_vertex_pixel[1][1] <= i_v1[1];
                        o_vertex_z[1] <= i_v1_z;

                        o_vertex_pixel[2][0] <= i_v2[0];
                        o_vertex_pixel[2][1] <= i_v2[1];
                        o_vertex_z[2] <= i_v2_z;

                        bb_tl[0] <= w_bb_tl[0];
                        bb_tl[1] <= w_bb_tl[1];

                        bb_br[0] <= w_bb_br[0];
                        bb_br[1] <= w_bb_br[1];

                        if (w_bb_valid & !i_v0_invalid & !i_v1_invalid & !i_v2_invalid) begin
                            o_dv <= '1;
                        end else begin
                            o_dv <= '0;
                        end
                    end
                end

                PA_WAIT_LAST: begin
                    if (r_index_buff_read_last) begin
                        foreach (o_vertex_addr[i]) o_vertex_addr[i] <= i_vertex_idxs[i];
                        o_vertex_read_en <= '0;
                        r_vertex_read_last <= '1;
                    end

                    if (r_vertex_read_last) begin
                        o_vertex_pixel[0][0] <= i_v0[0];
                        o_vertex_pixel[0][1] <= i_v0[1];
                        o_vertex_z[0] <= i_v0_z;

                        o_vertex_pixel[1][0] <= i_v1[0];
                        o_vertex_pixel[1][1] <= i_v1[1];
                        o_vertex_z[1] <= i_v1_z;

                        o_vertex_pixel[2][0] <= i_v2[0];
                        o_vertex_pixel[2][1] <= i_v2[1];
                        o_vertex_z[2] <= i_v2_z;

                        bb_tl[0] <= w_bb_tl[0];
                        bb_tl[1] <= w_bb_tl[1];

                        bb_br[0] <= w_bb_br[0];
                        bb_br[1] <= w_bb_br[1];

                        if (w_bb_valid & !i_v0_invalid & !i_v1_invalid & !i_v2_invalid) begin
                            o_dv <= '1;
                        end else begin
                            o_dv <= '0;
                        end

                        r_finished_wait_last <= '1;
                    end else begin
                        r_finished_wait_last <= '0;
                    end
                end

                default: begin
                    o_index_buff_read_en <= '0;
                    r_index_buff_read_last <= '0;
                    r_vertex_read_last <= '0;
                end
            endcase
        end
    end

endmodule
