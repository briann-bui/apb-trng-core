module apb_trng_entropy_bank #(
  parameter int NUM_RO      = 8,
  parameter int BASE_STAGES = 7
) (
  input  logic              i_trng_clk,
  input  logic              i_trng_rst_n,
  input  logic [NUM_RO-1:0] i_trng_ro_enable,
  output logic [NUM_RO-1:0] o_trng_ro_sample
);

  logic [NUM_RO-1:0] w_ro_async;

  for (genvar g_ro = 0; g_ro < NUM_RO; g_ro++) begin : g_trng_ro
    localparam int RO_STAGES = BASE_STAGES + (2 * g_ro);

    apb_trng_ro #(
      .STAGES   (RO_STAGES),
      .SIM_SEED (32'h1021 * (g_ro + 1))
    ) u_trng_ro (
      .i_trng_clk    (i_trng_clk),
      .i_trng_rst_n  (i_trng_rst_n),
      .i_trng_enable (i_trng_ro_enable[g_ro]),
      .o_trng_ro     (w_ro_async[g_ro])
    );
  end

  // Two-flop sampling boundary for the asynchronous oscillator outputs.
  (* ASYNC_REG = "TRUE" *) logic [NUM_RO-1:0] r_ro_sync_ff1;
  (* ASYNC_REG = "TRUE" *) logic [NUM_RO-1:0] r_ro_sync_ff2;

  always_ff @(posedge i_trng_clk or negedge i_trng_rst_n) begin
    if (!i_trng_rst_n) begin
      r_ro_sync_ff1 <= '0;
      r_ro_sync_ff2 <= '0;
    end else begin
      r_ro_sync_ff1 <= w_ro_async;
      r_ro_sync_ff2 <= r_ro_sync_ff1;
    end
  end

  // Keep named ASYNC_REG flops visible to common implementation tools.
  assign o_trng_ro_sample = r_ro_sync_ff2;

endmodule
