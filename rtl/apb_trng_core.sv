module apb_trng_core #(
  parameter int NUM_RO       = 8,
  parameter int BASE_STAGES  = 7,
  parameter int SAMPLE_DIV   = 7,
  parameter int RCT_CUTOFF   = 32,
  parameter int APT_WINDOW   = 64,
  parameter int APT_LOW      = 16,
  parameter int APT_HIGH     = 48
) (
  input  logic        i_trng_clk,
  input  logic        i_trng_rst_n,
  input  logic        i_trng_enable,
  input  logic        i_trng_clear,
  input  logic        i_trng_data_pop,
  output logic [31:0] o_trng_data,
  output logic        o_trng_data_valid,
  output logic        o_trng_health_fail
);

  localparam int SAMPLE_COUNT_W = (SAMPLE_DIV < 1) ? 1 : $clog2(SAMPLE_DIV + 1);
  localparam int RCT_COUNT_W    = (RCT_CUTOFF < 2) ? 1 : $clog2(RCT_CUTOFF + 1);
  localparam int APT_COUNT_W    = (APT_WINDOW < 2) ? 1 : $clog2(APT_WINDOW);
  localparam int APT_ONES_W     = $clog2(APT_WINDOW + 1);
  localparam logic [SAMPLE_COUNT_W-1:0] SAMPLE_DIV_VALUE = SAMPLE_DIV;
  localparam logic [RCT_COUNT_W-1:0] RCT_CUTOFF_VALUE = RCT_CUTOFF;
  localparam logic [RCT_COUNT_W-1:0] RCT_LAST_OK_VALUE = RCT_CUTOFF - 1;
  localparam logic [APT_COUNT_W-1:0] APT_LAST_VALUE = APT_WINDOW - 1;
  localparam logic [APT_ONES_W-1:0] APT_LOW_VALUE = APT_LOW;
  localparam logic [APT_ONES_W-1:0] APT_HIGH_VALUE = APT_HIGH;

  logic [NUM_RO-1:0] w_ro_async;
  logic              w_xor_async;
  (* ASYNC_REG = "TRUE" *) logic r_xor_sync_ff1;
  (* ASYNC_REG = "TRUE" *) logic r_xor_sync_ff2;
  logic [SAMPLE_COUNT_W-1:0] r_sample_count;
  logic                       w_sample_tick;

  logic                       r_rct_started;
  logic                       r_rct_last;
  logic [RCT_COUNT_W-1:0]     r_rct_count;
  logic [APT_COUNT_W-1:0]     r_apt_count;
  logic [APT_ONES_W-1:0]      r_apt_ones;
  logic [APT_ONES_W-1:0]      w_apt_ones_next;
  logic                       w_rct_fail;
  logic                       w_apt_fail;

  logic                       r_pair_valid;
  logic                       r_pair_first;
  logic [5:0]                 r_vn_count;
  logic [31:0]                r_word_shift;

  apb_trng_entropy_bank #(
    .NUM_RO      (NUM_RO),
    .BASE_STAGES (BASE_STAGES)
  ) u_trng_entropy_bank (
    .i_trng_clk      (i_trng_clk),
    .i_trng_rst_n    (i_trng_rst_n),
    .i_trng_enable   (i_trng_enable),
    .o_trng_ro_async (w_ro_async)
  );

  apb_trng_entropy_mixer #(
    .NUM_SOURCES (NUM_RO)
  ) u_trng_entropy_mixer (
    .i_trng_source_bits (w_ro_async),
    .o_trng_xor_async   (w_xor_async)
  );

  always_ff @(posedge i_trng_clk or negedge i_trng_rst_n) begin
    if (!i_trng_rst_n) begin
      r_xor_sync_ff1 <= 1'b0;
      r_xor_sync_ff2 <= 1'b0;
    end else begin
      r_xor_sync_ff1 <= w_xor_async;
      r_xor_sync_ff2 <= r_xor_sync_ff1;
    end
  end

  assign w_sample_tick = i_trng_enable && !o_trng_data_valid &&
                         !o_trng_health_fail && (r_sample_count == SAMPLE_DIV_VALUE);

  always_ff @(posedge i_trng_clk or negedge i_trng_rst_n) begin
    if (!i_trng_rst_n) begin
      r_sample_count <= '0;
    end else if (i_trng_clear || !i_trng_enable ||
                 o_trng_data_valid || o_trng_health_fail) begin
      r_sample_count <= '0;
    end else if (w_sample_tick) begin
      r_sample_count <= '0;
    end else begin
      r_sample_count <= r_sample_count + 1'b1;
    end
  end

  assign w_rct_fail = w_sample_tick && r_rct_started &&
                      (r_xor_sync_ff2 == r_rct_last) &&
                      (r_rct_count >= RCT_LAST_OK_VALUE);

  assign w_apt_ones_next = r_apt_ones + r_xor_sync_ff2;
  assign w_apt_fail = w_sample_tick && (r_apt_count == APT_LAST_VALUE) &&
                      ((w_apt_ones_next < APT_LOW_VALUE) ||
                       (w_apt_ones_next > APT_HIGH_VALUE));

  always_ff @(posedge i_trng_clk or negedge i_trng_rst_n) begin
    if (!i_trng_rst_n) begin
      o_trng_data        <= 32'd0;
      o_trng_data_valid  <= 1'b0;
      o_trng_health_fail <= 1'b0;
      r_rct_started      <= 1'b0;
      r_rct_last         <= 1'b0;
      r_rct_count        <= '0;
      r_apt_count        <= '0;
      r_apt_ones         <= '0;
      r_pair_valid       <= 1'b0;
      r_pair_first       <= 1'b0;
      r_vn_count         <= 6'd0;
      r_word_shift       <= 32'd0;
    end else if (i_trng_clear) begin
      o_trng_data        <= 32'd0;
      o_trng_data_valid  <= 1'b0;
      o_trng_health_fail <= 1'b0;
      r_rct_started      <= 1'b0;
      r_rct_count        <= '0;
      r_apt_count        <= '0;
      r_apt_ones         <= '0;
      r_pair_valid       <= 1'b0;
      r_vn_count         <= 6'd0;
      r_word_shift       <= 32'd0;
    end else begin
      if (i_trng_data_pop) begin
        o_trng_data_valid <= 1'b0;
      end else if (!i_trng_enable) begin
        r_rct_started <= 1'b0;
        r_rct_count   <= '0;
        r_apt_count   <= '0;
        r_apt_ones    <= '0;
        r_pair_valid  <= 1'b0;
        r_vn_count    <= 6'd0;
        r_word_shift  <= 32'd0;
      end else if (w_sample_tick) begin
        if (!r_rct_started || (r_xor_sync_ff2 != r_rct_last)) begin
          r_rct_started <= 1'b1;
          r_rct_last    <= r_xor_sync_ff2;
          r_rct_count   <= {{(RCT_COUNT_W-1){1'b0}}, 1'b1};
        end else if (r_rct_count < RCT_CUTOFF_VALUE) begin
          r_rct_count <= r_rct_count + 1'b1;
        end

        if (r_apt_count == APT_LAST_VALUE) begin
          r_apt_count <= '0;
          r_apt_ones  <= '0;
        end else begin
          r_apt_count <= r_apt_count + 1'b1;
          if (r_xor_sync_ff2) begin
            r_apt_ones <= r_apt_ones + 1'b1;
          end
        end

        if (w_rct_fail || w_apt_fail) begin
          o_trng_health_fail <= 1'b1;
          o_trng_data_valid  <= 1'b0;
          r_pair_valid       <= 1'b0;
          r_vn_count         <= 6'd0;
          r_word_shift       <= 32'd0;
        end else if (!r_pair_valid) begin
          r_pair_first <= r_xor_sync_ff2;
          r_pair_valid <= 1'b1;
        end else begin
          r_pair_valid <= 1'b0;
          if (r_pair_first != r_xor_sync_ff2) begin
            r_word_shift <= {r_word_shift[30:0], r_pair_first};
            if (r_vn_count == 6'd31) begin
              o_trng_data       <= {r_word_shift[30:0], r_pair_first};
              o_trng_data_valid <= 1'b1;
              r_vn_count        <= 6'd0;
            end else begin
              r_vn_count <= r_vn_count + 1'b1;
            end
          end
        end
      end
    end
  end

endmodule
