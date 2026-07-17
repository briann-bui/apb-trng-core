# APB TRNG Core for GF180MCU

A 32-bit APB true-random-number generator intended for the
`gf180mcu_fd_sc_mcu9t5v0` standard-cell library. The physical entropy source is
an array of eight independently sized ring oscillators. The digital path adds
synchronization, per-source and combined online health tests, source selection,
automatic quarantine, von Neumann debiasing, conditioning, data status, and
interrupts.

> A passing RTL regression does not certify entropy. Before security use, the
> fabricated source must be characterized across process, voltage, temperature,
> aging, and injection conditions, and its health thresholds must be derived
> from measured data.

## Architecture

```text
8 independently enabled GF180 NAND/inverter rings
          |
     2-FF samplers
          |
 per-source stuck/APT monitors
          |
 XOR or round-robin selector
          |
  RCT + APT health tests
          |
 raw-valid filter + optional Von Neumann
          |
 XOR-fold / LFSR / CRC / SHA-256 conditioner
          |
  entropy-credit threshold (2x/4x/8x)
          |
 parameterized output FIFO
          |
 APB register or ready/valid stream
```

Each oscillator contains one
`gf180mcu_fd_sc_mcu9t5v0__nand2_1` enable gate and an even number of
`gf180mcu_fd_sc_mcu9t5v0__inv_1` cells, giving an odd inversion count. Default
ring lengths are 7, 9, 11, 13, 15, 17, 19, and 21 stages. This intentional
diversity reduces the chance that process, voltage, temperature, or clock
conditions affect every source in exactly the same way. Defining
`GF180MCU_SC` selects these physical library cells. Normal RTL simulation uses
a deterministic surrogate because zero-delay functional models cannot model a
ring oscillator and can create an infinite delta-cycle loop.

## Registers

| Address | Name | Description |
| --- | --- | --- |
| `0x00` | `CTRL` | `[0]` enable; write `[1]=1` to clear conditioner and health state |
| `0x04` | `STATUS` | `[0]` enabled, `[1]` data valid, `[2]` health failure, `[3]` IRQ pending, `[4]` source failure, `[5]` no active source, `[6]` data not ready, `[7]` FIFO full, `[8]` FIFO empty |
| `0x08` | `DATA` | Conditioned 32-bit word; a successful read consumes it |
| `0x0C` | `HEALTH_CFG` | `[7:0]` repetition limit, `[15:8]` APT low, `[23:16]` APT high |
| `0x10` | `SAMPLE_DIV` | Sampling interval minus one in APB clock cycles |
| `0x14` | `IRQ_EN` | `[0]` word ready, `[1]` health failure |
| `0x18` | `IRQ_STAT` | Latched interrupt status, write one to clear |
| `0x1C` | `HEALTH_CNT` | Saturating count of latched health failures |
| `0x20` | `RO_SAMPLE` | Synchronized oscillator sample vector for bring-up diagnostics |
| `0x24` | `SOURCE_EN` | One enable bit per RO source; default all enabled |
| `0x28` | `SOURCE_CFG` | `[0]` 0=XOR/1=round-robin, `[1]` automatic quarantine |
| `0x2C` | `STUCK_LIMIT` | Maximum consecutive unchanged samples per source; zero disables |
| `0x30` | `SOURCE_FAIL` | Sticky per-source stuck/bias failure mask |
| `0x34` | `SOURCE_ACTIVE` | Sources currently admitted to the entropy mixer |
| `0x38` | `COND_CFG` | `[1:0]` mode, `[2]` Von Neumann enable, `[5:4]` oversampling |
| `0x3C` | `ENTROPY_CNT` | Accepted-bit credit accumulated toward the next word |
| `0x40` | `REJECT_CNT` | Saturating count of rejected raw events/pairs |
| `0x44` | `OUTPUT_CFG` | `[0]` blocking APB read, `[1]` streaming output mode |
| `0x48` | `FIFO_LEVEL` | Number of complete random words queued |
| `0x4C` | `OUTPUT_INFO` | `[7:0]` output width, `[15:8]` FIFO depth |
| `0xFC` | `VERSION` | `0x0005_0001` |

The adaptive proportion test uses a fixed 64-sample window and runs both on
every enabled source and on the combined raw stream. Defaults are a
repetition-count limit of 16, an allowed ones count of 16 through 48, and a
per-source stuck limit of 256 samples. A zero limit disables the corresponding
repetition/stuck test. Per-source failures are sticky. With auto-quarantine,
the faulty source is removed while healthy sources continue; loss of every
source or a combined-stream failure latches global health failure and
invalidates output data. A newly failed source immediately flushes partial
conditioning state and every queued output word before the remaining healthy
sources resume collection. `CTRL[1]` clears all health state.

## Entropy conditioning

`COND_CFG[1:0]` selects the 32-bit conditioning function:

| Value | Function |
| --- | --- |
| `0` | XOR folding into 32 lanes |
| `1` | LFSR whitening, polynomial `0x00400007` |
| `2` | CRC conditioning, polynomial `0x04C11DB7` |
| `3` | SHA-256, using the real `sha_256_core` RTL |

When `COND_CFG[2]` is set, the Von Neumann corrector maps `01 -> 0` and
`10 -> 1`; equal pairs `00` and `11` are rejected. Raw samples that coincide
with combined health failure or a newly failed source are also rejected before
they reach the conditioner.

`COND_CFG[5:4]` controls the minimum accepted-bit credit:

