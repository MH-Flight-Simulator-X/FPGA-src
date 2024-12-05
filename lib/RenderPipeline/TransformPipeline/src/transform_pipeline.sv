// TODO: Look at making matrix data 18 bit FP numbers, as this will reduce
// logic in vertex shader component, and will make packing the matrix data
// easier in the "FIFO"

`timescale 1ns / 1ps

module transform_pipeline #(
    parameter unsigned INPUT_DATAWIDTH = 24,
    parameter unsigned INPUT_FRACBITS = 13,
    parameter unsigned OUTPUT_DATAWIDTH = 12,   // Pixel coordinates are integers,
                                                // whilst depth is Q0.12
                                                // NB. signals are signed, but
                                                // z value should be
                                                // interpreted as unsigned!

    parameter unsigned MAX_TRIANGLE_COUNT = 16384,  // For testing
    parameter unsigned MAX_VERTEX_COUNT = 16384,    // When building set to something like 4096

    parameter unsigned SCREEN_WIDTH = 640,
    parameter unsigned SCREEN_HEIGHT = 480,

    parameter real ZFAR = 100.0,
    parameter real ZNEAR = 0.1
    ) (
    input logic clk,
    input logic rstn,

    // Signals
    input logic transform_pipeline_start,
    input logic transform_pipeline_next,    // Ready to recieve next triangle
    output logic transform_pipeline_ready,
    output logic transform_pipeline_done,

    // Transform matrix from MVP Matrix FIFO
    output logic o_mvp_matrix_read_en,
    input logic signed [INPUT_DATAWIDTH-1:0] i_mvp_matrix[4][4],
    input logic i_mvp_dv,

    // Read vertex data from Model Buffer -- Effectively accessed as SAM
    output logic o_model_buff_vertex_read_en,
    input logic signed [INPUT_DATAWIDTH-1:0] i_vertex[3],
    input logic i_vertex_dv,
    input logic i_vertex_last,

    // Read index data from Model Buffer -- Also SAM access pattern
    output logic o_model_buff_index_read_en,
    input logic [$clog2(MAX_VERTEX_COUNT)-1:0] i_index_data[3],
    input logic i_index_dv,
    input logic i_index_last,

    // Output triangle data
    output logic signed [OUTPUT_DATAWIDTH-1:0] o_v0[3],
    output logic signed [OUTPUT_DATAWIDTH-1:0] o_v1[3],
    output logic signed [OUTPUT_DATAWIDTH-1:0] o_v2[3],
    output logic o_triangle_dv,
    output logic o_triangle_last
    );

    // ====== MODULE INSTANTIATION ======
    // Vertex Shader
    logic w_vs_ready;
    logic w_vs_vertex_ready;
    logic w_vs_finished;

    logic signed [INPUT_DATAWIDTH-1:0] w_vs_o_vertex[4];
    logic w_vs_o_vertex_dv;

    vertex_shader_new #(
        .DATAWIDTH(INPUT_DATAWIDTH),
        .FRACBITS(INPUT_FRACBITS)
    ) vertex_shader_inst (
        .clk(clk),
        .rstn(rstn),

        .o_ready(w_vs_ready),
        .o_vertex_ready(w_vs_vertex_ready),
        .i_ready(w_vpp_ready),

        .i_mvp(i_mvp_matrix),
        .i_mvp_valid(i_mvp_dv),

        .i_vertex(i_vertex),
        .i_vertex_valid(i_vertex_dv),
        .i_vertex_last(i_vertex_last),

        .o_vertex(w_vs_o_vertex),
        .o_vertex_valid(w_vs_o_vertex_dv),
        .o_finished(w_vs_finished)
    );

    assign o_mvp_matrix_read_en = w_vs_ready & (current_state == VERTEX_SHADER_GET_MATRIX);

    // Vertex Post-Processor
    logic signed [INPUT_DATAWIDTH-1:0] r_vpp_i_vertex[4];
    logic r_vpp_i_vertex_dv;

    logic signed [OUTPUT_DATAWIDTH-1:0] w_vpp_pixel[3];
    logic w_vpp_done;

    logic w_vpp_o_vertex_invalid;
    logic w_vpp_ready;

    logic r_vpp_last_vertex = '0;
    logic r_vpp_last_vertex_finished = '0;

    logic [$clog2(MAX_VERTEX_COUNT)-1:0] r_vertexes_processed = '0;

    vertex_post_processor #(
        .IV_DATAWIDTH(INPUT_DATAWIDTH),
        .IV_FRACBITS(INPUT_FRACBITS),
        .OV_DATAWIDTH(OUTPUT_DATAWIDTH),

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

        .invalid(w_vpp_o_vertex_invalid),
        .done(w_vpp_done)
    );

    // G-Buffer
    logic w_gbuff_ready;
    logic r_gbuff_write_en;
    logic r_gbuff_read_en;
    logic [$clog2(MAX_VERTEX_COUNT)-1:0] r_gbuff_addr_write;
    logic [$clog2(MAX_VERTEX_COUNT)-1:0] r_gbuff_addr_read_port0;
    logic [$clog2(MAX_VERTEX_COUNT)-1:0] r_gbuff_addr_read_port1;
    logic [$clog2(MAX_VERTEX_COUNT)-1:0] r_gbuff_addr_read_port2;

    logic [3 * OUTPUT_DATAWIDTH-1:0] r_gbuff_data_write;
    logic [3 * OUTPUT_DATAWIDTH-1:0] w_gbuff_data_read_port0;
    logic [3 * OUTPUT_DATAWIDTH-1:0] w_gbuff_data_read_port1;
    logic [3 * OUTPUT_DATAWIDTH-1:0] w_gbuff_data_read_port2;
    logic w_gbuff_dv;

    g_buffer #(
        .VERTEX_DATAWIDTH(OUTPUT_DATAWIDTH),
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

    logic [OUTPUT_DATAWIDTH-1:0] r_pa_i_v0[3];
    logic [OUTPUT_DATAWIDTH-1:0] r_pa_i_v1[3];
    logic [OUTPUT_DATAWIDTH-1:0] r_pa_i_v2[3];
    logic r_pa_i_vertex_dv = '0;

    // TODO: Add vertex invalid signal to gbuffer and propagate it to PA
    primitive_assembler #(
        .DATAWIDTH(OUTPUT_DATAWIDTH),
        .SCREEN_WIDTH(SCREEN_WIDTH),
        .SCREEN_HEIGHT(SCREEN_HEIGHT),
        .MAX_TRIANGLE_COUNT(MAX_TRIANGLE_COUNT),
        .MAX_VERTEX_COUNT(MAX_VERTEX_COUNT)
    ) primitive_assembler_inst (
        .clk(clk),
        .rstn(rstn),

        .start(r_pa_start),
        .i_ready(transform_pipeline_next),
        .o_ready(w_pa_o_ready),
        .finished(w_pa_finished),

        .o_index_buff_read_en(o_model_buff_index_read_en),
        .i_index_data(i_index_data),
        .i_index_dv(i_index_dv),
        .i_index_last(i_index_last),

        .o_vertex_addr(w_pa_vertex_addr),
        .o_vertex_read_en(w_pa_vertex_read_en),

        .i_v0(r_pa_i_v0),
        .i_v0_invalid(0),

        .i_v1(r_pa_i_v1),
        .i_v1_invalid(0),

        .i_v2(r_pa_i_v2),
        .i_v2_invalid(0),
        .i_vertex_dv(r_pa_i_vertex_dv),

        .o_v0(o_v0),
        .o_v1(o_v1),
        .o_v2(o_v2),
        .o_dv(o_triangle_dv),
        .o_last(o_triangle_last)
    );

    // ====== STATE ======
    typedef enum logic [2:0] {
        IDLE,
        VERTEX_SHADER_GET_MATRIX,
        VERTEX_SHADER,
        PRIMITIVE_ASSEMBLER,
        DONE
    } state_t;
    state_t current_state = IDLE, next_state;
    state_t last_state = IDLE;

    always_ff @(posedge clk) begin
        if (~rstn) begin
            current_state <= IDLE;
            last_state <= IDLE;
        end else begin
            current_state <= next_state;
            last_state <= current_state;
            // if (current_state != last_state) begin
            //     $display("### Transform pipeline ### Next state: %s", current_state.name());
            // end
        end
    end

    always_comb begin
        next_state = current_state;
        transform_pipeline_ready = 1'b0;
        transform_pipeline_done = 1'b0;

        case (current_state)
            IDLE: begin
                if (transform_pipeline_start) begin
                    next_state = VERTEX_SHADER_GET_MATRIX;
                end
                transform_pipeline_ready = 1'b1;
            end

            VERTEX_SHADER_GET_MATRIX: begin
                if (i_mvp_dv) begin
                    next_state = VERTEX_SHADER;
                end
            end

            VERTEX_SHADER: begin
                if (w_vpp_done & r_vpp_last_vertex_finished) begin
                    next_state = PRIMITIVE_ASSEMBLER;
                end
            end

            PRIMITIVE_ASSEMBLER: begin
                if (w_pa_finished) begin
                    next_state = DONE;
                end
            end

            DONE: begin
                transform_pipeline_done = 1'b1;
                next_state = IDLE;
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

    always_ff @(posedge clk) begin
        if (~rstn) begin
            // VPP
            foreach (r_vpp_i_vertex[i]) r_vpp_i_vertex[i] <= '0;
            r_vpp_i_vertex_dv    <= '0;
            r_vpp_last_vertex    <= '0;
            r_vpp_last_vertex_finished <= '0;
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
            foreach(r_pa_i_v1[i]) r_pa_i_v1[i] <= '0;
            foreach(r_pa_i_v2[i]) r_pa_i_v2[i] <= '0;

        end else begin
            case (current_state)
                IDLE: begin
                    foreach (r_vpp_i_vertex[i]) r_vpp_i_vertex[i] <= '0;
                    r_vpp_i_vertex_dv    <= '0;
                    r_vpp_last_vertex    <= '0;
                    r_vpp_last_vertex_finished <= '0;
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
                    foreach(r_pa_i_v1[i]) r_pa_i_v1[i] <= '0;
                    foreach(r_pa_i_v2[i]) r_pa_i_v2[i] <= '0;
                end

                VERTEX_SHADER: begin
                    if (w_vs_o_vertex_dv) begin
                        foreach (r_vpp_i_vertex[i]) r_vpp_i_vertex[i] <= w_vs_o_vertex[i];
                        r_vpp_last_vertex <= w_vs_finished;
                        r_vpp_i_vertex_dv <= '1;
                    end else begin
                        foreach (r_vpp_i_vertex[i]) r_vpp_i_vertex[i] <= '0;
                        r_vpp_i_vertex_dv <= '0;
                    end

                    if (w_vpp_done && !w_vpp_o_vertex_invalid) begin
                        r_vpp_last_vertex_finished <= r_vpp_last_vertex;

                        // Increment the gbuff addr
                        r_gbuff_addr_write <= r_vertexes_processed;
                        r_vertexes_processed <= r_vertexes_processed + 1;

                        // Write VPP data to gbuff
                        r_gbuff_write_en <= '1;
                        r_gbuff_data_write <= {w_vpp_pixel[0], w_vpp_pixel[1], w_vpp_pixel[2]};
                    end else begin
                        r_gbuff_write_en <= '0;
                    end
                end

                PRIMITIVE_ASSEMBLER: begin
                    // Start running primitive assembler as vpp is finished
                    r_gbuff_write_en <= '0;   // Will only be doing read operations on buffer
                    foreach (r_vpp_i_vertex[i]) r_vpp_i_vertex[i] <= '0;
                    r_vpp_i_vertex_dv <= '0;

                    if (w_pa_o_ready & !w_pa_finished & transform_pipeline_next) begin
                        r_pa_start <= 1;
                    end else begin
                        r_pa_start <= 0;
                    end

                    // Assign primitive assembler signals
                    if (w_gbuff_ready & w_pa_vertex_read_en & transform_pipeline_next) begin
                        r_gbuff_read_en <= '1;
                    end else begin
                        r_gbuff_read_en <= '0;
                    end
                    r_gbuff_addr_read_port0 <= w_pa_vertex_addr[0];
                    r_gbuff_addr_read_port1 <= w_pa_vertex_addr[1];
                    r_gbuff_addr_read_port2 <= w_pa_vertex_addr[2];

                    if (w_gbuff_dv & transform_pipeline_next) begin
                        {r_pa_i_v0[0], r_pa_i_v0[1], r_pa_i_v0[2]} <= w_gbuff_data_read_port0;
                        {r_pa_i_v1[0], r_pa_i_v1[1], r_pa_i_v1[2]} <= w_gbuff_data_read_port1;
                        {r_pa_i_v2[0], r_pa_i_v2[1], r_pa_i_v2[2]} <= w_gbuff_data_read_port2;
                        r_pa_i_vertex_dv <= '1;
                    end else begin
                        r_pa_i_vertex_dv <= '0;
                    end
                end

                default: begin
                end
            endcase
        end
    end

    // assign r_vs_enable = w_vpp_ready;
    assign o_model_buff_vertex_read_en = w_vs_vertex_ready;
endmodule
