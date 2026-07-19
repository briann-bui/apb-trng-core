module apb_trng_wrapper #(
  parameter int C_APB_DATA_WIDTH = 32,
  parameter int C_APB_ADDR_WIDTH = 8,
  parameter int NUM_RO           = 8,
  parameter int BASE_STAGES      = 7
) (
  input  logic                            i_trng_pclk,
  input  logic                            i_trng_presetn,
  input  logic [C_APB_ADDR_WIDTH-1:0]     i_trng_paddr,
  input  logic                            i_trng_psel,
  input  logic                            i_trng_penable,
  input  logic                            i_trng_pwrite,
  input  logic [C_APB_DATA_WIDTH-1:0]     i_trng_pwdata,
  input  logic [(C_APB_DATA_WIDTH/8)-1:0] i_trng_pstrb,
  output logic [C_APB_DATA_WIDTH-1:0]     o_trng_prdata,
  output logic                            o_trng_pready,
  output logic                            o_trng_pslverr,
  output logic                            o_trng_irq
);

  logic        w_enable;
  logic        w_clear;
  logic        w_data_pop;
  logic [31:0] w_data;
  logic        w_data_valid;
  logic        w_health_fail;

  apb_trng_core #(
    .NUM_RO      (NUM_RO),
    .BASE_STAGES (BASE_STAGES)
  ) u_trng_core (
    .i_trng_clk         (i_trng_pclk),
    .i_trng_rst_n       (i_trng_presetn),
    .i_trng_enable      (w_enable),
    .i_trng_clear       (w_clear),
    .i_trng_data_pop    (w_data_pop),
    .o_trng_data        (w_data),
    .o_trng_data_valid  (w_data_valid),
    .o_trng_health_fail (w_health_fail)
  );

  apb_trng_apb_if #(
    .C_APB_DATA_WIDTH (C_APB_DATA_WIDTH),
    .C_APB_ADDR_WIDTH (C_APB_ADDR_WIDTH)
  ) u_trng_apb_if (
    .i_trng_pclk        (i_trng_pclk),
    .i_trng_presetn     (i_trng_presetn),
    .i_trng_paddr       (i_trng_paddr),
    .i_trng_psel        (i_trng_psel),
    .i_trng_penable     (i_trng_penable),
    .i_trng_pwrite      (i_trng_pwrite),
    .i_trng_pwdata      (i_trng_pwdata),
    .i_trng_pstrb       (i_trng_pstrb),
    .o_trng_prdata      (o_trng_prdata),
    .o_trng_pready      (o_trng_pready),
    .o_trng_pslverr     (o_trng_pslverr),
    .o_trng_irq         (o_trng_irq),
    .o_trng_enable      (w_enable),
    .o_trng_clear       (w_clear),
    .o_trng_data_pop    (w_data_pop),
    .i_trng_data        (w_data),
    .i_trng_data_valid  (w_data_valid),
    .i_trng_health_fail (w_health_fail)
  );

endmodule
