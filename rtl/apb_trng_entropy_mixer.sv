module apb_trng_entropy_mixer #(
  parameter int NUM_SOURCES = 8
) (
  input  logic [NUM_SOURCES-1:0] i_trng_source_bits,
  output logic                   o_trng_xor_async
);

`ifdef GF180MCU_SC
  wire [NUM_SOURCES-1:0] w_xor_chain;
  assign w_xor_chain[0] = i_trng_source_bits[0];

  for (genvar g_source = 1; g_source < NUM_SOURCES; g_source++) begin : g_trng_xor
    (* keep = "true", dont_touch = "true" *)
    gf180mcu_fd_sc_mcu9t5v0__xor2_1 u_trng_entropy_xor (
      .A1 (w_xor_chain[g_source-1]),
      .A2 (i_trng_source_bits[g_source]),
      .Z  (w_xor_chain[g_source])
    );
  end

  assign o_trng_xor_async = w_xor_chain[NUM_SOURCES-1];
`else
  assign o_trng_xor_async = ^i_trng_source_bits;
`endif

endmodule
