SRC_DIR = .
MODULE=tb_transform_pipeline

FIXED_POINT_DIVIDE = ../../../lib/Math/FixedPointDivide/src/fixed_point_divide.sv
MAT_VEC_MUL = ../../../lib/Math/MatVecMul/src/mat_vec_mul.sv
VERTEX_SHADER = ../../../lib/RenderPipeline/VertexShader/src/vertex_shader.sv

VERTEX_POST_PROCESSOR = ../../../lib/RenderPipeline/VertexPostProcessor/src/vertex_post_processor.sv

BRAM_SP = ../../../lib/Memory/BRAM_SP/src/bram_sp.sv
GBUFFER = ../../../lib/Memory/G-Buffer/src/g_buffer.sv

BBOX = ../../../lib/RenderPipeline/Rasterizer/BoundingBox/src/bounding_box.sv
PRIMITIVE_ASSEMBLER = ../../../lib/RenderPipeline/PrimitiveAssembler/src/primitive_assembler.sv

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

.stamp.verilate: $(SRC_DIR)/$(MODULE).sv $(FIXED_POINT_DIVIDE) \
				 $(MAT_VEC_MUL) $(VERTEX_SHADER) $(VERTEX_POST_PROCESSOR) \
				 $(BRAM_SP) $(GBUFFER) $(BBOX) $(PRIMITIVE_ASSEMBLER) $(MODULE).cpp
	@echo
	@echo "### VERILATING ###"
	verilator -Wall --trace --x-assign unique --x-initial unique \
		-cc $(SRC_DIR)/$(MODULE).sv \
			$(FIXED_POINT_DIVIDE) $(MAT_VEC_MUL) $(VERTEX_SHADER) $(VERTEX_POST_PROCESSOR) \
			$(BRAM_SP) $(GBUFFER) $(BBOX) $(PRIMITIVE_ASSEMBLER) \
		--exe $(MODULE).cpp
	@touch .stamp.verilate

.PHONY:lint
lint: $(MODULE).sv
	verilator --lint-only $(MODULE).sv

.PHONY: clean
clean:
	rm -rf .stamp.*;
	rm -rf ./obj_dir
	rm -rf waveform.vcd
