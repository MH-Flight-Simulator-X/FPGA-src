SRC_DIR = ../src
MODULE=render_pipeline

MAT_VEC_MUL = ../../Math/MatVecMul/src/mat_vec_mul.sv
VERTEX_SHADER = ../VertexShader/src/vertex_shader.sv

FIXED_POINT_DIVIDE = ../../Math/FixedPointDivide/src/fixed_point_divide.sv
VERTEX_POST_PROCESSOR = ../VertexPostProcessor/src/vertex_post_processor.sv

BRAM_SP = ../../Memory/BRAM_SP/src/bram_sp.sv
GBUFFER = ../../Memory/G-Buffer/src/g_buffer.sv

PRIMITIVE_ASSEMBLER = ../PrimitiveAssembler/src/primitive_assembler.sv

TRANSFORM_PIPELINE = ../TransformPipeline/src/transform_pipeline.sv

BBOX_FILE = ../Rasterizer/BoundingBox/src/bounding_box.sv
FAST_INVERSE = ../../Math/FastInverse/src/fast_inverse.sv
RASTERIZER_FRONTEND = ../Rasterizer/FrontEnd/src/rasterizer_frontend.sv

INCLUDES = $(MAT_VEC_MUL) $(VERTEX_SHADER) $(FIXED_POINT_DIVIDE) \
		   $(VERTEX_POST_PROCESSOR) $(BRAM_SP) $(GBUFFER) \
		   $(PRIMITIVE_ASSEMBLER) $(TRANSFORM_PIPELINE) \
		   $(BBOX_FILE) $(FAST_INVERSE) $(RASTERIZER_FRONTEND)

.PHONY:sim
sim: waveform.vcd

.PHONY:verilate
verilate: .stamp.verilate

.PHONY:build
build: obj_dir/V$(MODULE)

.PHONY:waves
waves: waveform.vcd
	@echo
	@echo "### WAVES ###"
	gtkwave waveform.vcd

waveform.vcd: ./obj_dir/V$(MODULE)
	@echo
	@echo "### SIMULATING ###"
	@./obj_dir/V$(MODULE) +verilator+rand+reset+2

./obj_dir/V$(MODULE): .stamp.verilate
	@echo
	@echo "### BUILDING SIM ###"
	make -C obj_dir -f V$(MODULE).mk V$(MODULE)

.stamp.verilate: $(SRC_DIR)/$(MODULE).sv $(INCLUDES) tb_$(MODULE).cpp
	@echo
	@echo "### VERILATING ###"
	verilator -Wall --trace --x-assign unique --x-initial unique \
		-cc $(SRC_DIR)/$(MODULE).sv $(INCLUDES) \
		--exe tb_$(MODULE).cpp
	@touch .stamp.verilate

.PHONY:lint
lint: $(MODULE).sv
	verilator --lint-only $(MODULE).sv

.PHONY: clean
clean:
	rm -rf .stamp.*;
	rm -rf ./obj_dir
	rm -rf waveform.vcd

