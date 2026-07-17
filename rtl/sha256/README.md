# TRNG-local SHA-256 RTL

This directory contains the SHA-256 datapath used only by the TRNG conditioning
mode. It was imported from the local `sha_256_core` IP and renamed with the
`apb_trng_sha256_*` prefix so `apb-trng-core` is self-contained and cannot
collide with a standalone SHA IP in the same SoC build.

Only the block core required by entropy conditioning is included. The original
AXI wrapper, UVM environment, and unrelated integration files are intentionally
not copied.

The adapter in `../apb_trng_sha256_adapter.sv` creates standard single-block
padding for 64-, 128-, and 256-bit entropy messages and truncates the 256-bit
digest to one 32-bit conditioned output word.
