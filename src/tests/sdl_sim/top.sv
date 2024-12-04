`timescale 1ns / 1ps

/* verilator lint_off UNUSED */
module top #(
    parameter unsigned DATAWIDTH = 12,
    parameter unsigned SCREEN_WIDTH = 160,
    parameter unsigned SCREEN_HEIGHT = 120,
    parameter unsigned DISPLAY_CORD_WIDTH = 16
    ) (
    input  logic clk_100m,            // 100MHz clock
    input  logic clk_pix,             // pixel clock
    input  logic sim_rst,

    input  logic render,

    output logic [DISPLAY_CORD_WIDTH-1:0] sdl_sx,  // horizontal SDL position
    output logic [DISPLAY_CORD_WIDTH-1:0] sdl_sy,  // vertical SDL position
    output logic sdl_de,              // data enable (low in blanking interval)
    output logic [7:0] sdl_r,         // 8-bit red
    output logic [7:0] sdl_g,         // 8-bit green
    output logic [7:0] sdl_b,         // 8-bit blue
    output logic frame,
    output logic done
    );

    // color parameters
    localparam unsigned COLOR_LOOKUP_WIDTH = 4;
    localparam unsigned CHANNEL_WIDTH = 4;
    localparam unsigned COLOR_WIDTH = 3*CHANNEL_WIDTH;
    localparam unsigned ADDR_WIDTH = $clog2(SCREEN_WIDTH * SCREEN_HEIGHT);

    // framebuffer (FB)
    localparam unsigned FB_DATA_WIDTH  = 4;
    localparam unsigned FB_DEPTH = SCREEN_WIDTH * SCREEN_HEIGHT;
    localparam unsigned FB_ADDR_WIDTH  = $clog2(FB_DEPTH);
    localparam string FB_IMAGE_FILE  = "../../image.mem";

    // pixel read address and color
    logic [FB_ADDR_WIDTH-1:0] i_pixel_write_addr;
    logic fb_write_enable;

    localparam signed AX0 = 30;
    localparam signed AY0 = 30;
    localparam unsigned AZ0 = 12'b110000000000; // 0.5

    localparam signed AX1 = 140;
    localparam signed AY1 = 100;
    localparam unsigned AZ1 = 12'b010000000000; // 0.5

    localparam signed AX2 = 160;
    localparam signed AY2 = 0;
    localparam signed AZ2 = 12'b010000000000; // 0.5

    localparam signed BX0 = 30;
    localparam signed BY0 = 30;
    localparam unsigned BZ0 = 12'b000000000001; // 0.25

    localparam signed BX1 = 30;
    localparam signed BY1 = 120;
    localparam unsigned BZ1 = 12'b000000000001; // 0.25

    localparam signed BX2 = 140;
    localparam signed BY2 = 50;
    localparam unsigned BZ2 = 12'b000000000001; // 0.25

    logic signed [DATAWIDTH-1:0] v0[3];
    logic signed [DATAWIDTH-1:0] v1[3];
    logic signed [DATAWIDTH-1:0] v2[3];

    logic current_triangle = '0;
    logic r_triangle_dv = 1'b0;
    logic w_rasterizer_ready;
    logic w_new_frame_render_ready;
    logic w_frame_swapped;

    always_comb begin
        if (current_triangle) begin
            v0[0] = AX0; v0[1] = AY0; v0[2] = AZ0;
            v1[0] = AX1; v1[1] = AY1; v1[2] = AZ1;
            v2[0] = AX2; v2[1] = AY2; v2[2] = AZ2;
            w_color_data = 0;
        end
        else begin
            v0[0] = BX0; v0[1] = BY0; v0[2] = BZ0;
            v1[0] = BX1; v1[1] = BY1; v1[2] = BZ1;
            v2[0] = BX2; v2[1] = BY2; v2[2] = BZ2;
            w_color_data = 1;
        end
    end

    logic unsigned [DATAWIDTH-1:0] w_depth_data;
    logic unsigned [COLOR_LOOKUP_WIDTH-1:0] w_color_data;

    rasterizer #(
        .DATAWIDTH(DATAWIDTH),
        .COLORWIDTH(COLOR_LOOKUP_WIDTH),
        .SCREEN_WIDTH(SCREEN_WIDTH),
        .SCREEN_HEIGHT(SCREEN_HEIGHT),
        .ADDRWIDTH(ADDR_WIDTH)
    ) rasterizer_inst (
        .clk(clk_100m),
        .rstn(~sim_rst),

        .ready(w_rasterizer_ready),

        .i_v0(v0),
        .i_v1(v1),
        .i_v2(v2),
        .i_triangle_dv(r_triangle_dv),
        .i_triangle_last(1), // current_triangle == 2'b10

        .o_fb_addr_write(i_pixel_write_addr),
        .o_fb_write_en(fb_write_enable),
        .o_fb_depth_data(w_depth_data),
        // .o_fb_color_data(w_color_data),
        .o_fb_color_data(),

        .finished(done)
    );

    typedef enum logic [2:0] {
        IDLE,
        CLEAR,
        CLEAR_WAIT_DONE,
        RENDER_FIRST,
        RENDER_FIRST_WAIT,
        // RENDER_SECOND,
        // RENDER_SECOND_WAIT,
        RENDER_DONE
    } state_t;
    state_t current_state, next_state;
    state_t last_state;

    always_ff @(posedge clk_100m) begin
        if (sim_rst) begin
            last_state <= IDLE;
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
            last_state <= current_state;

            if (current_state == IDLE && current_state != last_state) begin
                $display("\n\n");

                $display("Current triangle: %d", current_triangle);
            end
            if (current_state != last_state) begin
                $display("Current state: %s", current_state.name());
            end
        end
    end

    always_comb begin
        next_state = current_state;

        case (current_state)
            IDLE: begin
                if (render && w_rasterizer_ready) begin
                    next_state = CLEAR;
                end
            end

            CLEAR: begin
                next_state = CLEAR_WAIT_DONE;
            end

            CLEAR_WAIT_DONE: begin
                if (w_new_frame_render_ready && w_rasterizer_ready) begin
                    next_state = RENDER_FIRST;
                end
            end

            RENDER_FIRST: begin
                next_state = RENDER_FIRST_WAIT;
            end

            RENDER_FIRST_WAIT: begin
                if (done) begin
                    next_state = RENDER_DONE;
                end
            end

            // RENDER_SECOND: begin
            //     next_state = RENDER_SECOND_WAIT;
            // end
            //
            // RENDER_SECOND_WAIT: begin
            //     if (done) begin
            //         next_state = RENDER_DONE;
            //     end
            // end

            RENDER_DONE: begin
                if (w_frame_swapped) begin
                    next_state = IDLE;
                end
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

    always_ff @(posedge clk_100m) begin
        if (sim_rst) begin
            r_triangle_dv <= 1'b0;
            current_triangle <= '0;
            clear <= 1'b0;
        end else begin
            case (current_state)
                IDLE: begin
                    r_triangle_dv <= 1'b0;
                    current_triangle <= ~current_triangle;
                    clear <= 1'b0;
                end

                CLEAR: begin
                    clear <= 1'b1;
                end

                CLEAR_WAIT_DONE: begin
                    clear <= 1'b0;
                end

                RENDER_FIRST: begin
                    r_triangle_dv <= 1'b1;
                end

                RENDER_FIRST_WAIT: begin
                    r_triangle_dv <= 1'b0;
                end

                // RENDER_SECOND: begin
                //     r_triangle_dv <= 1'b1;
                //     current_triangle <= 2'b10;
                // end
                //
                // RENDER_SECOND_WAIT: begin
                //     r_triangle_dv <= 1'b0;
                // end

                RENDER_DONE: begin
                    r_triangle_dv <= 1'b0;
                end

                default: begin
                    r_triangle_dv <= 1'b0;
                end
            endcase
        end
    end

    localparam CLUT_WIDTH = 12;
    localparam CLUT_DEPTH = 16;
    localparam FB_CLEAR_VALUE = 10;
    localparam PALETTE_FILE = "../../palette.mem";

    logic [CHANNEL_WIDTH-1:0] red, green, blue;

    logic hsync;
    logic vsync;
    logic clear;
    display_new #(
        .FB_CLEAR_VALUE(10),
        .PALETTE_FILE(PALETTE_FILE),
        .FB_IMAGE_FILE(FB_IMAGE_FILE)
    ) display_inst (
        .clk(clk_100m),
        .clk_pixel(clk_pix),
        .rstn(~sim_rst),

        .frame_render_done(done),
        .frame_clear(clear),
        .new_frame_render_ready(w_new_frame_render_ready),
        .frame_swapped(w_frame_swapped),

        .i_pixel_write_addr(i_pixel_write_addr),
        .i_pixel_write_valid(fb_write_enable),
        .i_fb_data(w_color_data),
        .i_db_data(w_depth_data),

        .o_red(red),
        .o_green(green),
        .o_blue(blue),

        .hsync(hsync),
        .vsync(vsync)
    );

    assign sdl_sx = display_inst.screen_x;
    assign sdl_sy = display_inst.screen_y;
    assign sdl_de = display_inst.de;
    assign frame = display_inst.frame;

    // SDL output (8 bits per colour channel)
    always_ff @(posedge clk_pix) begin
        sdl_r <= {2{red}};  // double signal width from 4 to 8 bits
        sdl_g <= {2{green}};
        sdl_b <= {2{blue}};
    end
endmodule
