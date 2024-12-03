VFLAGS = -O3 --x-assign fast --x-initial fast --noassert
SDL_CFLAGS = `sdl2-config --cflags`
SDL_LDFLAGS = `sdl2-config --libs`

LIB_PATH = ../../../lib

VERILOG_SOURCES = \
    $(LIB_PATH)/Display/display_new.sv \
    $(LIB_PATH)/Display/DisplaySignals/projectf_display_480p.sv \
    $(LIB_PATH)/Memory/BRAM_DP/src/bram_dp.sv \
    $(LIB_PATH)/Memory/ROM/src/rom.sv \
    $(LIB_PATH)/Memory/Buffer/src/buffer.sv \
    $(LIB_PATH)/RenderPipeline/Rasterizer/BoundingBox/src/bounding_box.sv \
    $(LIB_PATH)/Math/FastInverse/src/fast_inverse.sv \
    $(LIB_PATH)/RenderPipeline/Rasterizer/Frontend/src/rasterizer_frontend.sv \
    $(LIB_PATH)/RenderPipeline/Rasterizer/Backend/src/rasterizer_backend.sv \
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
