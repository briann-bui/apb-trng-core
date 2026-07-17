`timescale 1ns/1ps

// Self-checking SHA adapter KAT top, located under the shared UVM layout.

module apb_trng_sha256_adapter_tb;
  logic         clk;
  logic         rst_n;
  logic         clear;
  logic         start;
  logic [255:0] message;
  logic [8:0]   message_bits;
  logic         ready;
  logic         digest_valid;
  logic [31:0]  digest_word;
  logic         error;

  always #5 clk = ~clk;

  apb_trng_sha256_adapter dut (
    .i_trng_clk          (clk),
    .i_trng_rst_n        (rst_n),
    .i_trng_clear        (clear),
    .i_trng_start        (start),
    .i_trng_message      (message),
    .i_trng_message_bits (message_bits),
    .o_trng_ready        (ready),
    .o_trng_digest_valid (digest_valid),
    .o_trng_digest_word  (digest_word),
    .o_trng_error        (error)
  );

  task automatic check_hash(
    input logic [255:0] test_message,
    input logic [8:0]   test_bits,
    input logic [31:0]  expected_word
  );
    int timeout;
    begin
      @(negedge clk);
      while (!ready) @(negedge clk);
      message = test_message;
      message_bits = test_bits;
      start = 1'b1;
      @(negedge clk);
      start = 1'b0;

      timeout = 0;
      while (!digest_valid) begin
        @(negedge clk);
        timeout++;
        if (timeout > 100) $fatal(1, "SHA-256 adapter timeout for %0d bits", test_bits);
      end
      if (error) $fatal(1, "SHA-256 core reported an error");
      if (digest_word !== expected_word)
        $fatal(1, "SHA-256 mismatch bits=%0d got=%08x expected=%08x",
               test_bits, digest_word, expected_word);
    end
  endtask

  initial begin
    clk = 1'b0;
    rst_n = 1'b0;
    clear = 1'b0;
    start = 1'b0;
    message = '0;
    message_bits = 9'd64;
    repeat (5) @(posedge clk);
    rst_n = 1'b1;

    // SHA-256("abcdefgh")
    check_hash({64'h6162636465666768, 192'd0}, 9'd64, 32'h9c56cc51);
    // SHA-256("abcdefghijklmnop")
    check_hash({128'h6162636465666768696a6b6c6d6e6f70, 128'd0},
               9'd128, 32'hf39dac6c);
    // SHA-256(bytes 0x00 through 0x1f)
    check_hash(256'h000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f,
               9'd256, 32'h630dcd29);

    $display("PASS: real SHA-256 core conditioning adapter KAT 64/128/256-bit");
    $finish;
  end
endmodule
