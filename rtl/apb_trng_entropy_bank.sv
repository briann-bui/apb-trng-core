module apb_trng_entropy_bank #(
  parameter int NUM_RO      = 8,
  parameter int BASE_STAGES = 7
) (
  input  logic              i_trng_clk,
  input  logic              i_trng_rst_n,
  input  logic              i_trng_enable,
  output logic [NUM_RO-1:0] o_trng_ro_async
);

  for (genvar g_ro = 0; g_ro < NUM_RO; g_ro++) begin : g_trng_ro
    localparam int RO_STAGES = BASE_STAGES + (2 * g_ro);

    apb_trng_ro #(
      .STAGES   (RO_STAGES),
      .SIM_SEED (32'h1021 * (g_ro + 1))
    ) u_trng_ro (
      .i_trng_clk    (i_trng_clk),
      .i_trng_rst_n  (i_trng_rst_n),
      .i_trng_enable (i_trng_enable),
      .o_trng_ro     (o_trng_ro_async[g_ro])
    );
  end

endmodule
