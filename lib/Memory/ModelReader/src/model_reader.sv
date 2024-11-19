`timescale 1ns / 1ps

module model_reader #(
    parameter integer MODEL_INDEX_WIDTH = 4,
    parameter integer HEADER_ADDR_WIDTH = 4,
    parameter integer index_addr_WIDTH = 12,
    parameter integer VERTEX_ADDR_WIDTH = 12,
    parameter integer COORD_WIDTH = 24,
    parameter integer VERTEX_DATA_WIDTH = COORD_WIDTH * 3,
    parameter integer INDEX_DATA_WIDTH = index_addr_WIDTH * 3,
    parameter integer HEADER_DATA_WIDTH = index_addr_WIDTH + VERTEX_ADDR_WIDTH,
    parameter string  HEADERS_FILE = "../../ModelReader/src/headers.mem",
    parameter string  FACES_FILE = "../../ModelReader/src/faces.mem",
    parameter string  VERTICES_FILE = "../../ModelReader/src/vertices.mem"
)(
    input  logic                             clk,
    input  logic                             rstn,
    output logic                             ready,

    input  logic [MODEL_INDEX_WIDTH-1:0]     model_index,

    input  logic                             index_read_en,
    input  logic                             vertex_read_en,

    output logic [INDEX_DATA_WIDTH-1:0]      index_data,
    output logic [VERTEX_DATA_WIDTH-1:0]     vertex_data,

    output logic                             index_o_dv,
    output logic                             vertex_o_dv,
    output logic                             index_buffer_last,
    output logic                             vertex_buffer_last
);

logic  [HEADER_ADDR_WIDTH-1:0] header_addr;
logic [HEADER_DATA_WIDTH-1:0]  header_data;


logic  [index_addr_WIDTH-1:0]   index_addr;
logic  [VERTEX_ADDR_WIDTH-1:0] vertex_addr;

// Start and end indices for faces and vertices
logic [index_addr_WIDTH-1:0]    index_end_index;
logic [VERTEX_ADDR_WIDTH-1:0]  vertex_end_index;

// State machine states
typedef enum logic [2:0] {
    IDLE,
    READ_HEADER_0,
    WAIT_HEADER_READ,
    READ_HEADER_1,
    READY
} state_t;
state_t current_state, next_state;

// Header ROM
rom #(
    .WIDTH(HEADER_DATA_WIDTH),
    .DEPTH(1 << HEADER_ADDR_WIDTH),  // TODO set to actual size
    .FILE(HEADERS_FILE)
) headers_rom (
    .clk(clk),
    .read_en(1),
    .addr(header_addr),
    .data(header_data),
    .dv()
);

// Faces ROM
rom #(
    .WIDTH(INDEX_DATA_WIDTH),
    .DEPTH(1 << index_addr_WIDTH),  // TODO set to actual size
    .FILE(FACES_FILE)
) faces_rom (
    .clk(clk),
    .read_en(index_read_en),
    .addr(index_addr),
    .data(index_data),
    .dv(index_o_dv)
);

// Vertices ROM
rom #(
    .WIDTH(VERTEX_DATA_WIDTH),
    .DEPTH(1 << VERTEX_ADDR_WIDTH), // TODO set to actual size
    .FILE(VERTICES_FILE)
) vertices_rom (
    .clk(clk),
    .read_en(vertex_read_en),
    .addr(vertex_addr),
    .data(vertex_data),
    .dv(vertex_o_dv)
);


always_ff @(posedge clk) begin
    if (~rstn) begin
        current_state <= IDLE;
    end
    else begin
        current_state <= next_state;
    end
end

// State transitions
always_comb begin
    ready = 1'b0;
    index_buffer_last = 1'b0;
    vertex_buffer_last = 1'b0;

    case (current_state)
        IDLE: begin
            next_state = READ_HEADER_0;
        end

        READ_HEADER_0: begin
            next_state = WAIT_HEADER_READ;
        end

        WAIT_HEADER_READ: begin
            next_state = READ_HEADER_1;
        end

        READ_HEADER_1: begin
            next_state = READY;
        end

        READY: begin
            next_state = READY;
            ready = 1'b1;
            if (index_addr == index_end_index - 1) index_buffer_last = 1'b1;
            if (vertex_addr == vertex_end_index - 1) vertex_buffer_last = 1'b1;
        end

        default: begin
            next_state = IDLE;
        end
    endcase
end

// State operations
always_ff @(posedge clk) begin
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

        WAIT_HEADER_READ: begin
            // Wait for header ROM to output data
        end

        READ_HEADER_1: begin
            // Read end indices from header
            index_end_index <= header_data[HEADER_DATA_WIDTH-1:VERTEX_ADDR_WIDTH];
            vertex_end_index <= header_data[VERTEX_ADDR_WIDTH-1:0];
        end

        READY: begin
            // Handle face data
            if (index_read_en && !index_buffer_last) begin
                index_addr <= (index_addr == index_end_index - 1) ? index_addr : index_addr + 1;
            end

            // Handle vertex data
            if (vertex_read_en && !vertex_buffer_last) begin
                vertex_addr <= (vertex_addr == vertex_end_index - 1) ? vertex_addr : vertex_addr + 1;
            end
        end

        default: begin
            // Do nothing
        end
    endcase
end

endmodule
