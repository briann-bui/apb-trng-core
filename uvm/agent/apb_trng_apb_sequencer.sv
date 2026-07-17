class apb_trng_apb_sequencer extends uvm_sequencer #(apb_trng_apb_item);
  `uvm_component_utils(apb_trng_apb_sequencer)

  function new(string name = "apb_trng_apb_sequencer", uvm_component parent = null);
    super.new(name, parent);
  endfunction
endclass
