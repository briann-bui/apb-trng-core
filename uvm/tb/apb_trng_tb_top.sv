module apb_trng_tb_top;
  import uvm_pkg::*;
  import apb_trng_uvm_pkg::*;

  logic pclk;
  logic presetn;

  apb_trng_uvm_if apb_vif(.pclk(pclk), .presetn(presetn));

  initial begin
    pclk = 1'b0;
    forever #5 pclk = ~pclk;
  end

  initial begin
    presetn = 1'b0;
    apb_vif.stream_ready = 1'b0;
    repeat (5) @(posedge pclk);
    presetn = 1'b1;
  end

  initial begin
    uvm_config_db#(virtual apb_trng_uvm_if)::set(null, "*", "vif", apb_vif);
    run_test();
  end

  apb_trng_wrapper u_dut (
    .i_trng_pclk          (pclk),
    .i_trng_presetn       (presetn),
    .i_trng_paddr         (apb_vif.paddr),
    .i_trng_psel          (apb_vif.psel),
    .i_trng_penable       (apb_vif.penable),
    .i_trng_pwrite        (apb_vif.pwrite),
    .i_trng_pwdata        (apb_vif.pwdata),
    .i_trng_pstrb         (apb_vif.pstrb),
    .o_trng_prdata        (apb_vif.prdata),
    .o_trng_pready        (apb_vif.pready),
    .o_trng_pslverr       (apb_vif.pslverr),
    .o_trng_irq           (apb_vif.irq),
    .o_trng_stream_data   (apb_vif.stream_data),
    .o_trng_stream_valid  (apb_vif.stream_valid),
    .i_trng_stream_ready  (apb_vif.stream_ready)
  );
endmodule
