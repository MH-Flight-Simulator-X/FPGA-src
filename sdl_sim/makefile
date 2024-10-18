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
		--exe main_$(basename $@).cpp -o $(basename $@) \
		--top-module top \
		-CFLAGS "${SDL_CFLAGS}" -LDFLAGS "${SDL_LDFLAGS}"

all: top

clean:
	rm -rf ./obj_dir

.PHONY: all clean
