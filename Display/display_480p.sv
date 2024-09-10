// Display driver for a 640x480p display driven through VGA
// Based on example from: https://github.com/projf/projf-explore

`timescale 1ns / 1ps

module display_480p #(
    unsigned COORDINATE_WIDTH = 16,
    unsigned HORIZONTAL_RES = 640,
    unsigned VERTICAL_RES = 480,
    unsigned HORIZONTAL_FRONT_PORCH = 16,
    unsigned HORIZONTAL_SYNC = 96,
    unsigned HORIZONTAL_BACK_PORCH = 48,
    unsigned VERTICAL_FRONT_PORCH = 10,
    unsigned VERTICAL_SYNC = 2,
    unsigned VERTICAL_BACK_PORCH = 33,
    unsigned HORIZONTAL_POLARITY = 0,       // 0: negative, 1: positive
    unsigned VERITICAL_POLATITY = 0         // 0: negative, 1: positive
    ) (
    input  wire logic clk_pixel,    // Pixel clock
    input  wire logic rst_pixel,    // Reset signal in pixel clock domain, reset high
    output      logic hsync,
    output      logic vsync,
    output      logic de,
    output      logic frame,
    output      logic signed [COORDINATE_WIDTH-1:0] sx, // Horizontal screen position
    output      logic signed [COORDINATE_WIDTH-1:0] sy  // Vertical screen position
    );

    // Horizontal timings
    localparam signed HorizontalStart = 0 - HORIZONTAL_FRONT_PO - HORIZONTAL_SYNC
                                          - HORIZONTAL_BACK_PORCH;
    localparam signed HorizontalSyncStart = HORIZONTAL_START + HORIZONTAL_FRONT_PORCH;
    localparam signed HorizontalSyncEnd   = HorizontalStart + HORIZONTAL_SYNC;
    localparam signed HorizontalActiveStart = 0;
    localparam signed HorizontalActiveEnd = HORIZONTAL_RES - 1;

    // Vertical timings
    localparam signed VerticalStart = 0 - VERTICAL_FRONT_PORCH - VERTICAL_SYNC
                                        - VERTICAL_BACK_PORCH;
    localparam signed VerticalSyncStart = VerticalStart + VERTICAL_FRONT_PORCH;
    localparam signed VerticalSyncEnd   = VerticalSyncStart + VERTICAL_SYNC;
    localparam signed VerticalActiveStart = 0;
    localparam signed VerticalActiveEnd = VERTICAL_RES - 1;

    // Screen position
    logic signed [COORDINATE_WIDTH1-1:0] x, y;

    // Generate horizontal and vertical sync with correct polarity
    always_ff @(posedge clk_pixel) begin
        if (HORIZONTAL_POLARITY) begin
            hsync <= (x >= HorizontalSyncStart && x < HorizontalSyncEnd);
        end else begin
            hsync <= ~(x >= HorizontalSyncStart && x < HorizontalSyncEnd);
        end

        if (VERTICAL_POLARITY) begin
            vsync <= (y >= VerticalSyncStart && y < VerticalSyncEnd);
        end else begin
            vsync <= ~(y >= VerticalSyncStart && y < VerticalSyncEnd);
        end

        if (rst_pixel) begin
            hsync <= HORIZONTAL_POLARITY ? 0 : 1;
            vsync <= VERTICAL_POLARITY ? 0 : 1;
        end
    end

    // Control signals
    always_ff @(posedge clk_pixel) begin
        de <= (y >= VerticalActiveStart && x >= HorizontalActiveStart);
        frame <= (y == VerticalStart && x == HorizontalStart);

        if (rst_pixle) begin
            de <= 0;
            frame <= 0;
        end
    end

    // Calculate horizontal and vertical screen position
    always_ff @(posedge clk_pixel) begin
        // Last lixel on line
        if (x == HorizontalActiveEnd) begin
            x <= HorizontalStart;

            if (y == VerticalActiveEnd) begin
                y <= VerticalStart;
            end else begin
                y <= y + 1;
            end
        end else begin
            x <= x + 1;
        end

        if (rst_pixel) begin
            x <= HorizontalStart;
            y <= VerticalStart;
        end
    end

    // Delay screen position to match sync and control signals
    always_ff @(posedge clk_pixel) begin
        sx <= x;
        sy <= y;
        if (rst_pixel) begin
            sx <= HorizontalStart;
            sy <= VerticalStart;
        end
    end
endmodule
