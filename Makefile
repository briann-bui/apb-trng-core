VCS ?= vcs
SPYGLASS ?= spyglass

TOP_MODULE ?= apb_trng_wrapper
RTL_FILELIST ?= filelist.f
GF180_FILELIST ?= filelist_gf180.f

REPORT_DIR ?= reports
VCS_DIR := $(REPORT_DIR)/vcs
SPYGLASS_DIR := $(REPORT_DIR)/spyglass

LINT_PRJ ?= lint/lint.prj
CDC_PRJ ?= cdc/cdc.prj
RDC_PRJ ?= rdc/rdc.prj

VCS_FLAGS ?= -full64 -sverilog -nc -timescale=1ns/1ps +lint=all,noVCDE

.PHONY: all check compile compile-gf180 lint cdc rdc clean

all: check

check: compile lint cdc rdc

compile:
	@mkdir -p $(VCS_DIR)/compile/csrc
	$(VCS) $(VCS_FLAGS) -f $(RTL_FILELIST) -top $(TOP_MODULE) \
		-Mdir=$(VCS_DIR)/compile/csrc \
		-o $(VCS_DIR)/compile/simv \
		-l $(REPORT_DIR)/compile.log
	@{ \
		echo "APB TRNG VCS compile summary"; \
		echo "Status: PASS"; \
		echo "Top: $(TOP_MODULE)"; \
		echo "File list: $(RTL_FILELIST)"; \
		echo "Full log: $(REPORT_DIR)/compile.log"; \
	} > $(REPORT_DIR)/compile_summary.rpt

compile-gf180:
	@mkdir -p $(VCS_DIR)/gf180/csrc
	$(VCS) $(VCS_FLAGS) +define+GF180MCU_SC -f $(GF180_FILELIST) -f $(RTL_FILELIST) \
		-top $(TOP_MODULE) \
		-Mdir=$(VCS_DIR)/gf180/csrc \
		-o $(VCS_DIR)/gf180/simv \
		-l $(REPORT_DIR)/compile_gf180.log
	@{ \
		echo "APB TRNG GF180 VCS compile summary"; \
		echo "Status: PASS"; \
		echo "Top: $(TOP_MODULE)"; \
		echo "File list: $(GF180_FILELIST)"; \
		echo "Full log: $(REPORT_DIR)/compile_gf180.log"; \
	} > $(REPORT_DIR)/compile_gf180_summary.rpt

lint:
	@mkdir -p $(SPYGLASS_DIR)/lint
	@cp $(LINT_PRJ) $(SPYGLASS_DIR)/lint/lint.prj
	$(SPYGLASS) -batch -project $(SPYGLASS_DIR)/lint/lint.prj \
		-goals "lint/lint_rtl" > $(REPORT_DIR)/lint.log 2>&1
	@report=$$(find $(SPYGLASS_DIR)/lint -path '*/lint/lint_rtl/spyglass_reports/moresimple.rpt' -print -quit); \
		test -n "$$report"; cp "$$report" $(REPORT_DIR)/lint_summary.rpt
	@! grep -Eq '[[:space:]](Fatal|Error)[[:space:]]' $(REPORT_DIR)/lint_summary.rpt
	@echo "Lint summary: $(REPORT_DIR)/lint_summary.rpt"

cdc:
	@mkdir -p $(SPYGLASS_DIR)/cdc
	@cp $(CDC_PRJ) $(SPYGLASS_DIR)/cdc/cdc.prj
	$(SPYGLASS) -batch -project $(SPYGLASS_DIR)/cdc/cdc.prj \
		-goals "cdc/cdc_setup_check,cdc/cdc_verify" > $(REPORT_DIR)/cdc.log 2>&1
	@report=$$(find $(SPYGLASS_DIR)/cdc -path '*/cdc/cdc_verify/spyglass_reports/moresimple.rpt' -print -quit); \
		test -n "$$report"; cp "$$report" $(REPORT_DIR)/cdc_summary.rpt
	@! grep -Eq '[[:space:]](Fatal|Error)[[:space:]]' $(REPORT_DIR)/cdc_summary.rpt
	@echo "CDC summary: $(REPORT_DIR)/cdc_summary.rpt"

rdc:
	@mkdir -p $(SPYGLASS_DIR)/rdc
	@cp $(RDC_PRJ) $(SPYGLASS_DIR)/rdc/rdc.prj
	$(SPYGLASS) -batch -project $(SPYGLASS_DIR)/rdc/rdc.prj \
		-goals "rdc/rdc_verify_struct" > $(REPORT_DIR)/rdc.log 2>&1
	@report=$$(find $(SPYGLASS_DIR)/rdc -path '*/rdc/rdc_verify_struct/spyglass_reports/moresimple.rpt' -print -quit); \
		test -n "$$report"; cp "$$report" $(REPORT_DIR)/rdc_summary.rpt
	@! grep -Eq '[[:space:]](Fatal|Error)[[:space:]]' $(REPORT_DIR)/rdc_summary.rpt
	@echo "RDC summary: $(REPORT_DIR)/rdc_summary.rpt"

clean:
	# Preserve reports/*.log and reports/*_summary.rpt; remove only tool work data.
	rm -rf $(VCS_DIR) $(SPYGLASS_DIR)
	rm -rf csrc simv simv.daidir DVEfiles AN.DB novas.conf novas.rc verdiLog
	rm -rf lint/lint cdc/cdc rdc/rdc
	rm -f ucli.key vc_hdrs.h tr_db.log spyglass.log transcript
	rm -f *.vpd *.vcd *.fsdb *.wlf *.vstf *.ucdb *.log
	@echo "Removed generated work files; kept the main reports in reports/."
