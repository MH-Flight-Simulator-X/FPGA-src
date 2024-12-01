SRC_DIR = ../src
MODULE=transform_pipeline

MAT_VEC_MUL = ../../../Math/MatVecMul/src/mat_vec_mul_new.sv
FRAC_DIV = ../../../Math/FixedPointDivide/src/fixed_point_divide.sv
BRAM_SP = ../../../Memory/BRAM_SP/src/bram_sp.sv

VERTEX_SHADER = ../../VertexShader/src/vertex_shader_new.sv
VERTEX_POST_PROCESSOR = ../../VertexPostProcessor/src/vertex_post_processor.sv
PRIMITIVE_ASSEMBLER = ../../PrimitiveAssembler/src/primitive_assembler.sv
GBUFFER = ../../../Memory/G-Buffer/src/g_buffer.sv


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

.stamp.verilate: $(SRC_DIR)/$(MODULE).sv $(MAT_VEC_MUL) $(FRAC_DIV) $(VERTEX_SHADER) $(VERTEX_POST_PROCESSOR) \
				 $(PRIMITIVE_ASSEMBLER) $(BRAM_SP) $(GBUFFER) tb_$(MODULE).cpp
	@echo
	@echo "### VERILATING ###"
	verilator -Wall --trace --x-assign unique --x-initial unique \
		-cc $(SRC_DIR)/$(MODULE).sv $(MAT_VEC_MUL) $(FRAC_DIV) $(VERTEX_SHADER) $(VERTEX_POST_PROCESSOR) \
		$(PRIMITIVE_ASSEMBLER) $(BRAM_SP) $(GBUFFER) \
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
	# rm *.vert
	# rm *.face
	# rm *.tri
