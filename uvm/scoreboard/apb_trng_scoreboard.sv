class apb_trng_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(apb_trng_scoreboard)

  uvm_analysis_imp #(apb_trng_apb_item, apb_trng_scoreboard) analysis_export;
  int unsigned read_count;
  int unsigned write_count;
  int unsigned data_read_count;

  function new(string name = "apb_trng_scoreboard", uvm_component parent = null);
    super.new(name, parent);
    analysis_export = new("analysis_export", this);
  endfunction

  function void write(apb_trng_apb_item tr);
    if (tr.slverr !== 1'b0)
      `uvm_error(get_type_name(), $sformatf("Unexpected PSLVERR at address 0x%02x", tr.addr))

    if (tr.write) begin
      write_count++;
    end else begin
      read_count++;
      if (tr.addr == 8'h08)
        data_read_count++;
      if ((tr.addr == 8'hFC) && (tr.rdata !== 32'h0005_0001))
        `uvm_error(get_type_name(), $sformatf("VERSION mismatch: 0x%08x", tr.rdata))
      if ((tr.addr == 8'h4C) && (tr.rdata[15:0] !== 16'h0820))
        `uvm_error(get_type_name(), $sformatf("OUTPUT_INFO mismatch: 0x%08x", tr.rdata))
    end
  endfunction

  function void report_phase(uvm_phase phase);
    `uvm_info(get_type_name(),
      $sformatf("Observed APB writes=%0d reads=%0d DATA reads=%0d",
                write_count, read_count, data_read_count), UVM_LOW)
    if ((read_count == 0) || (write_count == 0))
      `uvm_error(get_type_name(), "Regression did not exercise both APB reads and writes")
  endfunction
endclass
