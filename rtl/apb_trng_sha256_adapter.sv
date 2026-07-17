module apb_trng_sha256_adapter (
  input  logic         i_trng_clk,
  input  logic         i_trng_rst_n,
  input  logic         i_trng_clear,
  input  logic         i_trng_start,
  input  logic [255:0] i_trng_message,
  input  logic [8:0]   i_trng_message_bits,
  output logic         o_trng_ready,
  output logic         o_trng_digest_valid,
  output logic [31:0]  o_trng_digest_word,
  output logic         o_trng_error
);

  logic [511:0] r_sha_block;
  logic [511:0] w_padded_block;
  logic [63:0]  r_message_bits;
  logic         r_core_start;
  logic         r_core_block_valid;
  logic         r_waiting;
  logic         w_core_block_ready;
  logic         w_core_busy;
  logic         w_core_done;
  logic         w_core_error;
  logic         w_core_digest_valid;
  logic [255:0] w_core_digest;

  // The entropy message occupies the most-significant bits. This constructs
  // the standard single-block SHA-256 padding: message || 1 || 0* || length.
  always_comb begin
    integer message_index;
    w_padded_block = 512'd0;
    for (message_index = 0; message_index < 256; message_index++) begin
      if (message_index < i_trng_message_bits)
        w_padded_block[511-message_index] = i_trng_message[255-message_index];
    end
    w_padded_block[511-i_trng_message_bits] = 1'b1;
    w_padded_block[63:0] = {55'd0, i_trng_message_bits};
  end

  assign o_trng_ready = w_core_block_ready && !w_core_busy && !r_waiting;

  always_ff @(posedge i_trng_clk or negedge i_trng_rst_n) begin
    if (!i_trng_rst_n) begin
      r_sha_block          <= 512'd0;
      r_message_bits       <= 64'd0;
      r_core_start         <= 1'b0;
      r_core_block_valid   <= 1'b0;
      r_waiting            <= 1'b0;
      o_trng_digest_valid  <= 1'b0;
      o_trng_digest_word   <= 32'd0;
      o_trng_error         <= 1'b0;
    end else begin
      r_core_start        <= 1'b0;
      o_trng_digest_valid <= 1'b0;

      if (i_trng_clear) begin
        r_core_block_valid <= 1'b0;
        r_waiting          <= 1'b0;
        o_trng_error       <= 1'b0;
      end else begin
        if (i_trng_start && o_trng_ready) begin
          r_sha_block        <= w_padded_block;
          r_message_bits     <= {55'd0, i_trng_message_bits};
          r_core_start       <= 1'b1;
          r_core_block_valid <= 1'b1;
          r_waiting          <= 1'b1;
        end

        if (r_core_block_valid && !w_core_block_ready)
          r_core_block_valid <= 1'b0;

        if (w_core_error) begin
          o_trng_error <= 1'b1;
          r_waiting    <= 1'b0;
        end

        if (w_core_digest_valid && r_waiting) begin
          // A 32-bit truncation preserves the configured 2x/4x/8x entropy
          // budget. Emitting all 256 digest bits would overstate entropy.
          o_trng_digest_word  <= w_core_digest[255:224];
          o_trng_digest_valid <= 1'b1;
          r_waiting           <= 1'b0;
        end
      end
    end
  end

  apb_trng_sha256_core u_trng_sha256_core (
    .i_trng_sha256_clk          (i_trng_clk),
    .i_trng_sha256_rst_n        (i_trng_rst_n),
    .i_trng_sha256_start        (r_core_start),
    .i_trng_sha256_init         (1'b1),
    .i_trng_sha256_next         (1'b0),
    .i_trng_sha256_final        (1'b1),
    .i_trng_sha256_mode         (2'b00),
    .i_trng_sha256_block_valid  (r_core_block_valid),
    .i_trng_sha256_block        (r_sha_block),
    .i_trng_sha256_msg_bit_len  (r_message_bits),
    .o_trng_sha256_block_ready  (w_core_block_ready),
    .o_trng_sha256_busy         (w_core_busy),
    .o_trng_sha256_done         (w_core_done),
    .o_trng_sha256_error        (w_core_error),
    .o_trng_sha256_digest_valid (w_core_digest_valid),
    .o_trng_sha256_digest       (w_core_digest)
  );

endmodule
