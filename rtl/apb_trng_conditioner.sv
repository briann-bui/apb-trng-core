module apb_trng_conditioner (
  input  logic        i_trng_clk,
  input  logic        i_trng_rst_n,
  input  logic        i_trng_clear,
  input  logic        i_trng_block,
  input  logic        i_trng_raw_valid,
  input  logic        i_trng_raw_bit,
  input  logic        i_trng_raw_reject,
  input  logic [1:0]  i_trng_condition_mode,
  input  logic        i_trng_vn_enable,
  input  logic [1:0]  i_trng_oversample_sel,
  input  logic        i_trng_data_pop,
  output logic [31:0] o_trng_data,
  output logic        o_trng_data_valid,
  output logic        o_trng_word_pulse,
  output logic [8:0]  o_trng_entropy_credit,
  output logic [15:0] o_trng_reject_count
);

  logic        r_pair_valid;
  logic        r_pair_first;
  logic [31:0] r_accumulator;
  logic [8:0]  r_credit_count;
  logic [31:0] r_data;
  logic        r_data_valid;
  logic [15:0] r_reject_count;
  logic [4:0]  r_config;
  logic [4:0]  w_config;
  logic [8:0]  w_required_bits;
  logic        w_emit_bit;
  logic        w_emit_value;
  logic        w_lfsr_feedback;
  logic        w_crc_feedback;
  logic [31:0] w_accumulator_next;
  logic [255:0] r_sha_message;
  logic [255:0] w_sha_message_next;
  logic         r_sha_start;
  logic         w_sha_ready;
  logic         w_sha_digest_valid;
  logic [31:0]  w_sha_digest_word;
  logic         w_sha_error;

  function automatic logic [31:0] condition_seed(input logic [1:0] mode);
    case (mode)
      2'd0: condition_seed = 32'd0;         // XOR folding
      2'd1: condition_seed = 32'hA5C3_7E29; // LFSR whitening
      default: condition_seed = 32'h1D87_2B41; // CRC conditioning
    endcase
  endfunction

  assign w_config = {i_trng_oversample_sel, i_trng_vn_enable,
                     i_trng_condition_mode};

  always_comb begin
    unique case (i_trng_oversample_sel)
      2'd0: w_required_bits = 9'd64;  // 2 accepted bits/output bit
      2'd1: w_required_bits = 9'd128; // 4 accepted bits/output bit
      default: w_required_bits = 9'd256; // 8 accepted bits/output bit
    endcase
  end

  // Von Neumann: 01 -> 0, 10 -> 1, while 00 and 11 are discarded.
  assign w_emit_bit = i_trng_raw_valid && !r_data_valid &&
                      ((i_trng_condition_mode != 2'd3) ||
                       (w_sha_ready && !r_sha_start)) &&
                      (!i_trng_vn_enable ||
                       (r_pair_valid && (r_pair_first != i_trng_raw_bit)));
  assign w_emit_value = i_trng_vn_enable ? r_pair_first : i_trng_raw_bit;
  assign w_lfsr_feedback = r_accumulator[31] ^ w_emit_value;
  assign w_crc_feedback  = r_accumulator[31] ^ w_emit_value;

  always_comb begin
    w_sha_message_next = r_sha_message;
    w_sha_message_next[255-r_credit_count] = w_emit_value;
  end

  apb_trng_sha256_adapter u_trng_sha256_adapter (
    .i_trng_clk          (i_trng_clk),
    .i_trng_rst_n        (i_trng_rst_n),
    .i_trng_clear        (i_trng_clear || i_trng_block || (r_config != w_config)),
    .i_trng_start        (r_sha_start),
    .i_trng_message      (r_sha_message),
    .i_trng_message_bits (w_required_bits),
    .o_trng_ready        (w_sha_ready),
    .o_trng_digest_valid (w_sha_digest_valid),
    .o_trng_digest_word  (w_sha_digest_word),
    .o_trng_error        (w_sha_error)
  );

  always_comb begin
    w_accumulator_next = r_accumulator;
    unique case (i_trng_condition_mode)
      2'd0: begin
        w_accumulator_next[r_credit_count[4:0]] =
          r_accumulator[r_credit_count[4:0]] ^ w_emit_value;
      end
      2'd1: begin
        w_accumulator_next = {r_accumulator[30:0], 1'b0} ^
          (w_lfsr_feedback ? 32'h0040_0007 : 32'd0);
      end
      default: begin
        w_accumulator_next = {r_accumulator[30:0], 1'b0} ^
          (w_crc_feedback ? 32'h04C1_1DB7 : 32'd0);
      end
    endcase
  end

  always_ff @(posedge i_trng_clk or negedge i_trng_rst_n) begin
    if (!i_trng_rst_n) begin
      r_pair_valid    <= 1'b0;
      r_pair_first    <= 1'b0;
      r_accumulator   <= 32'h1D87_2B41;
      r_credit_count  <= 9'd0;
      r_data          <= 32'd0;
      r_data_valid    <= 1'b0;
      r_reject_count  <= 16'd0;
      r_config        <= 5'b00110; // 2x, VN enabled, CRC
      r_sha_message   <= 256'd0;
      r_sha_start     <= 1'b0;
      o_trng_word_pulse <= 1'b0;
    end else begin
      o_trng_word_pulse <= 1'b0;
      // START is a one-cycle request. Holding it high would make the adapter
      // re-hash a cleared message without collecting a fresh entropy block.
      r_sha_start       <= 1'b0;

      if (i_trng_clear || i_trng_block || (r_config != w_config)) begin
        r_pair_valid   <= 1'b0;
        r_accumulator  <= condition_seed(i_trng_condition_mode);
        r_credit_count <= 9'd0;
        r_data_valid   <= 1'b0;
        r_config       <= w_config;
        r_sha_message  <= 256'd0;
        if (i_trng_clear) r_reject_count <= 16'd0;
      end else begin
        if (i_trng_data_pop) r_data_valid <= 1'b0;

        if (i_trng_raw_reject && (r_reject_count != 16'hFFFF))
          r_reject_count <= r_reject_count + 1'b1;

        if (w_sha_digest_valid && (i_trng_condition_mode == 2'd3)) begin
          r_data             <= w_sha_digest_word;
          r_data_valid       <= 1'b1;
          r_sha_message      <= 256'd0;
          o_trng_word_pulse  <= 1'b1;
        end

        if (w_sha_error && (r_reject_count != 16'hFFFF))
          r_reject_count <= r_reject_count + 1'b1;

        if (i_trng_raw_valid && !r_data_valid &&
            ((i_trng_condition_mode != 2'd3) ||
             (w_sha_ready && !r_sha_start))) begin
          if (i_trng_vn_enable) begin
            if (!r_pair_valid) begin
              r_pair_first <= i_trng_raw_bit;
              r_pair_valid <= 1'b1;
            end else begin
              r_pair_valid <= 1'b0;
              if ((r_pair_first == i_trng_raw_bit) &&
                  (r_reject_count != 16'hFFFF))
                r_reject_count <= r_reject_count + 1'b1;
            end
          end else begin
            r_pair_valid <= 1'b0;
          end

          if (w_emit_bit) begin
            if (i_trng_condition_mode == 2'd3) begin
              r_sha_message <= w_sha_message_next;
              if (r_credit_count == (w_required_bits - 1'b1)) begin
                r_credit_count <= 9'd0;
                r_sha_start    <= 1'b1;
              end else begin
                r_credit_count <= r_credit_count + 1'b1;
              end
            end else begin
              r_accumulator <= w_accumulator_next;
              if (r_credit_count == (w_required_bits - 1'b1)) begin
                r_data             <= w_accumulator_next;
                r_data_valid       <= 1'b1;
                r_accumulator      <= condition_seed(i_trng_condition_mode);
                r_credit_count     <= 9'd0;
                o_trng_word_pulse  <= 1'b1;
              end else begin
                r_credit_count <= r_credit_count + 1'b1;
              end
            end
          end
        end
      end
    end
  end

  assign o_trng_data           = r_data;
  assign o_trng_data_valid     = r_data_valid && !i_trng_block;
  assign o_trng_entropy_credit = r_credit_count;
  assign o_trng_reject_count   = r_reject_count;

endmodule
