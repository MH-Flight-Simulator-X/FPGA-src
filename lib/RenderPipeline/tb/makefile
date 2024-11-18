# Makefile for Verilator and SDL Simulation

# Verilator options
VFLAGS = -O3 --x-assign fast --x-initial fast --noassert

# SDL flags
SDL_CFLAGS = $(shell sdl2-config --cflags)
SDL_LDFLAGS = $(shell sdl2-config --libs)

# Design and output file names
TOP_MODULE = render_pipeline
EXEC = render_pipeline

# Directories
SRC_DIR = ../src
OBJ_DIR = obj_dir

VERILOG_SOURCES = \
	../../Math/MatVecMul/src/mat_vec_mul.sv \
	../VertexShader/src/vertex_shader.sv \
	../../Math/FixedPointDivide/src/fixed_point_divide.sv \
	../VertexPostProcessor/src/vertex_post_processor.sv \
	../../Memory/BRAM_SP/src/bram_sp.sv \
	../../Memory/G-Buffer/src/g_buffer.sv \
	../PrimitiveAssembler/src/primitive_assembler.sv \
	../TransformPipeline/src/transform_pipeline.sv \
	../Rasterizer/BoundingBox/src/bounding_box.sv \
	../../Math/FastInverse/src/fast_inverse.sv \
	../Rasterizer/Frontend/src/rasterizer_frontend.sv \
	../Rasterizer/Backend/src/rasterizer_backend.sv \
	../Rasterizer/src/rasterizer.sv

# Verilog file (Top module)
VERILOG_FILE = $(SRC_DIR)/render_pipeline.sv

# C++ source file (Main simulation driver)
CPP_FILE = tb_render_pipeline.cpp

# Make target: all
all: $(EXEC)

# Rule to build the final executable
$(EXEC): $(OBJ_DIR)/V$(TOP_MODULE).mk
	make -C $(OBJ_DIR) -f V$(TOP_MODULE).mk

# Rule to generate the object files and Verilator C++ model
$(OBJ_DIR)/V$(TOP_MODULE).mk: $(VERILOG_FILE) $(VERILOG_SOURCES) $(CPP_FILE)
	verilator $(VFLAGS) -I$(SRC_DIR) -cc $(VERILOG_FILE) $(VERILOG_SOURCES) --exe $(CPP_FILE) -o $(EXEC) \
		-CFLAGS "$(SDL_CFLAGS)" -LDFLAGS "$(SDL_LDFLAGS)"

# Rule for cleaning up build files
clean:
	rm -rf $(OBJ_DIR)

run: $(EXEC)
	./obj_dir/$(EXEC)

.PHONY: all clean

