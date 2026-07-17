class apb_trng_base_seq extends uvm_sequence #(apb_trng_apb_item);
  `uvm_object_utils(apb_trng_base_seq)

  localparam bit [7:0] ADDR_CTRL        = 8'h00;
  localparam bit [7:0] ADDR_STATUS      = 8'h04;
  localparam bit [7:0] ADDR_DATA        = 8'h08;
  localparam bit [7:0] ADDR_HEALTH_CFG  = 8'h0C;
  localparam bit [7:0] ADDR_SAMPLE_DIV  = 8'h10;
  localparam bit [7:0] ADDR_IRQ_EN      = 8'h14;
  localparam bit [7:0] ADDR_IRQ_STAT    = 8'h18;
  localparam bit [7:0] ADDR_SOURCE_EN   = 8'h24;
  localparam bit [7:0] ADDR_SOURCE_CFG  = 8'h28;
  localparam bit [7:0] ADDR_STUCK_LIMIT = 8'h2C;
  localparam bit [7:0] ADDR_SOURCE_FAIL = 8'h30;
  localparam bit [7:0] ADDR_SOURCE_ACT  = 8'h34;
  localparam bit [7:0] ADDR_COND_CFG    = 8'h38;
  localparam bit [7:0] ADDR_ENTROPY_CNT = 8'h3C;
  localparam bit [7:0] ADDR_OUTPUT_CFG  = 8'h44;
  localparam bit [7:0] ADDR_FIFO_LEVEL  = 8'h48;
  localparam bit [7:0] ADDR_OUTPUT_INFO = 8'h4C;
  localparam bit [7:0] ADDR_VERSION     = 8'hFC;

  function new(string name = "apb_trng_base_seq");
    super.new(name);
  endfunction

  task apb_write(bit [7:0] addr, bit [31:0] data, bit [3:0] strb = 4'hF);
    apb_trng_apb_item tr;
    tr = apb_trng_apb_item::type_id::create("wr");
    start_item(tr);
    tr.write = 1'b1;
    tr.addr  = addr;
    tr.data  = data;
    tr.strb  = strb;
    finish_item(tr);
    if (tr.slverr !== 1'b0)
      `uvm_error(get_type_name(), $sformatf("APB write failed at 0x%02x", addr))
  endtask

  task apb_read(bit [7:0] addr, output logic [31:0] data);
    apb_trng_apb_item tr;
    tr = apb_trng_apb_item::type_id::create("rd");
    start_item(tr);
    tr.write = 1'b0;
    tr.addr  = addr;
    tr.data  = 32'd0;
    tr.strb  = 4'hF;
    finish_item(tr);
    data = tr.rdata;
    if (tr.slverr !== 1'b0)
      `uvm_error(get_type_name(), $sformatf("APB read failed at 0x%02x", addr))
  endtask

  task wait_status_bit(int bit_index, int max_polls);
    logic [31:0] value;
    for (int poll = 0; poll < max_polls; poll++) begin
      apb_read(ADDR_STATUS, value);
      if (value[bit_index]) return;
    end
    `uvm_fatal(get_type_name(), $sformatf("Timeout waiting for STATUS[%0d]", bit_index))
  endtask

  task configure_fast();
    apb_write(ADDR_SAMPLE_DIV, 32'd0);
    apb_write(ADDR_HEALTH_CFG, 32'h0040_0000);
    apb_write(ADDR_SOURCE_EN, 32'h0000_000F);
    apb_write(ADDR_SOURCE_CFG, 32'h0000_0002);
    apb_write(ADDR_STUCK_LIMIT, 32'd0);
    apb_write(ADDR_COND_CFG, 32'h0000_0006);
    apb_write(ADDR_IRQ_EN, 32'h0000_0003);
    apb_write(ADDR_CTRL, 32'h0000_0001);
  endtask
endclass
