SRC_DIR = ../src
MODULE = rasterizer

VERTEX_WIDTH = 32
FB_ADDR_WIDTH = 4
FB_WIDTH = 32
FB_HEIGHT = 16

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

.stamp.verilate: $(SRC_DIR)/$(MODULE).sv tb_$(MODULE).cpp
	@echo
	@echo "### VERILATING ###"
	verilator -Wall --trace --x-assign unique --x-initial unique \
	-cc $(SRC_DIR)/$(MODULE).sv --exe tb_$(MODULE).cpp \
	-GVERTEX_WIDTH=$(VERTEX_WIDTH) -GFB_ADDR_WIDTH=$(FB_ADDR_WIDTH) -GFB_WIDTH=$(FB_WIDTH) -GFB_HEIGHT=$(FB_HEIGHT)
	@touch .stamp.verilate

.PHONY:lint
lint: $(MODULE).sv
	verilator --lint-only $(MODULE).sv

.PHONY: clean
clean:
	rm -rf .stamp.*;
	rm -rf ./obj_dir
	rm -rf waveform.vcd
