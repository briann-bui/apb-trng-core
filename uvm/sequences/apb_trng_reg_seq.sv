class apb_trng_reg_seq extends apb_trng_base_seq;
  `uvm_object_utils(apb_trng_reg_seq)

  function new(string name = "apb_trng_reg_seq");
    super.new(name);
  endfunction

  task body();
    logic [31:0] data;

    apb_read(ADDR_VERSION, data);
    if (data !== 32'h0005_0001)
      `uvm_error(get_type_name(), $sformatf("VERSION mismatch: 0x%08x", data))

    apb_read(ADDR_OUTPUT_INFO, data);
    if (data[15:0] !== 16'h0820)
      `uvm_error(get_type_name(), $sformatf("OUTPUT_INFO mismatch: 0x%08x", data))

    apb_read(ADDR_CTRL, data);
    if (data[0] !== 1'b0)
      `uvm_error(get_type_name(), "TRNG must be disabled after reset")

    apb_write(ADDR_SAMPLE_DIV, 32'h0000_1234);
    apb_read(ADDR_SAMPLE_DIV, data);
    if (data[15:0] !== 16'h1234)
      `uvm_error(get_type_name(), "SAMPLE_DIV readback mismatch")

    apb_write(ADDR_SOURCE_EN, 32'h0000_005A);
    apb_read(ADDR_SOURCE_EN, data);
    if (data[7:0] !== 8'h5A)
      `uvm_error(get_type_name(), "SOURCE_EN readback mismatch")

    `uvm_info(get_type_name(), "Register sequence passed", UVM_LOW)
  endtask
endclass
