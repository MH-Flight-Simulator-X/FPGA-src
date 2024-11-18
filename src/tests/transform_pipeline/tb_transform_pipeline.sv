`timescale 1ns / 1ps

module tb_transform_pipeline #(
    parameter unsigned INPUT_VERTEX_DATAWIDTH = 24,
    parameter unsigned INPUT_VERTEX_FRACBITS = 13,
    parameter unsigned OUTPUT_VERTEX_DATAWIDTH = 12,
    parameter unsigned OUTPUT_DEPTH_FRACBITS = 12,

    parameter unsigned MAX_TRIANGLE_COUNT = 16384,
    parameter unsigned MAX_VERTEX_COUNT   = 16384,

    parameter unsigned SCREEN_WIDTH = 320,
    parameter unsigned SCREEN_HEIGHT = 320,

    parameter real ZFAR = 100.0,
    parameter real ZNEAR = 0.1
    ) (
    input logic clk,
    input logic rstn,

    // Input data vertex shader
    input logic signed [INPUT_VERTEX_DATAWIDTH-1:0] i_mvp_matrix[4][4],
    input logic i_mvp_dv,

    input logic signed [INPUT_VERTEX_DATAWIDTH-1:0] i_vertex[3],
    input logic i_vertex_dv,
    input logic i_vertex_last,

    // Output signal transform pipeline
    // Ready to recieve next vertex
    output logic vertex_ready,
    input logic i_triangle_ready,   // Whether or not the next triangle can be recieved

    // DEBUG
    output logic [OUTPUT_VERTEX_DATAWIDTH-1:0] debug_o_vertex[2],
    output logic debug_o_vertex_dv,

    // Output error signal
    output logic vpp_error,

    // Input data primitive assembler
    input logic [$clog2(MAX_TRIANGLE_COUNT)-1:0] i_num_triangles,

    // Primitive assembler index buffer signals and data
    output logic [$clog2(MAX_TRIANGLE_COUNT)-1:0] o_index_buff_addr,
    output logic o_index_buff_read_en,

    input logic [$clog2(MAX_VERTEX_COUNT)-1:0] i_vertex_idxs[3],

    // Output data primitive assembler
    output logic signed [OUTPUT_VERTEX_DATAWIDTH-1:0] o_vertex_pixel[3][2],
    output logic unsigned [OUTPUT_DEPTH_FRACBITS-1:0] o_vertex_z[3],

    output logic signed [OUTPUT_VERTEX_DATAWIDTH-1:0] bb_tl[2],
    output logic signed [OUTPUT_VERTEX_DATAWIDTH-1:0] bb_br[2],
    output logic o_triangle_dv,
    output logic finished,

    // DEBUG ---- REMOVE WHEN FINISHED
    output logic o_vs_finished,
    output logic o_vpp_finished,
    output logic o_pa_started
    );

    // Vertex Shader
    logic w_vs_ready;
    logic w_vs_finished;
    logic r_vs_enable;

    logic signed [INPUT_VERTEX_DATAWIDTH-1:0] w_vs_o_vertex[4];
    logic w_vs_o_vertex_dv;

    vertex_shader #(
        .DATAWIDTH(INPUT_VERTEX_DATAWIDTH),
        .FRACBITS(INPUT_VERTEX_FRACBITS)
    ) vertex_shader_inst (
        .clk(clk),
        .rstn(rstn),

        .o_ready(w_vs_ready),
        .o_finished(w_vs_finished),
        .i_enable(r_vs_enable),

        .i_mvp_mat(i_mvp_matrix),
        .i_mvp_dv(i_mvp_dv),

        .i_vertex(i_vertex),
        .i_vertex_dv(i_vertex_dv),
        .i_vertex_last(i_vertex_last),

        .o_vertex(w_vs_o_vertex),
        .o_vertex_dv(w_vs_o_vertex_dv)
    );

    // Vertex Post-Processor
    logic signed [INPUT_VERTEX_DATAWIDTH-1:0] r_vpp_i_vertex[4];
    logic r_vpp_i_vertex_dv;

    logic signed [OUTPUT_VERTEX_DATAWIDTH-1:0] w_vpp_pixel[2];
    logic signed [OUTPUT_DEPTH_FRACBITS-1:0] w_vpp_z;
    logic w_vpp_done;

    logic w_vpp_o_vertex_invalid;
    logic w_vpp_ready;

    logic r_vpp_last_vertex = '0;
    logic r_vpp_finished = '0;

    logic [$clog2(MAX_VERTEX_COUNT)-1:0] r_vertexes_processed = '0;

    vertex_post_processor #(
        .IV_DATAWIDTH(INPUT_VERTEX_DATAWIDTH),
        .IV_FRACBITS(INPUT_VERTEX_FRACBITS),
        .OV_DATAWIDTH(OUTPUT_VERTEX_DATAWIDTH),
        .O_DEPTH_FRACBITS(OUTPUT_DEPTH_FRACBITS),

        .WIDTH(SCREEN_WIDTH),
        .HEIGHT(SCREEN_HEIGHT),
        .ZFAR(ZFAR),
        .ZNEAR(ZNEAR)
    ) vertex_post_processor_inst (
        .clk(clk),
        .rstn(rstn),

        .ready(w_vpp_ready),

        .i_vertex(r_vpp_i_vertex),
        .i_vertex_dv(r_vpp_i_vertex_dv),

        .o_vertex_pixel(w_vpp_pixel),
        .o_vertex_z(w_vpp_z),

        .invalid(w_vpp_o_vertex_invalid),
        .done(w_vpp_done)
    );

    // G-Buffer for storing the VPP Data, and loading for primitive assembler
    logic w_gbuff_ready;
    logic r_gbuff_write_en;
    logic r_gbuff_read_en;
    logic [$clog2(MAX_VERTEX_COUNT)-1:0] r_gbuff_addr_write;
    logic [$clog2(MAX_VERTEX_COUNT)-1:0] r_gbuff_addr_read_port0;
    logic [$clog2(MAX_VERTEX_COUNT)-1:0] r_gbuff_addr_read_port1;
    logic [$clog2(MAX_VERTEX_COUNT)-1:0] r_gbuff_addr_read_port2;

    logic [3 * OUTPUT_VERTEX_DATAWIDTH-1:0] r_gbuff_data_write;
    logic [3 * OUTPUT_VERTEX_DATAWIDTH-1:0] w_gbuff_data_read_port0;
    logic [3 * OUTPUT_VERTEX_DATAWIDTH-1:0] w_gbuff_data_read_port1;
    logic [3 * OUTPUT_VERTEX_DATAWIDTH-1:0] w_gbuff_data_read_port2;
    logic w_gbuff_dv;

    g_buffer #(
        .VERTEX_DATAWIDTH(OUTPUT_VERTEX_DATAWIDTH),
        .MAX_VERTEX_COUNT(MAX_TRIANGLE_COUNT)
    ) g_buffer_inst (
        .clk(clk),
        .rstn(rstn),

        .ready(w_gbuff_ready),
        .write_en(r_gbuff_write_en),
        .read_en(r_gbuff_read_en),

        .addr_write(r_gbuff_addr_write),
        .addr_read_port0(r_gbuff_addr_read_port0),
        .addr_read_port1(r_gbuff_addr_read_port1),
        .addr_read_port2(r_gbuff_addr_read_port2),

        .data_write(r_gbuff_data_write),
        .data_read_port0(w_gbuff_data_read_port0),
        .data_read_port1(w_gbuff_data_read_port1),
        .data_read_port2(w_gbuff_data_read_port2),
        .dv(w_gbuff_dv)
    );

    // Primitive assembler
    logic r_pa_start;
    logic w_pa_o_ready;
    logic w_pa_finished;

    logic [$clog2(MAX_VERTEX_COUNT)-1:0] w_pa_vertex_addr[3];
    logic w_pa_vertex_read_en;

    logic [OUTPUT_VERTEX_DATAWIDTH-1:0] r_pa_i_v0[2];
    logic [OUTPUT_DEPTH_FRACBITS-1:0]   r_pa_i_v0_z;

    logic [OUTPUT_VERTEX_DATAWIDTH-1:0] r_pa_i_v1[2];
    logic [OUTPUT_DEPTH_FRACBITS-1:0]   r_pa_i_v1_z;

    logic [OUTPUT_VERTEX_DATAWIDTH-1:0] r_pa_i_v2[2];
    logic [OUTPUT_DEPTH_FRACBITS-1:0]   r_pa_i_v2_z;
    logic r_pa_i_vertex_dv = '0;

    logic r_pa_finished = '0;

    // TODO: Add vertex invalid signal to gbuffer and propagate it to PA
    primitive_assembler #(
        .IV_DATAWIDTH(OUTPUT_VERTEX_DATAWIDTH),
        .IV_DEPTH_FRACBITS(OUTPUT_DEPTH_FRACBITS),
        .SCREEN_WIDTH(SCREEN_WIDTH),
        .SCREEN_HEIGHT(SCREEN_HEIGHT),
        .MAX_TRIANGLE_COUNT(MAX_TRIANGLE_COUNT),
        .MAX_VERTEX_COUNT(MAX_VERTEX_COUNT)
    ) primitive_assembler_inst (
        .clk(clk),
        .rstn(rstn),

        .start(r_pa_start),
        .i_ready(i_triangle_ready),
        .o_ready(w_pa_o_ready),
        .finished(w_pa_finished),

        .i_num_triangles(i_num_triangles),
        .o_index_buff_addr(o_index_buff_addr),
        .o_index_buff_read_en(o_index_buff_read_en),
        .i_vertex_idxs(i_vertex_idxs),

        .o_vertex_addr(w_pa_vertex_addr),
        .o_vertex_read_en(w_pa_vertex_read_en),

        .i_v0(r_pa_i_v0),
        .i_v0_z(r_pa_i_v0_z),
        .i_v0_invalid(0),
        .i_v1(r_pa_i_v1),
        .i_v1_z(r_pa_i_v1_z),
        .i_v1_invalid(0),
        .i_v2(r_pa_i_v2),
        .i_v2_z(r_pa_i_v2_z),
        .i_v2_invalid(0),
        .i_vertex_dv(r_pa_i_vertex_dv),

        .o_vertex_pixel(o_vertex_pixel),
        .o_vertex_z(o_vertex_z),
        .bb_tl(bb_tl),
        .bb_br(bb_br),
        .o_dv(o_triangle_dv)
    );

    // Assign Vertex Post-Proccessor output to output
    always_ff @(posedge clk) begin
        if (~rstn) begin
            // VPP
            foreach (r_vpp_i_vertex[i]) r_vpp_i_vertex[i] <= '0;
            r_vpp_i_vertex_dv    <= '0;
            r_vpp_last_vertex    <= '0;
            vpp_error            <= '0;
            r_vpp_finished       <= '0;
            r_vertexes_processed <= '0;

            // GBuff
            r_gbuff_write_en    <= '0;
            r_gbuff_read_en     <= '0;
            r_gbuff_addr_write  <= '0;

            r_gbuff_addr_write  <= '0;
            r_gbuff_data_write  <= '0;

            r_gbuff_addr_read_port0 <= '0;
            r_gbuff_addr_read_port1 <= '0;
            r_gbuff_addr_read_port2 <= '0;

            // PA
            r_pa_start <= '0;
            r_pa_i_vertex_dv <= '0;

            foreach(r_pa_i_v0[i]) r_pa_i_v0[i] <= '0;
            r_pa_i_v0_z  <= '0;

            foreach(r_pa_i_v1[i]) r_pa_i_v1[i] <= '0;
            r_pa_i_v1_z  <= '0;

            foreach(r_pa_i_v2[i]) r_pa_i_v2[i] <= '0;
            r_pa_i_v2_z  <= '0;
            r_pa_finished <= '0;

        end else begin
            if (w_vs_o_vertex_dv) begin
                foreach (r_vpp_i_vertex[i]) r_vpp_i_vertex[i] <= w_vs_o_vertex[i];
                r_vpp_i_vertex_dv <= '1;

                r_vpp_last_vertex <= w_vs_finished;
            end else begin
                r_vpp_i_vertex_dv <= '0;
            end

            if (w_vpp_done & !r_vpp_finished) begin
                if (!w_vpp_o_vertex_invalid) begin
                    // Increment the gbuff addr
                    r_gbuff_addr_write <= r_vertexes_processed;
                    r_vertexes_processed <= r_vertexes_processed + 1;

                    // Write VPP data to gbuff
                    r_gbuff_write_en <= '1;
                    r_gbuff_data_write <= {w_vpp_pixel[0], w_vpp_pixel[1], w_vpp_z};
                end else begin
                    r_gbuff_write_en <= '0;
                end

                // If this was the last vertex, latch vpp finished signal
                if (r_vpp_last_vertex) begin
                    r_vpp_finished <= '1;
                end

                // Reset read_en
                r_gbuff_read_en <= '0;
            end else if (r_vpp_finished & !r_pa_finished) begin
                // Start running primitive assembler as vpp is finished
                r_gbuff_write_en <= '0;   // Will only be doing read operations on buffer

                if (w_pa_o_ready & !w_pa_finished & i_triangle_ready) begin
                    r_pa_start <= '1;
                end

                if (w_pa_finished) begin
                    r_pa_finished <= '1;
                end

                // Assign primitive assembler signals
                if (w_gbuff_ready & w_pa_vertex_read_en & i_triangle_ready) begin
                    r_gbuff_read_en <= '1;
                end else begin
                    r_gbuff_read_en <= '0;
                end
                r_gbuff_addr_read_port0 <= w_pa_vertex_addr[0];
                r_gbuff_addr_read_port1 <= w_pa_vertex_addr[1];
                r_gbuff_addr_read_port2 <= w_pa_vertex_addr[2];

                if (w_gbuff_dv & i_triangle_ready) begin
                    {r_pa_i_v0[0], r_pa_i_v0[1], r_pa_i_v0_z} <= w_gbuff_data_read_port0;
                    {r_pa_i_v1[0], r_pa_i_v1[1], r_pa_i_v1_z} <= w_gbuff_data_read_port1;
                    {r_pa_i_v2[0], r_pa_i_v2[1], r_pa_i_v2_z} <= w_gbuff_data_read_port2;
                    r_pa_i_vertex_dv <= '1;
                end else begin
                    r_pa_i_vertex_dv <= '0;
                end

            end else begin
                r_pa_start <= '0;
            end
        end
    end

    assign r_vs_enable = w_vpp_ready;
    assign vertex_ready = w_vs_ready;
    assign finished = w_pa_finished;

    // DEBUG
    assign o_vs_finished = w_vs_finished;
    assign o_vpp_finished = r_vpp_finished;
    assign o_pa_started = r_pa_start;

    assign debug_o_vertex[0] = w_vpp_pixel[0];
    assign debug_o_vertex[1] = w_vpp_pixel[1];
    assign debug_o_vertex_dv = w_vpp_done;

endmodule
