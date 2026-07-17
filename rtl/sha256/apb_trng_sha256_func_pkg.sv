

package apb_trng_sha256_func_pkg;

  
  
  
  function automatic logic [31:0] f_rotr(
    input logic [31:0] x,
    input int          n
  );
    f_rotr = (x >> n) | (x << (32 - n));
  endfunction

  
  
  
  function automatic logic [31:0] f_shr(
    input logic [31:0] x,
    input int          n
  );
    f_shr = x >> n;
  endfunction

  
  
  
  function automatic logic [31:0] f_ch(
    input logic [31:0] x,
    input logic [31:0] y,
    input logic [31:0] z
  );
    f_ch = (x & y) ^ (~x & z);
  endfunction

  
  
  
  function automatic logic [31:0] f_maj(
    input logic [31:0] x,
    input logic [31:0] y,
    input logic [31:0] z
  );
    f_maj = (x & y) ^ (x & z) ^ (y & z);
  endfunction

  
  
  
  
  function automatic logic [31:0] f_big_sigma0(
    input logic [31:0] x
  );
    f_big_sigma0 = f_rotr(x, 2) ^ f_rotr(x, 13) ^ f_rotr(x, 22);
  endfunction

  
  
  
  
  function automatic logic [31:0] f_big_sigma1(
    input logic [31:0] x
  );
    f_big_sigma1 = f_rotr(x, 6) ^ f_rotr(x, 11) ^ f_rotr(x, 25);
  endfunction

  
  
  
  
  function automatic logic [31:0] f_small_sigma0(
    input logic [31:0] x
  );
    f_small_sigma0 = f_rotr(x, 7) ^ f_rotr(x, 18) ^ f_shr(x, 3);
  endfunction

  
  
  
  
  function automatic logic [31:0] f_small_sigma1(
    input logic [31:0] x
  );
    f_small_sigma1 = f_rotr(x, 17) ^ f_rotr(x, 19) ^ f_shr(x, 10);
  endfunction

endpackage : apb_trng_sha256_func_pkg


