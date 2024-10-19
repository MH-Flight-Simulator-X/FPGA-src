`timescale 1ns / 1ps

typedef enum logic [2:0] {
    MCU_FPGA_COM_IDLE,
    MCU_FPGA_COM_NUM_OBJECTS,
    MCU_FPGA_COM_OBJECTS,
    MCU_FPGA_COM_OBJECT_ID,
    MCU_FPGA_COM_OBJECT_MATRIX,
    MCU_FPGA_COM_OBJECT_DONE,
    MCU_FPGA_COM_DONE
} mcu_fpga_com_state_t;

module mcu_fpga_com #(
    parameter unsigned I_MATRIX_DATAWIDTH = 24
    ) (
    input logic clk,
    input logic rstn,

    // TODO: Add mode such that we can use spi for both reading frame data
    // and writing model data through to external PSRAM
    /* verilator lint_off UNUSED */
    input logic i_mode,
    /* verilator lint_on UNUSED */
    input logic i_new_frame,
    output logic o_mcu_ready,

    output logic [7:0] o_num_objects,
    output logic o_num_objects_dv,

    output logic [3:0] o_object_id,
    output logic [3:0] o_object_flags,
    output logic [I_MATRIX_DATAWIDTH-1:0] o_object_matrix[4][4],
    output logic o_object_dv,

    input logic SCK,
    input logic MOSI,
    output logic MISO,
    input logic CSn
    );

    localparam int unsigned MATRIX_NUM_VALUES = 16;

    // Register data
    logic [7:0] r_num_objects;

    // Counters
    logic [3:0] r_object_cnt = '0;
    logic [$clog2(MATRIX_NUM_VALUES)-1:0] r_matrix_data_counter = '0;
    logic [$clog2(I_MATRIX_DATAWIDTH)-1:0] r_matrix_data_byte_counter = '0;

    // SPI Slave
    logic [7:0] w_RX_Byte;
    logic w_RX_DV;

    spi_slave spi_slave_inst (
        .clk(clk),
        .rstn(rstn),

        .o_RX_Byte(w_RX_Byte),
        .o_RX_DV(w_RX_DV),

        .SCK(SCK),
        .MISO(MISO),
        .MOSI(MOSI),
        .CSn(CSn)
    );

    // State
    mcu_fpga_com_state_t current_state = MCU_FPGA_COM_IDLE, next_state = MCU_FPGA_COM_IDLE;
    always_ff @(posedge clk) begin
        if (~rstn) begin
            current_state <= MCU_FPGA_COM_IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    always_comb begin
        next_state = current_state;

        case (current_state)
            MCU_FPGA_COM_IDLE: begin
                // Todo: CSn probably should not be input directly into state
                if (~CSn) begin
                    next_state = MCU_FPGA_COM_NUM_OBJECTS;
                end
            end

            MCU_FPGA_COM_NUM_OBJECTS: begin
                if (w_RX_DV) begin
                    next_state = MCU_FPGA_COM_OBJECTS;
                end
            end

            MCU_FPGA_COM_OBJECTS: begin
                if (r_object_cnt == r_num_objects - 1) begin
                    next_state = MCU_FPGA_COM_DONE;
                end else begin
                    next_state = MCU_FPGA_COM_OBJECT_ID;
                end
            end

            MCU_FPGA_COM_OBJECT_ID: begin
                if (w_RX_DV) begin
                    next_state = MCU_FPGA_COM_OBJECT_MATRIX;
                end
            end

            MCU_FPGA_COM_OBJECT_MATRIX: begin
                if (r_matrix_data_counter == MATRIX_NUM_VALUES - 1) begin
                    next_state = MCU_FPGA_COM_OBJECT_DONE;
                end
            end

            MCU_FPGA_COM_OBJECT_DONE: begin
                next_state = MCU_FPGA_COM_OBJECTS;
            end

            MCU_FPGA_COM_DONE: begin
                next_state = MCU_FPGA_COM_IDLE;
            end

            default: begin
                next_state = MCU_FPGA_COM_IDLE;
            end
        endcase
    end

    // Register results
    always_ff @(posedge clk) begin
        if (~rstn) begin
            r_num_objects <= '0;
            r_object_cnt <= '0;
            r_matrix_data_counter <= '0;
            r_matrix_data_byte_counter <= '0;

            o_num_objects <= '0;
            o_num_objects_dv <= '0;

            foreach (o_object_matrix[i,j]) o_object_matrix[i][j] <= '0;
            o_object_id <= '0;
            o_object_flags <= '0;
            o_object_dv <= 0;
        end else begin
            case (current_state)
                MCU_FPGA_COM_NUM_OBJECTS: begin
                    if (w_RX_DV) begin
                        r_num_objects <= w_RX_Byte;
                    end
                end

                MCU_FPGA_COM_OBJECT_ID: begin
                    if (w_RX_DV) begin
                        if (r_object_
                    end
                end

                default: begin
                    o_object_dv <= 0;
                end
            endcase
        end
    end

    assign o_mcu_ready = i_new_frame && (current_state == MCU_FPGA_COM_IDLE);

endmodule
