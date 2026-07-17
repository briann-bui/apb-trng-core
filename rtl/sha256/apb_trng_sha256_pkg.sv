

package apb_trng_sha256_pkg;

  
  
  
  parameter int P_TRNG_SHA256_BLOCK_W  = 512;   
  parameter int P_TRNG_SHA256_DIGEST_W = 256;   
  parameter int P_TRNG_SHA256_WORD_W   = 32;    
  parameter int P_TRNG_SHA256_ROUND_N  = 64;    
  parameter int P_TRNG_SHA256_WORDS_N  = 16;    

  
  
  
  typedef enum logic [1:0] {
    E_MODE_TRNG_SHA256    = 2'b00,  
    E_MODE_SHA224    = 2'b01,  
    E_MODE_RESERVED0 = 2'b10, 
    E_MODE_RESERVED1 = 2'b11  
  } apb_trng_sha256_mode_e;

  
  
  
  typedef enum logic [3:0] {
    S_IDLE   = 4'b0000,  
    S_INIT   = 4'b0001,  
    S_LOAD   = 4'b0010,  
    S_ROUND  = 4'b0011,  
    S_UPDATE = 4'b0100,  
    S_DIGEST = 4'b0101,  
    S_DONE   = 4'b0110,  
    S_ERROR  = 4'b0111   
  } apb_trng_sha256_fsm_e;

  
  
  
  parameter logic [31:0] P_TRNG_SHA256_H0_INIT = 32'h6a09e667;
  parameter logic [31:0] P_TRNG_SHA256_H1_INIT = 32'hbb67ae85;
  parameter logic [31:0] P_TRNG_SHA256_H2_INIT = 32'h3c6ef372;
  parameter logic [31:0] P_TRNG_SHA256_H3_INIT = 32'ha54ff53a;
  parameter logic [31:0] P_TRNG_SHA256_H4_INIT = 32'h510e527f;
  parameter logic [31:0] P_TRNG_SHA256_H5_INIT = 32'h9b05688c;
  parameter logic [31:0] P_TRNG_SHA256_H6_INIT = 32'h1f83d9ab;
  parameter logic [31:0] P_TRNG_SHA256_H7_INIT = 32'h5be0cd19;

  
  
  
  parameter logic [31:0] P_SHA224_H0_INIT = 32'hc1059ed8;
  parameter logic [31:0] P_SHA224_H1_INIT = 32'h367cd507;
  parameter logic [31:0] P_SHA224_H2_INIT = 32'h3070dd17;
  parameter logic [31:0] P_SHA224_H3_INIT = 32'hf70e5939;
  parameter logic [31:0] P_SHA224_H4_INIT = 32'hffc00b31;
  parameter logic [31:0] P_SHA224_H5_INIT = 32'h68581511;
  parameter logic [31:0] P_SHA224_H6_INIT = 32'h64f98fa7;
  parameter logic [31:0] P_SHA224_H7_INIT = 32'hbefa4fa4;

endpackage : apb_trng_sha256_pkg


