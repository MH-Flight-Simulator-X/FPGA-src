SRC_DIR = ../src
BRAM_FILE = ../../BRAM_DP/src/bram_dp.sv
MODULE = framebuffer

FB_WIDTH = 8
FB_HEIGHT = 4
DATA_WIDTH = 4

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

.stamp.verilate: $(SRC_DIR)/$(MODULE).sv $(BRAM_FILE) tb_$(MODULE).cpp
	@echo
	@echo "### VERILATING ###"
	verilator -Wall --trace --x-assign unique --x-initial unique \
	-cc $(SRC_DIR)/$(MODULE).sv $(BRAM_FILE) --exe tb_$(MODULE).cpp \
	-GFB_WIDTH=$(FB_WIDTH) -GFB_HEIGHT=$(FB_HEIGHT) -GDATA_WIDTH=$(DATA_WIDTH)
	@touch .stamp.verilate

.PHONY:lint
lint: $(MODULE).sv
	verilator --lint-only $(MODULE).sv

.PHONY: clean
clean:
	rm -rf .stamp.*;
	rm -rf ./obj_dir
	rm -rf waveform.vcd
