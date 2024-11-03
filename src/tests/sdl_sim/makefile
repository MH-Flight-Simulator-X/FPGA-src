VFLAGS = -O3 --x-assign fast --x-initial fast --noassert
SDL_CFLAGS = `sdl2-config --cflags`
SDL_LDFLAGS = `sdl2-config --libs`

LIB_PATH = ../../../lib

VERILOG_SOURCES = \
    $(LIB_PATH)/Display/projectf_display_480p.sv \
    $(LIB_PATH)/Memory/BRAM_DP/src/bram_dp.sv \
    $(LIB_PATH)/Memory/ROM/src/rom.sv \
    $(LIB_PATH)/Memory/Framebuffer/src/framebuffer.sv \
    $(LIB_PATH)/RenderPipeline/Rasterizer/BoundingBox/src/bounding_box.sv \
    $(LIB_PATH)/RenderPipeline/Rasterizer/src/rasterizer.sv

top: top.exe

%.exe: %.mk
	make -C ./obj_dir -f V$<

%.mk: %.sv
	verilator ${VFLAGS} -I.. \
		-cc $< \
		$(VERILOG_SOURCES) \
		--exe main_$(basename $@).cpp -o $(basename $@) \
		--top-module top \
		-CFLAGS "${SDL_CFLAGS}" -LDFLAGS "${SDL_LDFLAGS}"

all: top

run: top
	./obj_dir/top

clean:
	rm -rf ./obj_dir

.PHONY: all clean
