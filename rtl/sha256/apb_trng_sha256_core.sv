

module apb_trng_sha256_core
  import apb_trng_sha256_pkg::*;
#(
  parameter int P_DATA_W   = P_TRNG_SHA256_WORD_W,    
  parameter int P_BLOCK_W  = P_TRNG_SHA256_BLOCK_W,   
  parameter int P_DIGEST_W = P_TRNG_SHA256_DIGEST_W   
) (
  
  input  logic                   i_trng_sha256_clk,
  input  logic                   i_trng_sha256_rst_n,

  
  input  logic                   i_trng_sha256_start,       
  input  logic                   i_trng_sha256_init,        
  input  logic                   i_trng_sha256_next,        
  input  logic                   i_trng_sha256_final,       
  input  logic [1:0]             i_trng_sha256_mode,        

  
  input  logic                   i_trng_sha256_block_valid, 
  input  logic [P_BLOCK_W-1:0]  i_trng_sha256_block,       
  input  logic [63:0]            i_trng_sha256_msg_bit_len, 

  
  output logic                   o_trng_sha256_block_ready, 
  output logic                   o_trng_sha256_busy,        
  output logic                   o_trng_sha256_done,        
  output logic                   o_trng_sha256_error,       

  
  output logic                   o_trng_sha256_digest_valid, 
  output logic [P_DIGEST_W-1:0] o_trng_sha256_digest         
);

  
  
  
  logic        w_init_hash;
  logic        w_load_block;
  logic        w_round_en;
  logic        w_update_hash;
  logic        w_digest_valid_ctrl;
  logic [5:0]  w_round_index;

  
  
  
  

  
  
  
  apb_trng_sha256_ctrl u_ctrl (
    .i_clk          (i_trng_sha256_clk),
    .i_rst_n        (i_trng_sha256_rst_n),

    
    .i_start        (i_trng_sha256_start),
    .i_init         (i_trng_sha256_init),
    .i_next         (i_trng_sha256_next),
    .i_final        (i_trng_sha256_final),
    .i_mode         (i_trng_sha256_mode),
    .i_block_valid  (i_trng_sha256_block_valid),

    
    .o_block_ready  (o_trng_sha256_block_ready),
    .o_busy         (o_trng_sha256_busy),
    .o_done         (o_trng_sha256_done),
    .o_error        (o_trng_sha256_error),

    
    .o_init_hash    (w_init_hash),
    .o_load_block   (w_load_block),
    .o_round_en     (w_round_en),
    .o_update_hash  (w_update_hash),
    .o_digest_valid (w_digest_valid_ctrl),
    .o_round_index  (w_round_index)
  );

  
  
  
  apb_trng_sha256_datapath u_datapath (
    .i_clk          (i_trng_sha256_clk),
    .i_rst_n        (i_trng_sha256_rst_n),

    
    .i_init_hash    (w_init_hash),
    .i_load_block   (w_load_block),
    .i_round_en     (w_round_en),
    .i_update_hash  (w_update_hash),
    .i_digest_valid (w_digest_valid_ctrl),
    .i_round_index  (w_round_index),
    .i_mode         (i_trng_sha256_mode),

    
    .i_block        (i_trng_sha256_block),
    .o_digest       (o_trng_sha256_digest),
    .o_digest_valid (o_trng_sha256_digest_valid)
  );

endmodule : apb_trng_sha256_core

