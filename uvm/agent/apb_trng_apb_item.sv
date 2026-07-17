class apb_trng_apb_item extends uvm_sequence_item;
  rand bit          write;
  rand bit [7:0]    addr;
  rand bit [31:0]   data;
  rand bit [3:0]    strb;
       logic [31:0] rdata;
       logic        slverr;
       int unsigned wait_cycles;

  constraint c_default_strb { soft strb == 4'hF; }

  `uvm_object_utils_begin(apb_trng_apb_item)
    `uvm_field_int(write, UVM_ALL_ON)
    `uvm_field_int(addr, UVM_ALL_ON)
    `uvm_field_int(data, UVM_ALL_ON)
    `uvm_field_int(strb, UVM_ALL_ON)
    `uvm_field_int(rdata, UVM_ALL_ON)
    `uvm_field_int(slverr, UVM_ALL_ON)
    `uvm_field_int(wait_cycles, UVM_ALL_ON)
  `uvm_object_utils_end

  function new(string name = "apb_trng_apb_item");
    super.new(name);
    strb = 4'hF;
  endfunction
endclass
