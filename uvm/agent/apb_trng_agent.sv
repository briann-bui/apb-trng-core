class apb_trng_agent extends uvm_agent;
  `uvm_component_utils(apb_trng_agent)

  apb_trng_apb_sequencer m_sequencer;
  apb_trng_apb_driver    m_driver;
  apb_trng_apb_monitor   m_monitor;

  function new(string name = "apb_trng_agent", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    m_sequencer = apb_trng_apb_sequencer::type_id::create("m_sequencer", this);
    m_driver    = apb_trng_apb_driver::type_id::create("m_driver", this);
    m_monitor   = apb_trng_apb_monitor::type_id::create("m_monitor", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    m_driver.seq_item_port.connect(m_sequencer.seq_item_export);
  endfunction
endclass
