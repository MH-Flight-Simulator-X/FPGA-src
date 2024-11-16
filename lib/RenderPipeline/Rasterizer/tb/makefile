SRC_DIR = ../src
BOUNDING_BOX = ../BoundingBox/src/bounding_box.sv
FAST_INVERSE = ../../../Math/FastInverse/src/fast_inverse.sv
RASTERIZER_FRONTEND = ../Frontend/src/rasterizer_frontend.sv
RASTERIZER_BACKEND = ../Backend/src/rasterizer_backend.sv
MODULE = rasterizer

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

.stamp.verilate: $(SRC_DIR)/$(MODULE).sv $(BOUNDING_BOX) $(FAST_INVERSE) \
				 $(RASTERIZER_FRONTEND) $(RASTERIZER_BACKEND) tb_$(MODULE).cpp
	@echo
	@echo "### VERILATING ###"
	verilator -Wall --trace --x-assign unique --x-initial unique \
			  -cc $(SRC_DIR)/$(MODULE).sv $(BOUNDING_BOX) $(FAST_INVERSE) \
				  $(RASTERIZER_FRONTEND) $(RASTERIZER_BACKEND) \
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
