class apb_trng_apb_driver extends uvm_driver #(apb_trng_apb_item);
  `uvm_component_utils(apb_trng_apb_driver)

  virtual apb_trng_uvm_if vif;

  function new(string name = "apb_trng_apb_driver", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual apb_trng_uvm_if)::get(this, "", "vif", vif))
      `uvm_fatal(get_type_name(), "virtual APB interface not set")
  endfunction

  task run_phase(uvm_phase phase);
    apb_trng_apb_item tr;
    drive_idle();
    @(posedge vif.presetn);
    forever begin
      seq_item_port.get_next_item(tr);
      drive_transfer(tr);
      seq_item_port.item_done();
    end
  endtask

  task drive_idle();
    vif.paddr   <= '0;
    vif.psel    <= 1'b0;
    vif.penable <= 1'b0;
    vif.pwrite  <= 1'b0;
    vif.pwdata  <= '0;
    vif.pstrb   <= 4'hF;
  endtask

  task drive_transfer(apb_trng_apb_item tr);
    int unsigned timeout;
    timeout = 0;

    @(posedge vif.pclk);
    vif.paddr   <= tr.addr;
    vif.pwrite  <= tr.write;
    vif.pwdata  <= tr.data;
    vif.pstrb   <= tr.strb;
    vif.psel    <= 1'b1;
    vif.penable <= 1'b0;

    @(posedge vif.pclk);
    vif.penable <= 1'b1;
    do begin
      @(posedge vif.pclk);
      timeout++;
      if (timeout > 10000)
        `uvm_fatal(get_type_name(), $sformatf("APB timeout at address 0x%02x", tr.addr))
    end while (!vif.pready);

    tr.rdata       = vif.prdata;
    tr.slverr      = vif.pslverr;
    tr.wait_cycles = timeout - 1;
    drive_idle();
  endtask
endclass
