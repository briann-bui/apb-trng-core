class apb_trng_env extends uvm_env;
  `uvm_component_utils(apb_trng_env)

  apb_trng_agent      m_agent;
  apb_trng_scoreboard m_scoreboard;

  function new(string name = "apb_trng_env", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    m_agent      = apb_trng_agent::type_id::create("m_agent", this);
    m_scoreboard = apb_trng_scoreboard::type_id::create("m_scoreboard", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    m_agent.m_monitor.ap.connect(m_scoreboard.analysis_export);
  endfunction
endclass
