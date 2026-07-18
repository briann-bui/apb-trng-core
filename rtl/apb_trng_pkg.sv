package apb_trng_pkg;

  localparam logic [7:0] APB_TRNG_ADDR_CTRL   = 8'h00;
  localparam logic [7:0] APB_TRNG_ADDR_STATUS = 8'h04;
  localparam logic [7:0] APB_TRNG_ADDR_DATA   = 8'h08;

  localparam int APB_TRNG_CTRL_ENABLE_BIT       = 0;
  localparam int APB_TRNG_CTRL_CLEAR_BIT        = 1;
  localparam int APB_TRNG_STATUS_ENABLED_BIT    = 0;
  localparam int APB_TRNG_STATUS_DATA_VALID_BIT = 1;
  localparam int APB_TRNG_STATUS_HEALTH_FAIL_BIT= 2;

endpackage
