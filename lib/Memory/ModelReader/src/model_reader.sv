`timescale 1ns / 1ps

module model_reader #(
    parameter integer MODEL_INDEX_WIDTH = 4,
    parameter integer HEADER_ADDR_WIDTH = 4,
    parameter integer FACE_ADDR_WIDTH = 12,
    parameter integer VERTEX_ADDR_WIDTH = 12,
    parameter integer COORD_WIDTH = 24,
    parameter integer VERTEX_DATA_WIDTH = COORD_WIDTH * 3,
    parameter integer FACE_DATA_WIDTH = FACE_ADDR_WIDTH * 3,
    parameter integer HEADER_DATA_WIDTH = FACE_ADDR_WIDTH + VERTEX_ADDR_WIDTH,
    parameter string  HEADERS_FILE = "../../ModelReader/src/headers.mem",
    parameter string  FACES_FILE = "../../ModelReader/src/faces.mem",
    parameter string  VERTICES_FILE = "../../ModelReader/src/vertices.mem"
)(
    input  logic                             clk,
    input  logic                             rstn,

    input  logic [MODEL_INDEX_WIDTH-1:0]     model_index,

    input  logic                             next_face,
    input  logic                             next_vertex,

    output logic [FACE_DATA_WIDTH-1:0]       face_data,
    output logic [VERTEX_DATA_WIDTH-1:0]     vertex_data,

    output logic                             face_buffer_done,
    output logic                             vertex_buffer_done,

    output logic                             data_valid
);

logic  [HEADER_ADDR_WIDTH-1:0] header_addr;
logic [HEADER_DATA_WIDTH-1:0]  header_data;


logic  [FACE_ADDR_WIDTH-1:0]   face_addr;
logic  [VERTEX_ADDR_WIDTH-1:0] vertex_addr;

// Start and end indices for faces and vertices
logic [FACE_ADDR_WIDTH-1:0]    face_end_index;
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
    .addr(header_addr),
    .data(header_data)
);

// Faces ROM
rom #(
    .WIDTH(FACE_DATA_WIDTH),
    .DEPTH(1 << FACE_ADDR_WIDTH),  // TODO set to actual size
    .FILE(FACES_FILE)
) faces_rom (
    .clk(clk),
    .addr(face_addr),
    .data(face_data)
);

// Vertices ROM
rom #(
    .WIDTH(VERTEX_DATA_WIDTH),
    .DEPTH(1 << VERTEX_ADDR_WIDTH), // TODO set to actual size
    .FILE(VERTICES_FILE)
) vertices_rom (
    .clk(clk),
    .addr(vertex_addr),
    .data(vertex_data)
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
    data_valid = 1'b0;
    face_buffer_done = 1'b0;
    vertex_buffer_done = 1'b0;

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
            data_valid = 1'b1;
            if (face_addr == face_end_index - 1) face_buffer_done = 1'b1;
            if (vertex_addr == vertex_end_index - 1) vertex_buffer_done = 1'b1;
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
            face_addr <= header_data[HEADER_DATA_WIDTH-1:VERTEX_ADDR_WIDTH];
            vertex_addr <= header_data[VERTEX_ADDR_WIDTH-1:0];
            
            // Increment header addr to read end indices
            header_addr <= model_index + 1;
        end

        WAIT_HEADER_READ: begin
            // Wait for header ROM to output data
        end

        READ_HEADER_1: begin
            // Read end indices from header
            face_end_index <= header_data[HEADER_DATA_WIDTH-1:VERTEX_ADDR_WIDTH];
            vertex_end_index <= header_data[VERTEX_ADDR_WIDTH-1:0];
        end

        READY: begin
            // Handle face data
            if (next_face && !face_buffer_done) begin
                face_addr <= (face_addr == face_end_index - 1) ? face_addr : face_addr + 1;
            end

            // Handle vertex data
            if (next_vertex && !vertex_buffer_done) begin
                vertex_addr <= (vertex_addr == vertex_end_index - 1) ? vertex_addr : vertex_addr + 1;
            end
        end

        default: begin
            // Do nothing
        end
    endcase
end

endmodule
