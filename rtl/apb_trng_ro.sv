module apb_trng_ro #(
  parameter int STAGES   = 7,
  parameter int SIM_SEED = 1
) (
  input  logic i_trng_clk,
  input  logic i_trng_rst_n,
  input  logic i_trng_enable,
  output logic o_trng_ro
);

  initial begin
    assert ((STAGES >= 3) && ((STAGES % 2) == 1))
      else $error("apb_trng_ro STAGES must be odd and >= 3");
  end

`ifdef GF180MCU_SC
  // The NAND gate both closes and disables the ring.  All cells below are
  // physical cells from gf180mcu_fd_sc_mcu9t5v0, not inferred RTL gates.
  // Functional zero-delay cell models must only be linted/elaborated; use the
  // default simulation model for event simulation.
  wire [STAGES-1:0] w_ro_node /* verilator split_var */;

  (* keep = "true", dont_touch = "true" *)
  gf180mcu_fd_sc_mcu9t5v0__nand2_1 u_trng_ro_gate (
    .A1 (i_trng_enable),
    .A2 (w_ro_node[STAGES-1]),
    .ZN (w_ro_node[0])
  );

  for (genvar g_stage = 1; g_stage < STAGES; g_stage++) begin : g_trng_inv
    (* keep = "true", dont_touch = "true" *)
    gf180mcu_fd_sc_mcu9t5v0__inv_1 u_trng_ro_inv (
      .I  (w_ro_node[g_stage-1]),
      .ZN (w_ro_node[g_stage])
    );
  end

  assign o_trng_ro = w_ro_node[STAGES-1];
`else
  // Digital surrogate used only for RTL/UVM simulation.  It is deliberately
  // deterministic so regressions are repeatable; it is not an entropy source.
  logic [31:0] r_sim_lfsr;
  logic        w_sim_feedback;

  assign w_sim_feedback = r_sim_lfsr[31] ^ r_sim_lfsr[21] ^
                          r_sim_lfsr[1]  ^ r_sim_lfsr[0];

  always_ff @(posedge i_trng_clk or negedge i_trng_rst_n) begin
    if (!i_trng_rst_n) begin
      r_sim_lfsr <= 32'h1ACE_B00C ^ SIM_SEED;
    end else if (i_trng_enable) begin
      r_sim_lfsr <= {r_sim_lfsr[30:0], w_sim_feedback};
    end
  end

  assign o_trng_ro = i_trng_enable && r_sim_lfsr[0];
`endif

endmodule
