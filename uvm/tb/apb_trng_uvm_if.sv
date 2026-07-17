interface apb_trng_uvm_if(input logic pclk, input logic presetn);
  logic [7:0]  paddr;
  logic        psel;
  logic        penable;
  logic        pwrite;
  logic [31:0] pwdata;
  logic [3:0]  pstrb;
  logic [31:0] prdata;
  logic        pready;
  logic        pslverr;
  logic        irq;

  logic [31:0] stream_data;
  logic        stream_valid;
  logic        stream_ready;
endinterface
