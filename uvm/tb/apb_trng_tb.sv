`timescale 1ns/1ps

// Self-checking TRNG regression top, located under the shared UVM layout.

module apb_trng_tb;
  localparam logic [7:0] ADDR_CTRL       = 8'h00;
  localparam logic [7:0] ADDR_STATUS     = 8'h04;
  localparam logic [7:0] ADDR_DATA       = 8'h08;
  localparam logic [7:0] ADDR_HEALTH_CFG = 8'h0C;
  localparam logic [7:0] ADDR_SAMPLE_DIV = 8'h10;
  localparam logic [7:0] ADDR_IRQ_EN     = 8'h14;
  localparam logic [7:0] ADDR_IRQ_STAT   = 8'h18;
  localparam logic [7:0] ADDR_SOURCE_EN  = 8'h24;
  localparam logic [7:0] ADDR_SOURCE_CFG = 8'h28;
  localparam logic [7:0] ADDR_STUCK_LIMIT= 8'h2C;
  localparam logic [7:0] ADDR_SOURCE_FAIL= 8'h30;
  localparam logic [7:0] ADDR_SOURCE_ACT = 8'h34;
  localparam logic [7:0] ADDR_COND_CFG   = 8'h38;
  localparam logic [7:0] ADDR_ENTROPY_CNT= 8'h3C;
  localparam logic [7:0] ADDR_REJECT_CNT = 8'h40;
  localparam logic [7:0] ADDR_OUTPUT_CFG = 8'h44;
  localparam logic [7:0] ADDR_FIFO_LEVEL = 8'h48;
  localparam logic [7:0] ADDR_OUTPUT_INFO= 8'h4C;
  localparam logic [7:0] ADDR_VERSION    = 8'hFC;

  logic        pclk;
  logic        presetn;
  logic [7:0]  paddr;
  logic        psel;
  logic        penable;
  logic        pwrite;
  logic [31:0] pwdata;
  logic [3:0]  pstrb;
  logic [31:0] prdata;
  logic        pready;
  logic        pslverr;
  logic        irq;
  logic [31:0] stream_data;
  logic        stream_valid;
  logic        stream_ready;

  apb_trng_wrapper dut (
    .i_trng_pclk    (pclk),
    .i_trng_presetn (presetn),
    .i_trng_paddr   (paddr),
    .i_trng_psel    (psel),
    .i_trng_penable (penable),
    .i_trng_pwrite  (pwrite),
    .i_trng_pwdata  (pwdata),
    .i_trng_pstrb   (pstrb),
    .o_trng_prdata  (prdata),
    .o_trng_pready  (pready),
    .o_trng_pslverr (pslverr),
    .o_trng_irq     (irq),
    .o_trng_stream_data (stream_data),
    .o_trng_stream_valid(stream_valid),
    .i_trng_stream_ready(stream_ready)
  );

  always #5 pclk = ~pclk;

  task automatic apb_write(input logic [7:0] addr, input logic [31:0] data);
    @(negedge pclk);
    paddr = addr; pwdata = data; pwrite = 1'b1; psel = 1'b1; penable = 1'b0;
    @(negedge pclk);
    penable = 1'b1;
    #1;
    if (!pready || pslverr) $fatal(1, "APB write failed at %02x", addr);
    @(negedge pclk);
    psel = 1'b0; penable = 1'b0; pwrite = 1'b0;
  endtask

  task automatic apb_read(input logic [7:0] addr, output logic [31:0] data);
    @(negedge pclk);
    paddr = addr; pwrite = 1'b0; psel = 1'b1; penable = 1'b0;
    @(negedge pclk);
    penable = 1'b1;
    #1;
    if (!pready || pslverr) $fatal(1, "APB read failed at %02x", addr);
    data = prdata;
    @(negedge pclk);
    psel = 1'b0; penable = 1'b0;
  endtask

  task automatic wait_status_bit(input int bit_index, input int max_polls);
    logic [31:0] value;
    for (int poll = 0; poll < max_polls; poll++) begin
      apb_read(ADDR_STATUS, value);
      if (value[bit_index]) return;
    end
    $fatal(1, "Timeout waiting for STATUS[%0d]", bit_index);
  endtask

  initial begin
    logic [31:0] value;
    logic [31:0] random_word;
    logic [31:0] round_robin_word;
    logic [31:0] stream_word;
    logic [31:0] sha_word;
    logic [31:0] sha_word_2;
    logic [31:0] sha_word_3;

    pclk = 1'b0; presetn = 1'b0; paddr = '0; psel = 1'b0;
    penable = 1'b0; pwrite = 1'b0; pwdata = '0; pstrb = 4'hF;
    stream_ready = 1'b0;
    repeat (5) @(posedge pclk);
    presetn = 1'b1;

    apb_read(ADDR_VERSION, value);
    if (value != 32'h0005_0001) $fatal(1, "Bad VERSION: %08x", value);
    apb_read(ADDR_OUTPUT_INFO, value);
    if (value[15:0] != 16'h0820) $fatal(1, "Bad output width/depth: %08x", value);

    // Empty non-blocking reads return zero and set DATA_NOT_READY.
    apb_read(ADDR_DATA, value);
    if (value != 0) $fatal(1, "Empty non-blocking read returned data");
    apb_read(ADDR_STATUS, value);
    if (!value[6]) $fatal(1, "DATA_NOT_READY status was not set: STATUS=%08x", value);

    // Blocking mode holds PREADY low while the FIFO is empty.
    apb_write(ADDR_OUTPUT_CFG, 32'h0000_0001);
    @(negedge pclk);
    paddr = ADDR_DATA; pwrite = 1'b0; psel = 1'b1; penable = 1'b1;
    #1;
    if (pready) $fatal(1, "Blocking empty read did not apply backpressure");
    @(negedge pclk);
    psel = 1'b0; penable = 1'b0;
    apb_write(ADDR_OUTPUT_CFG, 32'h0000_0000);

    // Fast, permissive configuration for the deterministic RTL surrogate.
    apb_write(ADDR_SAMPLE_DIV, 32'd0);
    apb_write(ADDR_HEALTH_CFG, 32'h0040_0000); // high=64, low=0, RCT off
    apb_write(ADDR_SOURCE_EN, 32'h0000_000F);  // four parallel sources
    apb_write(ADDR_SOURCE_CFG, 32'h0000_0002); // XOR + auto quarantine
    apb_write(ADDR_STUCK_LIMIT, 32'd0);        // disabled for data-path test
    apb_write(ADDR_COND_CFG, 32'h0000_0006);   // CRC + VN + 2x (64 credits)
    apb_write(ADDR_IRQ_EN, 32'h0000_0003);
    apb_write(ADDR_CTRL, 32'h0000_0001);

    apb_read(ADDR_SOURCE_ACT, value);
    if (value[7:0] != 8'h0F) $fatal(1, "Bad active source mask: %08x", value);

    wait_status_bit(1, 400);
    apb_read(ADDR_DATA, random_word);
    if (^random_word === 1'bx) $fatal(1, "TRNG data contains X: %08x", random_word);
    apb_read(ADDR_STATUS, value);
    if (value[1]) $fatal(1, "DATA_VALID did not clear after DATA read");
    apb_read(ADDR_REJECT_CNT, value);
    if (value[15:0] == 0) $fatal(1, "Expected Von Neumann rejected-pair count");

    wait_status_bit(3, 400);
    if (!irq) $fatal(1, "Expected data-ready IRQ");
    apb_write(ADDR_IRQ_STAT, 32'h0000_0001);

    // Round-robin plus LFSR whitening at 4x must clear partial credit and wait
    // for 128 accepted bits before publishing a word.
    apb_write(ADDR_SOURCE_CFG, 32'h0000_0003);
    apb_write(ADDR_COND_CFG, 32'h0000_0015); // LFSR + VN + 4x
    apb_read(ADDR_STATUS, value);
    if (value[1]) $fatal(1, "Conditioner published data before enough entropy");
    apb_read(ADDR_ENTROPY_CNT, value);
    if (value[8:0] >= 128) $fatal(1, "Invalid initial entropy credit: %0d", value[8:0]);
    wait_status_bit(1, 1000);
    apb_read(ADDR_DATA, round_robin_word);
    if (^round_robin_word === 1'bx)
      $fatal(1, "Round-robin TRNG data contains X: %08x", round_robin_word);

    // Streaming mode holds a word stable until READY is asserted.
    apb_write(ADDR_OUTPUT_CFG, 32'h0000_0002);
    for (int cycle = 0; cycle < 2000; cycle++) begin
      @(posedge pclk);
      if (stream_valid) break;
      if (cycle == 1999) $fatal(1, "Timeout waiting for stream VALID");
    end
    stream_word = stream_data;
    repeat (3) begin
      @(posedge pclk);
      if (!stream_valid || (stream_data != stream_word))
        $fatal(1, "Streaming data changed while READY was low");
    end
    stream_ready = 1'b1;
    @(posedge pclk);
    stream_ready = 1'b0;

    // End-to-end SHA-256 conditioning mode (mode=3, VN enabled, 2x). Three
    // consecutive words prove that each digest request is a pulse and that
    // the conditioner resumes collecting a fresh entropy message afterward.
    apb_write(ADDR_OUTPUT_CFG, 32'h0000_0000);
    apb_write(ADDR_COND_CFG, 32'h0000_0007);
    wait_status_bit(1, 1000);
    apb_read(ADDR_DATA, sha_word);
    if (^sha_word === 1'bx) $fatal(1, "SHA-conditioned TRNG data contains X");
    wait_status_bit(1, 1000);
    apb_read(ADDR_DATA, sha_word_2);
    wait_status_bit(1, 1000);
    apb_read(ADDR_DATA, sha_word_3);
    if ((^sha_word_2 === 1'bx) || (^sha_word_3 === 1'bx))
      $fatal(1, "Consecutive SHA-conditioned data contains X");
    if ((sha_word == sha_word_2) || (sha_word_2 == sha_word_3) ||
        (sha_word == sha_word_3))
      $fatal(1, "Deterministic regression produced repeated SHA words: %08x %08x %08x",
             sha_word, sha_word_2, sha_word_3);

    // Queue a complete word and accumulate part of the next one before forcing
    // the only source to fail. Quarantine must atomically discard both states.
    apb_write(ADDR_CTRL, 32'h0000_0003); // clear health state, remain enabled
    apb_write(ADDR_SOURCE_EN, 32'h0000_0001);
    apb_write(ADDR_COND_CFG, 32'h0000_0006); // CRC + VN + 2x
    apb_write(ADDR_STUCK_LIMIT, 32'd0);
    wait_status_bit(1, 1000);
    for (int poll = 0; poll < 200; poll++) begin
      apb_read(ADDR_ENTROPY_CNT, value);
      if (value[8:0] != 0) break;
      if (poll == 199) $fatal(1, "No partial entropy accumulated before source-fail test");
    end
    apb_write(ADDR_STUCK_LIMIT, 32'd2);
    wait_status_bit(4, 100);
    apb_read(ADDR_SOURCE_FAIL, value);
    if (!value[0]) $fatal(1, "Expected source 0 to be quarantined");
    apb_read(ADDR_STATUS, value);
    if (value[1] || !value[8])
      $fatal(1, "Source failure did not flush output FIFO: STATUS=%08x", value);
    apb_read(ADDR_FIFO_LEVEL, value);
    if (value[6:0] != 0) $fatal(1, "FIFO not empty after source failure: %0d", value[6:0]);
    apb_read(ADDR_ENTROPY_CNT, value);
    if (value[8:0] != 0)
      $fatal(1, "Entropy credit not cleared after source failure: %0d", value[8:0]);
    wait_status_bit(2, 20); // no source remains, so global health failure follows
    apb_read(ADDR_IRQ_STAT, value);
    if (!value[1]) $fatal(1, "Expected health-fail IRQ status");

    $display("PASS: XOR=%08x RR=%08x STREAM=%08x SHA=%08x/%08x/%08x; FIFO/backpressure/source-fail flush passed",
             random_word, round_robin_word, stream_word,
             sha_word, sha_word_2, sha_word_3);
    $finish;
  end

endmodule
