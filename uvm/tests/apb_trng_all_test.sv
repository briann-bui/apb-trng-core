class apb_trng_all_test extends apb_trng_base_test;
  `uvm_component_utils(apb_trng_all_test)

  function new(string name = "apb_trng_all_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    apb_trng_reg_seq     reg_seq;
    apb_trng_entropy_seq entropy_seq;
    apb_trng_health_seq  health_seq;

    phase.raise_objection(this);
    reg_seq     = apb_trng_reg_seq::type_id::create("reg_seq");
    entropy_seq = apb_trng_entropy_seq::type_id::create("entropy_seq");
    health_seq  = apb_trng_health_seq::type_id::create("health_seq");

    reg_seq.start(m_env.m_agent.m_sequencer);
    entropy_seq.start(m_env.m_agent.m_sequencer);
    health_seq.start(m_env.m_agent.m_sequencer);
    phase.drop_objection(this);
  endtask
endclass