| Value | Oversampling | Accepted bits per 32-bit word |
| --- | --- | --- |
| `0` | 2x | 64 |
| `1` | 4x | 128 |
| `2`, `3` | 8x | 256 |

No output word is published until the selected threshold is reached. Reading
`DATA` consumes the word; conditioning pauses while an unread word is pending,
so it cannot overwrite software-visible data. A configuration change discards
all partial credit and restarts with the new policy.

SHA mode collects a 64-, 128-, or 256-bit entropy message, constructs standard
single-block SHA-256 padding, and runs the self-contained synthesizable core in
`rtl/sha256/`. All local SHA packages and modules use the
`apb_trng_sha256_*` prefix. Only digest bits `[255:224]` are published. Truncating to
32 output bits preserves the selected 2x/4x/8x input entropy budget; publishing
all 256 digest bits from a 64-bit message would incorrectly overstate entropy.
The SHA adapter has known-answer tests for all three supported message lengths.
The end-to-end regression also requires multiple consecutive SHA-conditioned
words, with a fresh accepted-bit budget accumulated for every word.

## Random output and backpressure

`OUTPUT_WIDTH` is a build-time parameter supporting 8, 16, 32, 64, or 128
bits. `FIFO_DEPTH` supports 4 through 64 complete output words. Conditioned
32-bit blocks are split for 8/16-bit output and packed for 64/128-bit output.

APB mode is non-blocking by default. Reading an empty FIFO returns zero and
latches `STATUS[6]`. With `OUTPUT_CFG[0]=1`, an empty `DATA` read holds
`PREADY=0` until a complete word is available. For output widths above 32,
successive `DATA` reads return consecutive 32-bit slices and pop the FIFO entry
only after the final slice.

With `OUTPUT_CFG[1]=1`, the top-level `o_trng_stream_data`,
`o_trng_stream_valid`, and `i_trng_stream_ready` ports implement standard
backpressure. Data and `VALID` remain stable until `READY` is asserted. A full
FIFO propagates backpressure to the conditioner, so unread output is never
overwritten. Reset, health failure, or a conditioning-policy change flushes
partial state and queued output; no stale register value can be read again.

Throughput depends on PCLK, sampling divisor, Von Neumann rejection rate,
oversampling ratio, selected conditioner, and measured silicon entropy. RTL
cannot guarantee 1 Mbps across PVT without those physical measurements. SHA-256
adds approximately 68–69 clock cycles after each entropy message is complete.

## Physical entropy and PVT robustness

The implemented physical mechanism is **ring-oscillator phase jitter**. RTL
cannot truthfully create thermal noise or metastability entropy: those require
a characterized analog/custom-cell macro and a technology-specific interface.
Such a macro can replace or extend `apb_trng_entropy_bank` while reusing the
source enable, selection, health, quarantine, conditioning, and APB layers.

The design limits common-mode degradation through different ring lengths,
parallel sources, programmable sampling rate, independent monitoring, and
automatic quarantine. These mechanisms detect and contain degradation; they do
not eliminate PVT dependence. Silicon qualification must sweep temperature,
supply voltage, process corners, reference-clock variation, and digital-noise
activity. Thresholds should then be programmed from the measured distributions.

## Build and test

```sh
make lint          # technology-independent RTL
make lint-gf180    # elaborates the real GF180 cell variant
make sim           # self-checking APB/data/health regression
make sim-sha       # SHA-256 adapter known-answer tests
make run           # class-based UVM 1.2 regression
make coverage      # requires a licensed Questa/ModelSim coverage feature
make all
```

The local PDK is referenced from `../reference/` by `filelist_gf180.f`. The
TRNG has no runtime or compile-time dependency on the sibling SHA repository.

With `GF180MCU_SC`, the entropy rings explicitly instantiate GF180 NAND and
inverter cells, while the parallel entropy mixer explicitly instantiates GF180
XOR cells; all carry keep/dont-touch attributes. The SHA datapath,
conditioner, FIFO, APB logic, and synchronizers remain technology-independent
synchronous RTL so synthesis can optimize and map them to the selected GF180
standard-cell liberty corner. Hand-instantiating every SHA gate would prevent
useful timing/area optimization; the explicit-cell boundary is therefore kept
at the physically sensitive entropy source.

## ASIC integration requirements

1. Synthesize the tapeout variant with `GF180MCU_SC` defined.
2. Source `constraints/gf180_trng.tcl` and verify every RO cell remains in the
   post-synthesis netlist. Combinational-loop removal must be disabled for these
   instances only.
3. Keep each ring locally compact, but separate different rings physically to
   reduce common-mode coupling and correlation. Avoid clock trunks, large
   switching buses, regulators, and high-current output drivers; use guard
   rings, local decoupling, and supply isolation where the floorplan permits.
4. Mark the first sampling flop as asynchronous and review recovery/removal and
   metastability containment at signoff.
5. Run gate-level RO simulations only with extracted/SDF delay. Do not simulate
   the GF180 zero-delay functional cell filelist as an entropy model.
6. Characterize raw samples on silicon and perform the applicable SP 800-90B
   entropy-source assessment before claiming a security strength.

## Repository structure

```text
rtl/          Synthesizable entropy source, conditioner, APB, and wrapper
rtl/sha256/   Self-contained TRNG-prefixed SHA-256 block core
uvm/          Class-based UVM 1.2 environment and legacy smoke/KAT tops
constraints/  GF180 preservation and CDC constraints
docs/         Vietnamese architecture and block-diagram guide
```
