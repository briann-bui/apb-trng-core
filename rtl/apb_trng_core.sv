module apb_trng_core #(
  parameter int NUM_RO      = 8,
  parameter int BASE_STAGES = 7
) (
  input  logic              i_trng_clk,
  input  logic              i_trng_rst_n,
  input  logic              i_trng_enable,
  input  logic              i_trng_clear,
  input  logic [NUM_RO-1:0] i_trng_source_enable,
  input  logic              i_trng_combine_mode,
  input  logic              i_trng_auto_quarantine,
  input  logic [15:0]       i_trng_stuck_limit,
  input  logic [1:0]        i_trng_condition_mode,
  input  logic              i_trng_vn_enable,
  input  logic [1:0]        i_trng_oversample_sel,
  input  logic [15:0]       i_trng_sample_div,
  input  logic [7:0]        i_trng_rep_limit,
  input  logic [7:0]        i_trng_prop_low,
  input  logic [7:0]        i_trng_prop_high,
  input  logic              i_trng_data_pop,
  output logic [31:0]       o_trng_data,
  output logic              o_trng_data_valid,
  output logic              o_trng_health_fail,
  output logic              o_trng_word_pulse,
  output logic              o_trng_health_pulse,
  output logic [15:0]       o_trng_health_count,
  output logic [8:0]        o_trng_entropy_credit,
  output logic [15:0]       o_trng_reject_count,
  output logic [NUM_RO-1:0] o_trng_ro_sample,
  output logic [NUM_RO-1:0] o_trng_source_fail,
  output logic              o_trng_source_fail_pulse,
  output logic [NUM_RO-1:0] o_trng_source_active
);

  localparam int SOURCE_INDEX_WIDTH = (NUM_RO <= 1) ? 1 : $clog2(NUM_RO);

  logic [15:0] r_sample_count;
  logic        w_sample_tick;
  logic        w_raw_bit;
  logic        w_xor_mixed_bit;
  logic        r_raw_previous;
  logic [7:0]  r_repeat_count;
  logic [6:0]  r_window_count;
  logic [6:0]  r_window_ones;
  logic        w_rep_fail;
  logic        w_prop_fail;
  logic        w_raw_valid;
  logic        w_raw_reject;
  logic [NUM_RO-1:0] w_ro_enable;
  logic [NUM_RO-1:0] w_source_fail_now;
  logic [NUM_RO-1:0] w_source_new_fail;
  logic [NUM_RO-1:0] r_source_previous;
  logic [15:0] r_source_stuck_count [NUM_RO];
  logic [6:0]  r_source_ones [NUM_RO];
  logic [SOURCE_INDEX_WIDTH-1:0] r_source_index;
  logic [SOURCE_INDEX_WIDTH-1:0] w_selected_index;
  logic        w_selected_valid;

  apb_trng_entropy_bank #(
    .NUM_RO      (NUM_RO),
    .BASE_STAGES (BASE_STAGES)
  ) u_trng_entropy_bank (
    .i_trng_clk       (i_trng_clk),
    .i_trng_rst_n     (i_trng_rst_n),
    .i_trng_ro_enable (w_ro_enable),
    .o_trng_ro_sample (o_trng_ro_sample)
  );

  apb_trng_entropy_mixer #(
    .NUM_SOURCES (NUM_RO)
  ) u_trng_entropy_mixer (
    .i_trng_source_bits (o_trng_ro_sample),
    .i_trng_source_mask (o_trng_source_active),
    .o_trng_xor_bit     (w_xor_mixed_bit)
  );

  apb_trng_conditioner u_trng_conditioner (
    .i_trng_clk              (i_trng_clk),
    .i_trng_rst_n            (i_trng_rst_n),
    // Discard every partial conditioned block as soon as a source is newly
    // declared unhealthy. Healthy sources may continue after quarantine, but
    // no data influenced by the failed source is retained.
    .i_trng_clear            (i_trng_clear || o_trng_source_fail_pulse),
    .i_trng_block            (o_trng_health_fail),
    .i_trng_raw_valid        (w_raw_valid),
    .i_trng_raw_bit          (w_raw_bit),
    .i_trng_raw_reject       (w_raw_reject),
    .i_trng_condition_mode   (i_trng_condition_mode),
    .i_trng_vn_enable        (i_trng_vn_enable),
    .i_trng_oversample_sel   (i_trng_oversample_sel),
    .i_trng_data_pop         (i_trng_data_pop),
    .o_trng_data             (o_trng_data),
    .o_trng_data_valid       (o_trng_data_valid),
    .o_trng_word_pulse       (o_trng_word_pulse),
    .o_trng_entropy_credit   (o_trng_entropy_credit),
    .o_trng_reject_count     (o_trng_reject_count)
  );

  assign o_trng_source_active = i_trng_source_enable &
                                (i_trng_auto_quarantine ? ~o_trng_source_fail : {NUM_RO{1'b1}});
  assign w_ro_enable   = o_trng_source_active & {NUM_RO{i_trng_enable}};
  assign w_sample_tick = i_trng_enable && (|o_trng_source_active) &&
                         (r_sample_count >= i_trng_sample_div);

  // Mode 0 mixes every active source. Mode 1 samples one active source in
  // round-robin order, which is useful for characterization and diagnostics.
  always_comb begin
    integer source_offset;
    integer source_candidate;
    w_selected_valid = 1'b0;
    w_selected_index = '0;
    for (source_offset = 0; source_offset < NUM_RO; source_offset++) begin
      source_candidate = {{(32-SOURCE_INDEX_WIDTH){1'b0}}, r_source_index} + source_offset;
      if (source_candidate >= NUM_RO) source_candidate = source_candidate - NUM_RO;
      if (!w_selected_valid && o_trng_source_active[source_candidate]) begin
        w_selected_valid = 1'b1;
        w_selected_index = source_candidate[SOURCE_INDEX_WIDTH-1:0];
      end
    end
  end

  always_comb begin
    if (!i_trng_combine_mode)
      w_raw_bit = w_xor_mixed_bit;
    else if (w_selected_valid)
      w_raw_bit = o_trng_ro_sample[w_selected_index];
    else
      w_raw_bit = 1'b0;
  end

  // Each source gets an independent stuck detector and 64-sample proportion
  // test. A failed source is sticky and can be automatically quarantined.
  always_comb begin
    integer source_id;
    w_source_fail_now = '0;
    for (source_id = 0; source_id < NUM_RO; source_id++) begin
      if (w_sample_tick && i_trng_source_enable[source_id]) begin
        if ((i_trng_stuck_limit != 0) &&
            (o_trng_ro_sample[source_id] == r_source_previous[source_id]) &&
            (r_source_stuck_count[source_id] >= (i_trng_stuck_limit - 1'b1)))
          w_source_fail_now[source_id] = 1'b1;

        if ((r_window_count == 7'd63) &&
            (((r_source_ones[source_id] + o_trng_ro_sample[source_id]) < i_trng_prop_low) ||
             ((r_source_ones[source_id] + o_trng_ro_sample[source_id]) > i_trng_prop_high)))
          w_source_fail_now[source_id] = 1'b1;
      end
    end
  end

  assign w_source_new_fail = w_source_fail_now & ~o_trng_source_fail;
  assign o_trng_source_fail_pulse = |w_source_new_fail;
  assign w_rep_fail = w_sample_tick && (w_raw_bit == r_raw_previous) &&
                      (r_repeat_count >= (i_trng_rep_limit - 1'b1)) &&
                      (i_trng_rep_limit != 0);
  assign w_prop_fail = w_sample_tick && (r_window_count == 7'd63) &&
                       (((r_window_ones + w_raw_bit) < i_trng_prop_low) ||
                        ((r_window_ones + w_raw_bit) > i_trng_prop_high));
  assign w_raw_valid  = w_sample_tick && !w_rep_fail && !w_prop_fail &&
                        !(|w_source_new_fail);
  assign w_raw_reject = w_sample_tick && (w_rep_fail || w_prop_fail ||
                                           (|w_source_new_fail));

  always_ff @(posedge i_trng_clk or negedge i_trng_rst_n) begin
    integer source_id;
    if (!i_trng_rst_n) begin
      r_sample_count       <= 16'd0;
      r_raw_previous       <= 1'b0;
      r_repeat_count       <= 8'd0;
      r_window_count       <= 7'd0;
      r_window_ones        <= 7'd0;
      r_source_previous    <= '0;
      r_source_index       <= '0;
      o_trng_source_fail   <= '0;
      o_trng_health_fail   <= 1'b0;
      o_trng_health_pulse  <= 1'b0;
      o_trng_health_count  <= 16'd0;
      for (source_id = 0; source_id < NUM_RO; source_id++) begin
        r_source_stuck_count[source_id] <= 16'd0;
        r_source_ones[source_id]        <= 7'd0;
      end
    end else begin
      o_trng_health_pulse <= 1'b0;

      if (i_trng_clear) begin
        r_sample_count       <= 16'd0;
        r_repeat_count       <= 8'd0;
        r_window_count       <= 7'd0;
        r_window_ones        <= 7'd0;
        r_source_previous    <= o_trng_ro_sample;
        o_trng_source_fail   <= '0;
        o_trng_health_fail   <= 1'b0;
        o_trng_health_count  <= 16'd0;
        for (source_id = 0; source_id < NUM_RO; source_id++) begin
          r_source_stuck_count[source_id] <= 16'd0;
          r_source_ones[source_id]        <= 7'd0;
        end
      end else begin
        if (!i_trng_enable) begin
          r_sample_count <= 16'd0;
        end else if (!(|o_trng_source_active)) begin
          o_trng_health_fail  <= 1'b1;
          o_trng_health_pulse <= !o_trng_health_fail;
          if (!o_trng_health_fail && (o_trng_health_count != 16'hFFFF))
            o_trng_health_count <= o_trng_health_count + 1'b1;
        end else if (w_sample_tick) begin
          r_sample_count <= 16'd0;

          if ({{(32-SOURCE_INDEX_WIDTH){1'b0}}, w_selected_index} == (NUM_RO-1))
            r_source_index <= '0;
          else r_source_index <= w_selected_index + 1'b1;

          for (source_id = 0; source_id < NUM_RO; source_id++) begin
            if (!i_trng_source_enable[source_id]) begin
              r_source_stuck_count[source_id] <= 16'd0;
              r_source_ones[source_id]        <= 7'd0;
            end else begin
              if (o_trng_ro_sample[source_id] != r_source_previous[source_id])
                r_source_stuck_count[source_id] <= 16'd0;
              else if (r_source_stuck_count[source_id] != 16'hFFFF)
                r_source_stuck_count[source_id] <= r_source_stuck_count[source_id] + 1'b1;

              if (r_window_count == 7'd63)
                r_source_ones[source_id] <= 7'd0;
              else
                r_source_ones[source_id] <= r_source_ones[source_id] + o_trng_ro_sample[source_id];
            end
          end
          r_source_previous <= o_trng_ro_sample;
          o_trng_source_fail <= o_trng_source_fail | w_source_fail_now;

          if (w_raw_bit == r_raw_previous) begin
            if (r_repeat_count != 8'hFF) r_repeat_count <= r_repeat_count + 1'b1;
          end else begin
            r_raw_previous <= w_raw_bit;
            r_repeat_count <= 8'd1;
          end

          if (r_window_count == 7'd63) begin
            r_window_count <= 7'd0;
            r_window_ones  <= 7'd0;
          end else begin
            r_window_count <= r_window_count + 1'b1;
            r_window_ones  <= r_window_ones + w_raw_bit;
          end

          if (w_rep_fail || w_prop_fail) begin
            o_trng_health_fail <= 1'b1;
          end

          if (w_rep_fail || w_prop_fail || (|w_source_new_fail)) begin
            o_trng_health_pulse <= 1'b1;
            if (o_trng_health_count != 16'hFFFF)
              o_trng_health_count <= o_trng_health_count + 1'b1;
          end
        end else begin
          r_sample_count <= r_sample_count + 1'b1;
        end
      end
    end
  end

endmodule
