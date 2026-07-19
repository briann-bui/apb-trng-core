module apb_trng_apb_if
  import apb_trng_pkg::*;
#(
  parameter int C_APB_DATA_WIDTH = 32,
  parameter int C_APB_ADDR_WIDTH = 8
) (
  input  logic                            i_trng_pclk,
  input  logic                            i_trng_presetn,
  input  logic [C_APB_ADDR_WIDTH-1:0]     i_trng_paddr,
  input  logic                            i_trng_psel,
  input  logic                            i_trng_penable,
  input  logic                            i_trng_pwrite,
  input  logic [C_APB_DATA_WIDTH-1:0]     i_trng_pwdata,
  input  logic [(C_APB_DATA_WIDTH/8)-1:0] i_trng_pstrb,
  output logic [C_APB_DATA_WIDTH-1:0]     o_trng_prdata,
  output logic                            o_trng_pready,
  output logic                            o_trng_pslverr,
  output logic                            o_trng_irq,
  output logic                            o_trng_enable,
  output logic                            o_trng_clear,
  output logic                            o_trng_data_pop,
  input  logic [31:0]                     i_trng_data,
  input  logic                            i_trng_data_valid,
  input  logic                            i_trng_health_fail
);

  logic w_apb_access;
  logic w_apb_write;
  logic w_apb_read;

  assign w_apb_access = i_trng_psel && i_trng_penable;
  assign w_apb_write  = w_apb_access && i_trng_pwrite;
  assign w_apb_read   = w_apb_access && !i_trng_pwrite;

  assign o_trng_pready   = 1'b1;
  assign o_trng_pslverr  = 1'b0;
  assign o_trng_irq      = i_trng_data_valid || i_trng_health_fail;
  assign o_trng_data_pop = w_apb_read &&
                           (i_trng_paddr[7:0] == APB_TRNG_ADDR_DATA) &&
                           i_trng_data_valid;

  always_ff @(posedge i_trng_pclk or negedge i_trng_presetn) begin
    if (!i_trng_presetn) begin
      o_trng_enable <= 1'b0;
      o_trng_clear  <= 1'b0;
    end else begin
      o_trng_clear <= 1'b0;
      if (w_apb_write && (i_trng_paddr[7:0] == APB_TRNG_ADDR_CTRL) && i_trng_pstrb[0]) begin
        o_trng_enable <= i_trng_pwdata[APB_TRNG_CTRL_ENABLE_BIT];
        o_trng_clear  <= i_trng_pwdata[APB_TRNG_CTRL_CLEAR_BIT];
      end
    end
  end

  always_comb begin
    o_trng_prdata = 32'd0;
    if (i_trng_psel && !i_trng_pwrite) begin
      unique case (i_trng_paddr[7:0])
        APB_TRNG_ADDR_CTRL: begin
          o_trng_prdata[APB_TRNG_CTRL_ENABLE_BIT] = o_trng_enable;
        end
        APB_TRNG_ADDR_STATUS: begin
          o_trng_prdata[APB_TRNG_STATUS_ENABLED_BIT]     = o_trng_enable;
          o_trng_prdata[APB_TRNG_STATUS_DATA_VALID_BIT]  = i_trng_data_valid;
          o_trng_prdata[APB_TRNG_STATUS_HEALTH_FAIL_BIT] = i_trng_health_fail;
        end
        APB_TRNG_ADDR_DATA: o_trng_prdata = i_trng_data_valid ? i_trng_data : 32'd0;
        default:            o_trng_prdata = 32'd0;
      endcase
    end
  end

endmodule
