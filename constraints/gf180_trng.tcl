# Preserve the intentionally combinational GF180 ring oscillators.
# Source this file after elaborating apb_trng_wrapper. Adapt hierarchical
# separators if the implementation tool does not use '/' in object names.
set trng_ro_cells [get_cells -hierarchical -filter {NAME =~ *u_trng_entropy_bank*g_trng_ro*u_trng_ro*u_trng_ro_*}]
set_dont_touch $trng_ro_cells true

# RO outputs are asynchronous entropy inputs, not timing clocks.
set trng_sync_d [get_pins -hierarchical -filter {NAME =~ *u_trng_entropy_bank*r_ro_sync_ff1*/D}]
set_false_path -to $trng_sync_d

# Placement guidance: spread oscillator groups to reduce correlation while
# keeping every individual ring compact. Exact regions are floorplan-specific.
# Keep RO cells away from clock trunks, high-toggle buses, pad drivers, and
# regulator/supply-switch boundaries. Use separate placement regions, guard
# rings, and local decoupling where supported by the GF180 floorplan flow.
# Do not balance or otherwise route RO nets as functional clocks.
