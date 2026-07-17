

module apb_trng_sha256_round
  import apb_trng_sha256_func_pkg::*;
(
  
  input  logic [31:0] i_a,
  input  logic [31:0] i_b,
  input  logic [31:0] i_c,
  input  logic [31:0] i_d,
  input  logic [31:0] i_e,
  input  logic [31:0] i_f,
  input  logic [31:0] i_g,
  input  logic [31:0] i_h,

  
  input  logic [31:0] i_wt,   
  input  logic [31:0] i_kt,   

  
  output logic [31:0] o_next_a,
  output logic [31:0] o_next_b,
  output logic [31:0] o_next_c,
  output logic [31:0] o_next_d,
  output logic [31:0] o_next_e,
  output logic [31:0] o_next_f,
  output logic [31:0] o_next_g,
  output logic [31:0] o_next_h
);

  
  
  
  logic [31:0] w_t1;  
  logic [31:0] w_t2;  

  
  
  
  always_comb begin
    
    w_t1 = i_h + f_big_sigma1(i_e) + f_ch(i_e, i_f, i_g) + i_kt + i_wt;

    
    w_t2 = f_big_sigma0(i_a) + f_maj(i_a, i_b, i_c);

    
    o_next_a = w_t1 + w_t2;
    o_next_b = i_a;
    o_next_c = i_b;
    o_next_d = i_c;
    o_next_e = i_d + w_t1;
    o_next_f = i_e;
    o_next_g = i_f;
    o_next_h = i_g;
  end

endmodule : apb_trng_sha256_round


