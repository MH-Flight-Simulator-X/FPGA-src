`timescale 1ns / 1ps

/* verilator lint_off PINCONNECTEMPTY */
module model_reader #(
    parameter integer MODEL_INDEX_WIDTH = 4,
    parameter integer INDEX_ADDR_WIDTH = 15,
    parameter integer VERTEX_ADDR_WIDTH = 15,
    parameter integer COORDINATE_WIDTH = 24,
    parameter string  MODEL_HEADER_FILE = "model_headers.mem",
    parameter string  MODEL_FACES_FILE = "model_faces.mem",
    parameter string  MODEL_VERTEX_FILE = "model_vertex.mem"
)(
    input  logic                             clk,
    input  logic                             reset,
    output logic                             ready,

    input  logic [MODEL_INDEX_WIDTH-1:0]     model_index,

    input  logic                             index_read_en,
    input  logic                             vertex_read_en,

    output logic [INDEX_ADDR_WIDTH-1:0]         index_data[3],
    output logic signed [COORDINATE_WIDTH-1:0]  vertex_data[3],

    output logic                             index_o_dv,
    output logic                             vertex_o_dv,
    output logic                             index_data_last,
    output logic                             vertex_data_last
);

    localparam integer VERTEX_DATA_WIDTH = COORDINATE_WIDTH * 3;
    localparam integer INDEX_DATA_WIDTH = INDEX_ADDR_WIDTH * 3;
    localparam integer HEADER_DATA_WIDTH = INDEX_ADDR_WIDTH + VERTEX_ADDR_WIDTH;

    logic [MODEL_INDEX_WIDTH-1:0] header_addr;
    logic [HEADER_DATA_WIDTH-1:0] header_data;


    // Current and end indices for faces and vertices
    logic  [INDEX_ADDR_WIDTH-1:0]   index_addr;
    logic  [VERTEX_ADDR_WIDTH-1:0] vertex_addr;

    logic [INDEX_ADDR_WIDTH-1:0]    index_end_addr;
    logic [VERTEX_ADDR_WIDTH-1:0]  vertex_end_addr;

    // Wires from ROMs
    logic [INDEX_DATA_WIDTH-1:0]            w_index_data;
    logic signed [VERTEX_DATA_WIDTH-1:0]    w_vertex_data;
    logic w_index_data_last;
    logic w_vertex_data_last;

    // Header ROM
    rom #(
        .WIDTH(HEADER_DATA_WIDTH),
        .DEPTH(1 << MODEL_INDEX_WIDTH),  // TODO set to actual size
        .FILE(MODEL_HEADER_FILE)
    ) headers_rom (
        .clk(clk),
        .addr(header_addr),
        .data(header_data)
    );

    // Faces ROM
    rom #(
        .WIDTH(INDEX_DATA_WIDTH),
        .DEPTH(1 << INDEX_ADDR_WIDTH),  // TODO set to actual size
        .FILE(MODEL_FACES_FILE)
    ) faces_rom (
        .clk(clk),
        .addr(index_addr),
        .data(w_index_data)
    );

    // Vertices ROM
    rom #(
        .WIDTH(VERTEX_DATA_WIDTH),
        .DEPTH(1 << VERTEX_ADDR_WIDTH), // TODO set to actual size
        .FILE(MODEL_VERTEX_FILE),
        .BIN(1)
    ) vertices_rom (
        .clk(clk),
        .addr(vertex_addr),
        .data(w_vertex_data)
    );


    // State machine states
    typedef enum logic [2:0] {
        IDLE,
        WAIT_HEADER_0_READ,
        READ_HEADER_0,
        WAIT_HEADER_1_READ,
        READ_HEADER_1,
        READY
    } state_t;
    state_t current_state, next_state;

    always_ff @(posedge clk) begin
        if (reset) begin
            current_state <= IDLE;
        end
        else begin
            current_state <= next_state;
        end
    end

    // State transitions
    always_comb begin
        ready = 1'b0;

        w_index_data_last = 1'b0;
        w_vertex_data_last = 1'b0;

        case (current_state)
            IDLE: begin
                next_state = WAIT_HEADER_0_READ;
            end

            WAIT_HEADER_0_READ: begin
                next_state = READ_HEADER_0;
            end

            READ_HEADER_0: begin
                next_state = WAIT_HEADER_1_READ;
            end

            WAIT_HEADER_1_READ: begin
                next_state = READ_HEADER_1;
            end

            READ_HEADER_1: begin
                next_state = READY;
            end

            READY: begin
                next_state = READY;
                ready = 1'b1;
                if (index_addr == index_end_addr - 1) w_index_data_last = 1'b1;
                if (vertex_addr == vertex_end_addr - 1) w_vertex_data_last = 1'b1;
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

    // State operations
    always_ff @(posedge clk) begin
        if (reset) begin
            foreach (index_data[i]) index_data[i] <= '0;
            index_o_dv <= '0;
            index_data_last <= '0;

            foreach (vertex_data[i]) vertex_data[i] <= '0;
            vertex_o_dv <= '0;
            vertex_data_last <= '0;
        end else begin
            case (current_state)
                IDLE: begin
                    header_addr <= model_index;
                end

                READ_HEADER_0: begin
                    // Read start indices from header
                    index_addr <= header_data[HEADER_DATA_WIDTH-1:VERTEX_ADDR_WIDTH];
                    vertex_addr <= header_data[VERTEX_ADDR_WIDTH-1:0];

                    // Increment header addr to read end indices
                    header_addr <= model_index + 1;
                end


                READ_HEADER_1: begin
                    // Read end indices from header
                    index_end_addr <= header_data[HEADER_DATA_WIDTH-1:VERTEX_ADDR_WIDTH];
                    vertex_end_addr <= header_data[VERTEX_ADDR_WIDTH-1:0];
                end

                READY: begin
                    // Handle face data
                    if (index_read_en) begin
                        if (index_o_dv) begin
                            foreach (index_data[i]) index_data[i] <= '0;
                            index_o_dv <= '0;
                            index_data_last <= '0;
                        end else begin
                            index_data[0] <= w_index_data[VERTEX_ADDR_WIDTH-1:0];
                            index_data[1] <= w_index_data[2*VERTEX_ADDR_WIDTH-1:VERTEX_ADDR_WIDTH];
                            index_data[2] <= w_index_data[3*VERTEX_ADDR_WIDTH-1:2*VERTEX_ADDR_WIDTH];

                            index_o_dv <= (index_addr <= index_end_addr);
                            index_data_last <= w_index_data_last;
                        end
                    end

                    if (index_read_en && !w_index_data_last && index_o_dv) begin
                        index_addr <= (index_addr == index_end_addr - 1) ? index_addr : index_addr + 1;
                    end

                    // Handle vertex data
                    if (vertex_read_en) begin
                        if (vertex_o_dv) begin
                            foreach (vertex_data[i]) vertex_data[i] <= '0;
                            vertex_o_dv <= '0;
                            vertex_data_last <= '0;
                        end else begin
                            vertex_data[0] <= w_vertex_data[COORDINATE_WIDTH-1:0];
                            vertex_data[1] <= w_vertex_data[2*COORDINATE_WIDTH-1:COORDINATE_WIDTH];
                            vertex_data[2] <= w_vertex_data[3*COORDINATE_WIDTH-1:2*COORDINATE_WIDTH];

                            vertex_o_dv <= (vertex_addr <= vertex_end_addr);
                            vertex_data_last <= w_vertex_data_last;
                        end
                    end

                    if (vertex_read_en && !w_vertex_data_last && vertex_o_dv) begin
                        vertex_addr <= (vertex_addr == vertex_end_addr - 1) ? vertex_addr : vertex_addr + 1;
                    end
                end

                default: begin
                    // Do nothing
                end
            endcase
        end
    end

endmodule
