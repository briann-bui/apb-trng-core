# TRNG UVM 1.2 verification environment

This is a class-based UVM environment using `uvm_pkg`, factory registration,
an active APB agent, monitor analysis port, scoreboard, reusable sequences,
tests, and a UVM top. It follows the layout used by the other APB IPs.

```text
uvm/
├── agent/       APB transaction, sequencer, and agent
├── driver/      APB protocol driver with PREADY support
├── monitor/     APB bus monitor and analysis port
├── scoreboard/  APB response and fixed-register checks
├── env/         Agent/scoreboard connectivity
├── sequences/   Register, entropy/SHA, and health sequences
├── tests/       Individual tests and aggregate all-test
└── tb/          Interface, UVM package, top, and legacy smoke/KAT tops
```

Run the complete UVM regression:

```sh
make run
```

Run a selected test:

```sh
make run UVM_TEST=apb_trng_reg_test
make run UVM_TEST=apb_trng_entropy_test
make run UVM_TEST=apb_trng_health_test
make run UVM_TEST=apb_trng_all_test
```

The `make coverage` target is provided for a licensed Questa/ModelSim edition
with Code Coverage enabled. ModelSim Intel FPGA Starter Edition can run the UVM
tests but reports a license error for `-coverage`. The earlier deterministic
module-level regressions remain available as `make sim` and `make sim-sha`.

The GF180 ring oscillator must not be simulated as a zero-delay combinational
loop. Normal verification therefore uses the deterministic RTL surrogate; real
entropy characterization requires a post-layout delay model and silicon data.
