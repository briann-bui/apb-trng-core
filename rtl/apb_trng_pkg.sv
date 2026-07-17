package apb_trng_pkg;

  localparam logic [7:0] APB_TRNG_ADDR_CTRL        = 8'h00;
  localparam logic [7:0] APB_TRNG_ADDR_STATUS      = 8'h04;
  localparam logic [7:0] APB_TRNG_ADDR_DATA        = 8'h08;
  localparam logic [7:0] APB_TRNG_ADDR_HEALTH_CFG  = 8'h0C;
  localparam logic [7:0] APB_TRNG_ADDR_SAMPLE_DIV  = 8'h10;
  localparam logic [7:0] APB_TRNG_ADDR_IRQ_EN      = 8'h14;
  localparam logic [7:0] APB_TRNG_ADDR_IRQ_STAT    = 8'h18;
  localparam logic [7:0] APB_TRNG_ADDR_HEALTH_CNT = 8'h1C;
  localparam logic [7:0] APB_TRNG_ADDR_RO_SAMPLE   = 8'h20;
  localparam logic [7:0] APB_TRNG_ADDR_SOURCE_EN   = 8'h24;
  localparam logic [7:0] APB_TRNG_ADDR_SOURCE_CFG  = 8'h28;
  localparam logic [7:0] APB_TRNG_ADDR_STUCK_LIMIT = 8'h2C;
  localparam logic [7:0] APB_TRNG_ADDR_SOURCE_FAIL = 8'h30;
  localparam logic [7:0] APB_TRNG_ADDR_SOURCE_ACT  = 8'h34;
  localparam logic [7:0] APB_TRNG_ADDR_COND_CFG    = 8'h38;
  localparam logic [7:0] APB_TRNG_ADDR_ENTROPY_CNT = 8'h3C;
  localparam logic [7:0] APB_TRNG_ADDR_REJECT_CNT  = 8'h40;
  localparam logic [7:0] APB_TRNG_ADDR_OUTPUT_CFG  = 8'h44;
  localparam logic [7:0] APB_TRNG_ADDR_FIFO_LEVEL  = 8'h48;
  localparam logic [7:0] APB_TRNG_ADDR_OUTPUT_INFO = 8'h4C;
  localparam logic [7:0] APB_TRNG_ADDR_VERSION     = 8'hFC;

  localparam logic [31:0] APB_TRNG_VERSION = 32'h0005_0001;

endpackage
