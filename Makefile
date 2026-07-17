VERILATOR_BIN ?= C:/msys64/usr/bin/perl C:/msys64/ucrt64/bin/verilator
VERILATOR_FLAGS ?= --language 1800-2017 -Wall -Wno-fatal
export PATH := C:/msys64/ucrt64/bin:$(PATH)

TOP_MODULE ?= apb_trng_wrapper
TB_TOP ?= apb_trng_tb
UVM_TOP ?= apb_trng_tb_top
UVM_TEST ?= apb_trng_all_test
MODELSIM_HOME ?= C:/intelFPGA/18.1/modelsim_ase
MODELSIM_BIN ?= $(MODELSIM_HOME)/win32aloem
UVM_SRC ?= C:/intelFPGA/18.1/modelsim_ase/verilog_src/uvm-1.2/src
UVM_DEFINES ?= +define+UVM_NO_DPI+UVM_NO_RELNOTES
VLIB ?= $(MODELSIM_BIN)/vlib.exe
VLOG ?= $(MODELSIM_BIN)/vlog.exe
VSIM ?= $(MODELSIM_BIN)/vsim.exe
VSIM_FLAGS ?= -suppress 19 -suppress 8315
UVM_LOG ?= sim/uvm_run.log

.PHONY: all lint lint-gf180 sim sim-sha uvm-compile uvm-run run coverage clean

all: lint lint-gf180 sim sim-sha uvm-run

lint:
	$(VERILATOR_BIN) $(VERILATOR_FLAGS) --lint-only -f filelist.f --top-module $(TOP_MODULE)

lint-gf180:
	$(VERILATOR_BIN) $(VERILATOR_FLAGS) +define+GF180MCU_SC --lint-only \
		-Wno-UNOPTFLAT -f filelist_gf180.f --top-module $(TOP_MODULE)

sim:
	@test -d work || $(VLIB) work
	$(VLOG) -sv -work work -f filelist_tb.f
	$(VSIM) -c -suppress 19 -suppress 8315 $(TB_TOP) -do "run -all; quit -f"

sim-sha:
	@test -d work || $(VLIB) work
	$(VLOG) -sv -work work -f filelist_sha_tb.f
	$(VSIM) -c -suppress 19 -suppress 8315 apb_trng_sha256_adapter_tb -do "run -all; quit -f"

uvm-compile:
	@test -f $(UVM_SRC)/uvm_pkg.sv || { echo "ERROR: missing $(UVM_SRC)/uvm_pkg.sv. Set UVM_SRC."; exit 127; }
	@test -d work || $(VLIB) work
	$(VLOG) -sv $(UVM_DEFINES) +incdir+$(UVM_SRC) -work work $(UVM_SRC)/uvm_pkg.sv
	$(VLOG) -sv $(UVM_DEFINES) +acc +incdir+$(UVM_SRC) -work work -f filelist_uvm.f

uvm-run: uvm-compile
	@mkdir -p sim
	$(VSIM) -c $(VSIM_FLAGS) $(UVM_TOP) +UVM_TESTNAME=$(UVM_TEST) +UVM_NO_RELNOTES -l $(UVM_LOG) -do "run -all; quit -f"
	@grep -q 'UVM_ERROR :    0' $(UVM_LOG) || { echo "UVM run failed: see $(UVM_LOG)"; exit 1; }
	@grep -q 'UVM_FATAL :    0' $(UVM_LOG) || { echo "UVM run failed: see $(UVM_LOG)"; exit 1; }

run: uvm-run

coverage:
	@test -f $(UVM_SRC)/uvm_pkg.sv || { echo "ERROR: missing $(UVM_SRC)/uvm_pkg.sv. Set UVM_SRC."; exit 127; }
	@mkdir -p sim
	@test -d work || $(VLIB) work
	$(VLOG) -sv $(UVM_DEFINES) +incdir+$(UVM_SRC) -work work $(UVM_SRC)/uvm_pkg.sv
	$(VLOG) -sv $(UVM_DEFINES) +acc +cover +incdir+$(UVM_SRC) -work work -f filelist_uvm.f
	$(VSIM) -c $(VSIM_FLAGS) -coverage $(UVM_TOP) +UVM_TESTNAME=$(UVM_TEST) +UVM_NO_RELNOTES -l $(UVM_LOG) -do "coverage save -onexit sim/coverage.ucdb; run -all; quit -f"
	@grep -q 'UVM_ERROR :    0' $(UVM_LOG) || { echo "UVM coverage run failed: see $(UVM_LOG)"; exit 1; }
	@grep -q 'UVM_FATAL :    0' $(UVM_LOG) || { echo "UVM coverage run failed: see $(UVM_LOG)"; exit 1; }

clean:
	rm -rf obj_dir work sim reports
	rm -f *.log *.vcd *.fst *.ucdb transcript vsim.wlf modelsim.ini
