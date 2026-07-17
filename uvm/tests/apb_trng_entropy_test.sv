class apb_trng_entropy_test extends apb_trng_base_test;
  `uvm_component_utils(apb_trng_entropy_test)

  function new(string name = "apb_trng_entropy_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    apb_trng_entropy_seq seq;
    phase.raise_objection(this);
    seq = apb_trng_entropy_seq::type_id::create("seq");
    seq.start(m_env.m_agent.m_sequencer);
    phase.drop_objection(this);
  endtask
endclass
