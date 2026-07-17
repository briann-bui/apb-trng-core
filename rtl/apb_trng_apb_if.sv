module apb_trng_apb_if
  import apb_trng_pkg::*;
#(
  parameter int C_APB_DATA_WIDTH = 32,
  parameter int C_APB_ADDR_WIDTH = 8,
  parameter int NUM_RO           = 8,
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
  output logic                            o_trng_enable,
  output logic                            o_trng_clear,
  output logic [15:0]                     o_trng_sample_div,
  output logic [7:0]                      o_trng_rep_limit,
  output logic [7:0]                      o_trng_prop_low,
  output logic [7:0]                      o_trng_prop_high,
  output logic [NUM_RO-1:0]               o_trng_source_enable,
  output logic                            o_trng_combine_mode,
  output logic                            o_trng_auto_quarantine,
  output logic [15:0]                     o_trng_stuck_limit,
  output logic [1:0]                      o_trng_condition_mode,
  output logic                            o_trng_vn_enable,
  output logic [1:0]                      o_trng_oversample_sel,
  output logic                            o_trng_blocking_read,
  output logic                            o_trng_stream_mode,
  output logic                            o_trng_output_clear,
  output logic                            o_trng_data_pop,
  input  logic [31:0]                     i_trng_data,
  input  logic                            i_trng_data_valid,
  input  logic                            i_trng_health_fail,
  input  logic                            i_trng_word_pulse,
  input  logic                            i_trng_health_pulse,
  input  logic [15:0]                     i_trng_health_count,
  input  logic [8:0]                      i_trng_entropy_credit,
  input  logic [15:0]                     i_trng_reject_count,
  input  logic                            i_trng_fifo_empty,
  input  logic                            i_trng_fifo_full,
  input  logic [6:0]                      i_trng_fifo_level,
  input  logic                            i_trng_not_ready_pulse,
  input  logic [NUM_RO-1:0]               i_trng_ro_sample,
  input  logic [NUM_RO-1:0]               i_trng_source_fail,
  input  logic [NUM_RO-1:0]               i_trng_source_active
);

  logic        r_enable;
  logic [31:0] r_health_cfg;
  logic [31:0] r_sample_div;
  logic [31:0] r_source_enable;
  logic [31:0] r_source_cfg;
  logic [31:0] r_stuck_limit;
  logic [31:0] r_cond_cfg;
  logic [31:0] r_output_cfg;
  logic        r_data_not_ready;
  logic [1:0]  r_irq_en;
  logic [1:0]  r_irq_stat;
  logic [31:0] r_prdata;
  logic        w_apb_write;
  logic        w_apb_read;

  initial begin
    assert (C_APB_DATA_WIDTH == 32)
      else $error("apb_trng_apb_if requires a 32-bit APB data bus");
    assert (NUM_RO <= 32)
      else $error("RO_SAMPLE register supports at most 32 oscillators");
  end

  assign w_apb_write = i_trng_psel && i_trng_penable && i_trng_pwrite;
  assign w_apb_read  = i_trng_psel && i_trng_penable && !i_trng_pwrite;

  always_ff @(posedge i_trng_pclk or negedge i_trng_presetn) begin
    if (!i_trng_presetn) begin
      r_enable     <= 1'b0;
      r_health_cfg <= 32'h0030_1010; // high=48, low=16, repetition limit=16
      r_sample_div <= 32'd7;
      r_source_enable <= 32'hFFFF_FFFF;
      r_source_cfg    <= 32'h0000_0002; // XOR combine + auto quarantine
      r_stuck_limit   <= 32'd256;
      r_cond_cfg      <= 32'h0000_0006; // CRC, Von Neumann, 2x
      r_output_cfg    <= 32'd0; // non-blocking APB register/FIFO mode
      r_data_not_ready <= 1'b0;
      r_irq_en     <= 2'd0;
      r_irq_stat   <= 2'd0;
      o_trng_clear <= 1'b0;
      o_trng_output_clear <= 1'b0;

    end else begin
      o_trng_clear <= 1'b0;
      o_trng_output_clear <= 1'b0;

      if (i_trng_not_ready_pulse) r_data_not_ready <= 1'b1;
      if (w_apb_read && (i_trng_paddr == APB_TRNG_ADDR_DATA) &&
          !r_output_cfg[0] && !i_trng_data_valid)
        r_data_not_ready <= 1'b1;

      if (i_trng_word_pulse)   r_irq_stat[0] <= 1'b1;
      if (i_trng_health_pulse) r_irq_stat[1] <= 1'b1;

      if (w_apb_write) begin
        unique case (i_trng_paddr)
          APB_TRNG_ADDR_CTRL: begin
            if (i_trng_pstrb[0]) begin
              r_enable     <= i_trng_pwdata[0];
              o_trng_clear <= i_trng_pwdata[1];
              if (i_trng_pwdata[1]) r_data_not_ready <= 1'b0;
            end
          end
          APB_TRNG_ADDR_HEALTH_CFG: begin
            if (i_trng_pstrb[0]) r_health_cfg[7:0]   <= i_trng_pwdata[7:0];
            if (i_trng_pstrb[1]) r_health_cfg[15:8]  <= i_trng_pwdata[15:8];
            if (i_trng_pstrb[2]) r_health_cfg[23:16] <= i_trng_pwdata[23:16];
          end
          APB_TRNG_ADDR_SAMPLE_DIV: begin
            if (i_trng_pstrb[0]) r_sample_div[7:0]  <= i_trng_pwdata[7:0];
            if (i_trng_pstrb[1]) r_sample_div[15:8] <= i_trng_pwdata[15:8];
          end
          APB_TRNG_ADDR_SOURCE_EN: begin
            if (i_trng_pstrb[0]) r_source_enable[7:0]   <= i_trng_pwdata[7:0];
            if (i_trng_pstrb[1]) r_source_enable[15:8]  <= i_trng_pwdata[15:8];
            if (i_trng_pstrb[2]) r_source_enable[23:16] <= i_trng_pwdata[23:16];
            if (i_trng_pstrb[3]) r_source_enable[31:24] <= i_trng_pwdata[31:24];
          end
          APB_TRNG_ADDR_SOURCE_CFG: begin
            if (i_trng_pstrb[0]) r_source_cfg[1:0] <= i_trng_pwdata[1:0];
          end
          APB_TRNG_ADDR_STUCK_LIMIT: begin
            if (i_trng_pstrb[0]) r_stuck_limit[7:0]  <= i_trng_pwdata[7:0];
            if (i_trng_pstrb[1]) r_stuck_limit[15:8] <= i_trng_pwdata[15:8];
          end
          APB_TRNG_ADDR_COND_CFG: begin
            if (i_trng_pstrb[0]) begin
              r_cond_cfg[5:0] <= i_trng_pwdata[5:0];
              o_trng_output_clear <= 1'b1;
            end
          end
          APB_TRNG_ADDR_OUTPUT_CFG: begin
            if (i_trng_pstrb[0]) r_output_cfg[1:0] <= i_trng_pwdata[1:0];
          end
          APB_TRNG_ADDR_IRQ_EN: begin
            if (i_trng_pstrb[0]) r_irq_en <= i_trng_pwdata[1:0];
          end
          APB_TRNG_ADDR_IRQ_STAT: begin
            // Hardware events win over a simultaneous software W1C.
            if (i_trng_pstrb[0])
              r_irq_stat <= (r_irq_stat & ~i_trng_pwdata[1:0]) |
                            {i_trng_health_pulse, i_trng_word_pulse};
          end
          default: ;
        endcase
      end
    end
  end

  always_comb begin
    r_prdata = 32'd0;
    unique case (i_trng_paddr)
      APB_TRNG_ADDR_CTRL:        r_prdata = {31'd0, r_enable};
      APB_TRNG_ADDR_STATUS:      r_prdata = {23'd0, i_trng_fifo_empty,
                                             i_trng_fifo_full, r_data_not_ready,
                                             !(|i_trng_source_active), |i_trng_source_fail,
                                             |r_irq_stat, i_trng_health_fail,
                                             i_trng_data_valid, r_enable};
      APB_TRNG_ADDR_DATA:        r_prdata = i_trng_data_valid ? i_trng_data : 32'd0;
      APB_TRNG_ADDR_HEALTH_CFG:  r_prdata = r_health_cfg;
      APB_TRNG_ADDR_SAMPLE_DIV:  r_prdata = r_sample_div;
      APB_TRNG_ADDR_IRQ_EN:      r_prdata = {30'd0, r_irq_en};
      APB_TRNG_ADDR_IRQ_STAT:    r_prdata = {30'd0, r_irq_stat};
      APB_TRNG_ADDR_HEALTH_CNT:  r_prdata = {16'd0, i_trng_health_count};
      APB_TRNG_ADDR_RO_SAMPLE:   r_prdata = {{(32-NUM_RO){1'b0}}, i_trng_ro_sample};
      APB_TRNG_ADDR_SOURCE_EN:   r_prdata = r_source_enable;
      APB_TRNG_ADDR_SOURCE_CFG:  r_prdata = r_source_cfg;
      APB_TRNG_ADDR_STUCK_LIMIT: r_prdata = r_stuck_limit;
      APB_TRNG_ADDR_SOURCE_FAIL: r_prdata = {{(32-NUM_RO){1'b0}}, i_trng_source_fail};
      APB_TRNG_ADDR_SOURCE_ACT:  r_prdata = {{(32-NUM_RO){1'b0}}, i_trng_source_active};
      APB_TRNG_ADDR_COND_CFG:    r_prdata = r_cond_cfg;
      APB_TRNG_ADDR_ENTROPY_CNT: r_prdata = {23'd0, i_trng_entropy_credit};
      APB_TRNG_ADDR_REJECT_CNT:  r_prdata = {16'd0, i_trng_reject_count};
      APB_TRNG_ADDR_OUTPUT_CFG:  r_prdata = r_output_cfg;
      APB_TRNG_ADDR_FIFO_LEVEL:  r_prdata = {25'd0, i_trng_fifo_level};
      APB_TRNG_ADDR_OUTPUT_INFO: r_prdata = {16'd0, FIFO_DEPTH[7:0], OUTPUT_WIDTH[7:0]};
      APB_TRNG_ADDR_VERSION:     r_prdata = APB_TRNG_VERSION;
      default:                   r_prdata = 32'd0;
    endcase
  end

  assign o_trng_prdata      = w_apb_read ? r_prdata : 32'd0;
  assign o_trng_pready      = !(w_apb_read && (i_trng_paddr == APB_TRNG_ADDR_DATA) &&
                                r_output_cfg[0] && !i_trng_data_valid);
  assign o_trng_pslverr     = 1'b0;
  assign o_trng_irq         = |(r_irq_en & r_irq_stat);
  assign o_trng_enable      = r_enable;
  assign o_trng_sample_div  = r_sample_div[15:0];
  assign o_trng_rep_limit   = r_health_cfg[7:0];
  assign o_trng_prop_low    = r_health_cfg[15:8];
  assign o_trng_prop_high   = r_health_cfg[23:16];
  assign o_trng_source_enable  = r_source_enable[NUM_RO-1:0];
  assign o_trng_combine_mode   = r_source_cfg[0];
  assign o_trng_auto_quarantine = r_source_cfg[1];
  assign o_trng_stuck_limit    = r_stuck_limit[15:0];
  assign o_trng_condition_mode = r_cond_cfg[1:0];
  assign o_trng_vn_enable      = r_cond_cfg[2];
  assign o_trng_oversample_sel = r_cond_cfg[5:4];
  assign o_trng_blocking_read = r_output_cfg[0];
  assign o_trng_stream_mode   = r_output_cfg[1];
  assign o_trng_data_pop    = w_apb_read && o_trng_pready &&
                              (i_trng_paddr == APB_TRNG_ADDR_DATA);

endmodule
