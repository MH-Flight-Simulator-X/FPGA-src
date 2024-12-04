# Makefile for Verilator and SDL Simulation

# Verilator options
VFLAGS = -O3 --x-assign fast --x-initial fast --assert

# SDL flags
SDL_CFLAGS = $(shell sdl2-config --cflags)
SDL_LDFLAGS = $(shell sdl2-config --libs)

# Design and output file names
TOP_MODULE = top_MH_FPGA
EXEC = top_MH_FPGA

# Directories
SRC_DIR = ../src
LIB_DIR = ../lib
OBJ_DIR = obj_dir

VERILOG_SOURCES = \
	$(LIB_DIR)/Math/MatVecMul/src/mat_vec_mul_new.sv \
	$(LIB_DIR)/Math/FastInverse/src/fast_inverse.sv \
	$(LIB_DIR)/Math/FixedPointDivide/src/fixed_point_divide.sv \
	$(LIB_DIR)/Memory/BRAM_SP/src/bram_sp.sv \
    $(LIB_DIR)/Memory/BRAM_DP/src/bram_dp.sv \
	$(LIB_DIR)/Memory/Buffer/src/buffer.sv \
	$(LIB_DIR)/Memory/G-Buffer/src/g_buffer.sv \
	$(LIB_DIR)/Memory/ROM/src/rom.sv \
	$(LIB_DIR)/Memory/ModelReader/src/model_reader.sv \
	$(LIB_DIR)/Display/DisplaySignals/projectf_display_480p.sv \
	$(LIB_DIR)/Display/display_new.sv \
	$(LIB_DIR)/RenderPipeline/VertexShader/src/vertex_shader_new.sv \
	$(LIB_DIR)/RenderPipeline/VertexPostProcessor/src/vertex_post_processor.sv \
	$(LIB_DIR)/RenderPipeline/PrimitiveAssembler/src/primitive_assembler.sv \
	$(LIB_DIR)/RenderPipeline/TransformPipeline/src/transform_pipeline.sv \
	$(LIB_DIR)/RenderPipeline/Rasterizer/BoundingBox/src/bounding_box.sv \
	$(LIB_DIR)/RenderPipeline/Rasterizer/Frontend/src/rasterizer_frontend.sv \
	$(LIB_DIR)/RenderPipeline/Rasterizer/Backend/src/rasterizer_backend.sv \
	$(LIB_DIR)/RenderPipeline/Rasterizer/src/rasterizer.sv \
	$(LIB_DIR)/RenderPipeline/src/render_pipeline.sv

# Verilog file (Top module)
VERILOG_FILE = $(SRC_DIR)/top_MH_FPGA.sv

# C++ source file (Main simulation driver)
CPP_FILE = tb_top_MH_FPGA.cpp

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


