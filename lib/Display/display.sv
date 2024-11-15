`timescale 1ns / 1ps

module display#(
    parameter unsigned DISPLAY_WIDTH = 160,
    parameter unsigned DISPLAY_HEIGHT = 120,
    parameter unsigned COORDINATE_WIDTH = 16,
    parameter unsigned FB_DATA_WIDTH = 4,
    parameter unsigned DB_DATA_WIDTH = 12,
    parameter unsigned CHANNEL_WIDTH = 4,
    parameter unsigned COLOR_WIDTH = CHANNEL_WIDTH*3,
    parameter unsigned BG_COLOR = 'h137
    ) (
    // input logic clk_pix,

    input logic signed [COORDINATE_WIDTH-1:0] screen_x,
    input logic signed [COORDINATE_WIDTH-1:0] screen_y,

    input logic signed [COLOR_WIDTH-1:0] fb_pix_colr,
    input logic signed [DB_DATA_WIDTH-1:0] db_value,

    output logic signed [CHANNEL_WIDTH-1:0] o_red,
    output logic signed [CHANNEL_WIDTH-1:0] o_green,
    output logic signed [CHANNEL_WIDTH-1:0] o_blue
    );

    // paint screen
    logic paint_db;
    logic paint_fb;
    always_comb begin
        paint_fb = (screen_y >= 0 && screen_y < DISPLAY_HEIGHT && screen_x >= 0 && screen_x < DISPLAY_WIDTH);
        paint_db = (screen_y >= 0 && screen_y < DISPLAY_HEIGHT && screen_x >= DISPLAY_WIDTH && screen_x < DISPLAY_WIDTH*2);
        if (paint_fb) begin
            {o_red, o_green, o_blue} = fb_pix_colr;
        end
        else if (paint_db) begin
            {o_red, o_green, o_blue} = {db_value[11:8], 8'b00000000};
        end
        else begin
            {o_red, o_green, o_blue} = BG_COLOR;
        end
    end 

endmodule
