`timescale 1ns / 1ps

module model_reader #(
    parameter integer MODEL_INDEX_WIDTH = 4,
    parameter integer HEADER_ADDR_WIDTH = 4,
    parameter integer FACE_ADDR_WIDTH = 16,
    parameter integer FACE_DATA_WIDTH = 36,  // 3 x 12 bits per face
    parameter integer VERTEX_ADDR_WIDTH = 16,
    parameter integer VERTEX_DATA_WIDTH = 48  // 3 x 16 bits per vertex
    parameter integer HEADER_DATA_WIDTH = FACE_ADDR_WIDTH + VERTEX_ADDR_WIDTH,
    parameter string  HEADERS_FILE = "headers.mem"
    parameter string  FACES_FILE = "faces.mem"
    parameter string  VERTICES_FILE = "vertices.mem"
)(
    input  logic                             clk,
    input  logic                             reset,

    input  logic [MODEL_INDEX_WIDTH-1:0]     model_index,

    input  logic                             next_face,
    input  logic                             next_vertex,

    output logic [FACE_DATA_WIDTH-1:0]       face_data,
    output logic [VERTEX_DATA_WIDTH-1:0]     vertex_data,

    output logic                             face_buffer_done,
    output logic                             vertex_buffer_done
);

logic  [HEADER_ADDR_WIDTH-1:0] header_addr;
logic [HEADER_DATA_WIDTH-1:0]  header_data;

logic  [FACE_ADDR_WIDTH-1:0]   face_addr;
logic [FACE_DATA_WIDTH-1:0]    face_rom_data;

logic  [VERTEX_ADDR_WIDTH-1:0] vertex_addr;
logic [VERTEX_DATA_WIDTH-1:0]  vertex_rom_data;

// Start and end indices for faces and vertices
logic [FACE_ADDR_WIDTH-1:0]    face_start_index;
logic [FACE_ADDR_WIDTH-1:0]    face_end_index;

logic [VERTEX_ADDR_WIDTH-1:0]  vertex_start_index;
logic [VERTEX_ADDR_WIDTH-1:0]  vertex_end_index;

// State machine states
typedef enum logic [1:0] {
    IDLE,
    READ_HEADER_0,
    READ_HEADER_1,
    READY
} state_t;

state_t state;

// Header ROM
rom #(
    .WIDTH(1 << HEADER_ADDR_WIDTH), // TODO set to actual size
    .DEPTH(HEADER_DATA_WIDTH),
    .FILE(HEADERS_FILE)
) headers_rom (
    .clk(clk),
    .addr(header_addr),
    .data(header_data)
);

// Faces ROM
rom #(
    .WIDTH(1 << FACE_ADDR_WIDTH), // TODO set to actual size
    .DEPTH(FACE_DATA_WIDTH),
    .FILE(FACES_FILE)
) faces_rom (
    .clk(clk),
    .addr(face_addr),
    .data(face_rom_data)
);

// Vertices ROM
rom #(
    .WIDTH(1 << VERTEX_ADDR_WIDTH), // TODO set to actual size
    .DEPTH(VERTEX_DATA_WIDTH),
    .FILE(VERTICES_FILE)
) vertices_rom (
    .clk(clk),
    .addr(vertex_addr),
    .data(vertex_rom_data)
);

// State transitions
always_comb begin
    next_state = current_state;
    case (current_state)
        IDLE: begin
            next_state = READ_HEADER_0;
        end
        READ_HEADER_0: begin
            next_state = READ_HEADER_1;
        end
        READ_HEADER_1: begin
            next_state = READY;
        end
        READY: begin
            if (face_addr == face_end_index - 1) face_buffer_done = 1'b1;
            if (vertex_addr == vertex_end_index - 1) vertex_buffer_done = 1'b1;
            if (reset) next_state = IDLE;
        end
        default: begin
            next_state = IDLE;
        end
    endcase
end

// State operations
always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
        current_state <= IDLE;
        face_addr <= {FACE_ADDR_WIDTH{1'b0}};
        vertex_addr <= {VERTEX_ADDR_WIDTH{1'b0}};
    end else begin
        current_state <= next_state;

        case (current_state)
            IDLE: begin
                // Reset counters and addresses
                header_addr <= model_index;
                face_buffer_done <= 1'b0;
                vertex_buffer_done =< 1'b0;
            end

            READ_HEADER_0: begin
                // Load start indices from header
                face_start_index <= header_data[HEADER_DATA_WIDTH:VERTEX_ADDR_WIDTH];
                vertex_start_index <= header_data[VERTEX_ADDR_WIDTH:0];
                
                // Read next header for end indices
                header_addr <= model_index + 1;
            end

            READ_HEADER_1: begin
                // Load end indices from header
                face_end_index <= header_data[HEADER_DATA_WIDTH:VERTEX_ADDR_WIDTH];
                vertex_end_index <= header_data[VERTEX_ADDR_WIDTH:0];
                
                // Initialize face and vertex addresses
                face_addr <= face_start_index;
                vertex_addr <= vertex_start_index;
            end

            READY: begin
                // Handle face data
                if (next_face && !face_buffer_done) begin
                    face_data <= face_rom_data;
                    face_addr <= (face_addr == face_end_index - 1) ? face_addr : face_addr + 1;
                end

                // Handle vertex data
                if (next_vertex && !vertex_buffer_done) begin
                    vertex_data <= vertex_rom_data;
                    vertex_addr <= (vertex_addr == vertex_end_index - 1) ? vertex_addr : vertex_addr + 1;
                end
            end

            default: begin
                // Do nothing
            end
        endcase
    end
end

endmodule