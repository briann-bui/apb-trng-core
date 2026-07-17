module apb_trng_wrapper #(
  parameter int C_APB_DATA_WIDTH = 32,
  parameter int C_APB_ADDR_WIDTH = 8,
  parameter int NUM_RO           = 8,
  parameter int BASE_STAGES      = 7,
  parameter int OUTPUT_WIDTH     = 32,
  parameter int FIFO_DEPTH       = 8
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
  output logic                            o_trng_irq,
  output logic [OUTPUT_WIDTH-1:0]         o_trng_stream_data,
  output logic                            o_trng_stream_valid,
  input  logic                            i_trng_stream_ready
);

  logic              w_enable;
  logic              w_clear;
  logic [15:0]       w_sample_div;
  logic [7:0]        w_rep_limit;
  logic [7:0]        w_prop_low;
  logic [7:0]        w_prop_high;
  logic [NUM_RO-1:0] w_source_enable;
  logic              w_combine_mode;
  logic              w_auto_quarantine;
  logic [15:0]       w_stuck_limit;
  logic [1:0]        w_condition_mode;
  logic              w_vn_enable;
  logic [1:0]        w_oversample_sel;
  logic              w_fifo_apb_read;
  logic [31:0]       w_conditioned_data;
  logic              w_conditioned_valid;
  logic              w_conditioned_ready;
  logic              w_conditioned_pop;
  logic [31:0]       w_fifo_apb_data;
  logic              w_fifo_apb_valid;
  logic              w_fifo_empty;
  logic              w_fifo_full;
  logic [6:0]        w_fifo_level;
  logic              w_fifo_output_pulse;
  logic              w_not_ready_pulse;
  logic              w_stream_mode;
  logic              w_output_clear;
  logic              w_health_fail;
  logic              w_health_pulse;
  logic [15:0]       w_health_count;
  logic [8:0]        w_entropy_credit;
  logic [15:0]       w_reject_count;
  logic [NUM_RO-1:0] w_ro_sample;
  logic [NUM_RO-1:0] w_source_fail;
  logic              w_source_fail_pulse;
  logic [NUM_RO-1:0] w_source_active;

  apb_trng_core #(
    .NUM_RO      (NUM_RO),
    .BASE_STAGES (BASE_STAGES)
  ) u_trng_core (
    .i_trng_clk          (i_trng_pclk),
    .i_trng_rst_n        (i_trng_presetn),
    .i_trng_enable       (w_enable),
    .i_trng_clear        (w_clear),
    .i_trng_source_enable(w_source_enable),
    .i_trng_combine_mode (w_combine_mode),
    .i_trng_auto_quarantine(w_auto_quarantine),
    .i_trng_stuck_limit  (w_stuck_limit),
    .i_trng_condition_mode(w_condition_mode),
    .i_trng_vn_enable    (w_vn_enable),
    .i_trng_oversample_sel(w_oversample_sel),
    .i_trng_sample_div   (w_sample_div),
    .i_trng_rep_limit    (w_rep_limit),
    .i_trng_prop_low     (w_prop_low),
    .i_trng_prop_high    (w_prop_high),
    .i_trng_data_pop     (w_conditioned_pop),
    .o_trng_data         (w_conditioned_data),
    .o_trng_data_valid   (w_conditioned_valid),
    .o_trng_health_fail  (w_health_fail),
    .o_trng_word_pulse   (),
    .o_trng_health_pulse (w_health_pulse),
    .o_trng_health_count (w_health_count),
    .o_trng_entropy_credit(w_entropy_credit),
    .o_trng_reject_count (w_reject_count),
    .o_trng_ro_sample    (w_ro_sample),
    .o_trng_source_fail  (w_source_fail),
    .o_trng_source_fail_pulse(w_source_fail_pulse),
    .o_trng_source_active(w_source_active)
  );

  assign w_conditioned_pop = w_conditioned_valid && w_conditioned_ready;

  apb_trng_output_fifo #(
    .OUTPUT_WIDTH (OUTPUT_WIDTH),
    .FIFO_DEPTH   (FIFO_DEPTH)
  ) u_trng_output_fifo (
    .i_trng_clk               (i_trng_pclk),
    .i_trng_rst_n             (i_trng_presetn),
    // Flush queued output on the same edge that latches a new quarantine bit.
    .i_trng_clear             (w_clear || w_health_fail || w_output_clear ||
                               w_source_fail_pulse),
    .i_trng_conditioned_data  (w_conditioned_data),
    .i_trng_conditioned_valid (w_conditioned_valid),
    .o_trng_conditioned_ready (w_conditioned_ready),
    .i_trng_stream_mode       (w_stream_mode),
    .i_trng_apb_read          (w_fifo_apb_read),
    .o_trng_apb_data          (w_fifo_apb_data),
    .o_trng_apb_data_valid    (w_fifo_apb_valid),
    .o_trng_stream_data       (o_trng_stream_data),
    .o_trng_stream_valid      (o_trng_stream_valid),
    .i_trng_stream_ready      (i_trng_stream_ready),
    .o_trng_fifo_empty        (w_fifo_empty),
    .o_trng_fifo_full         (w_fifo_full),
    .o_trng_fifo_level        (w_fifo_level),
    .o_trng_output_pulse      (w_fifo_output_pulse),
    .o_trng_not_ready_pulse   (w_not_ready_pulse)
  );

  apb_trng_apb_if #(
    .C_APB_DATA_WIDTH (C_APB_DATA_WIDTH),
    .C_APB_ADDR_WIDTH (C_APB_ADDR_WIDTH),
    .NUM_RO           (NUM_RO),
    .OUTPUT_WIDTH     (OUTPUT_WIDTH),
    .FIFO_DEPTH       (FIFO_DEPTH)
  ) u_trng_apb_if (
    .i_trng_pclk         (i_trng_pclk),
    .i_trng_presetn      (i_trng_presetn),
    .i_trng_paddr        (i_trng_paddr),
    .i_trng_psel         (i_trng_psel),
    .i_trng_penable      (i_trng_penable),
    .i_trng_pwrite       (i_trng_pwrite),
    .i_trng_pwdata       (i_trng_pwdata),
    .i_trng_pstrb        (i_trng_pstrb),
    .o_trng_prdata       (o_trng_prdata),
    .o_trng_pready       (o_trng_pready),
    .o_trng_pslverr      (o_trng_pslverr),
    .o_trng_irq          (o_trng_irq),
    .o_trng_enable       (w_enable),
    .o_trng_clear        (w_clear),
    .o_trng_sample_div   (w_sample_div),
    .o_trng_rep_limit    (w_rep_limit),
    .o_trng_prop_low     (w_prop_low),
    .o_trng_prop_high    (w_prop_high),
    .o_trng_source_enable(w_source_enable),
    .o_trng_combine_mode (w_combine_mode),
    .o_trng_auto_quarantine(w_auto_quarantine),
    .o_trng_stuck_limit  (w_stuck_limit),
    .o_trng_condition_mode(w_condition_mode),
    .o_trng_vn_enable    (w_vn_enable),
    .o_trng_oversample_sel(w_oversample_sel),
    .o_trng_blocking_read(),
    .o_trng_stream_mode  (w_stream_mode),
    .o_trng_output_clear (w_output_clear),
    .o_trng_data_pop     (w_fifo_apb_read),
    .i_trng_data         (w_fifo_apb_data),
    .i_trng_data_valid   (w_fifo_apb_valid),
    .i_trng_health_fail  (w_health_fail),
    .i_trng_word_pulse   (w_fifo_output_pulse),
    .i_trng_health_pulse (w_health_pulse),
    .i_trng_health_count (w_health_count),
    .i_trng_entropy_credit(w_entropy_credit),
    .i_trng_reject_count (w_reject_count),
    .i_trng_fifo_empty   (w_fifo_empty),
    .i_trng_fifo_full    (w_fifo_full),
    .i_trng_fifo_level   (w_fifo_level),
    .i_trng_not_ready_pulse(w_not_ready_pulse),
    .i_trng_ro_sample    (w_ro_sample),
    .i_trng_source_fail  (w_source_fail),
    .i_trng_source_active(w_source_active)
  );

endmodule
