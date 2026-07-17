class apb_trng_health_seq extends apb_trng_base_seq;
  `uvm_object_utils(apb_trng_health_seq)

  function new(string name = "apb_trng_health_seq");
    super.new(name);
  endfunction

  task body();
    logic [31:0] value;
    bit partial_seen;

    partial_seen = 1'b0;
    apb_write(ADDR_CTRL, 32'h0000_0003);
    apb_write(ADDR_HEALTH_CFG, 32'h0040_0000);
    apb_write(ADDR_SAMPLE_DIV, 32'd0);
    apb_write(ADDR_SOURCE_EN, 32'h0000_0001);
    apb_write(ADDR_SOURCE_CFG, 32'h0000_0002);
    apb_write(ADDR_COND_CFG, 32'h0000_0006);
    apb_write(ADDR_STUCK_LIMIT, 32'd0);

    wait_status_bit(1, 1000);
    for (int poll = 0; poll < 200; poll++) begin
      apb_read(ADDR_ENTROPY_CNT, value);
      if (value[8:0] != 0) begin
        partial_seen = 1'b1;
        break;
      end
    end
    if (!partial_seen)
      `uvm_fatal(get_type_name(), "No partial entropy before source-fail test")

    apb_write(ADDR_STUCK_LIMIT, 32'd2);
    wait_status_bit(4, 100);

    apb_read(ADDR_SOURCE_FAIL, value);
    if (!value[0])
      `uvm_error(get_type_name(), "Source 0 was not quarantined")

    apb_read(ADDR_STATUS, value);
    if (value[1] || !value[8])
      `uvm_error(get_type_name(), $sformatf("FIFO flush failed: STATUS=0x%08x", value))

    apb_read(ADDR_FIFO_LEVEL, value);
    if (value[6:0] != 0)
      `uvm_error(get_type_name(), $sformatf("FIFO level after failure=%0d", value[6:0]))

    apb_read(ADDR_ENTROPY_CNT, value);
    if (value[8:0] != 0)
      `uvm_error(get_type_name(), $sformatf("Entropy credit after failure=%0d", value[8:0]))

    wait_status_bit(2, 20);
    `uvm_info(get_type_name(), "Health/quarantine/flush sequence passed", UVM_LOW)
  endtask
endclass
