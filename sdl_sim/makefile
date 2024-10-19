VFLAGS = -O3 --x-assign fast --x-initial fast --noassert
SDL_CFLAGS = `sdl2-config --cflags`
SDL_LDFLAGS = `sdl2-config --libs`

top: top.exe

%.exe: %.mk
	make -C ./obj_dir -f V$<

%.mk: %.sv
	verilator ${VFLAGS} -I.. \
		-cc $< \
		../lib/Display/projectf_display_480p.sv \
		../lib/Memory/BRAM_DP/src/bram_dp.sv \
		../lib/Memory/CLUT/src/clut.sv \
		../lib/Memory/Framebuffer/src/framebuffer.sv \
		../lib/RenderPipeline/Rasterizer/BoundingBox/src/bounding_box.sv \
		../lib/RenderPipeline/Rasterizer/src/rasterizer.sv \
		--exe main_$(basename $@).cpp -o $(basename $@) \
		--top-module top \
		-CFLAGS "${SDL_CFLAGS}" -LDFLAGS "${SDL_LDFLAGS}"

all: top

run: top
	./obj_dir/top

clean:
	rm -rf ./obj_dir

.PHONY: all clean
