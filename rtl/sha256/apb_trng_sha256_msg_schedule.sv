

module apb_trng_sha256_msg_schedule
  import apb_trng_sha256_pkg::*;
  import apb_trng_sha256_func_pkg::*;
(
  input  logic        i_clk,
  input  logic        i_rst_n,

  
  input  logic        i_load,       
  input  logic        i_round_en,   

  
  input  logic [P_TRNG_SHA256_BLOCK_W-1:0] i_block,  

  
  output logic [P_TRNG_SHA256_WORD_W-1:0]  o_wt      
);

  
  
  
  logic [P_TRNG_SHA256_WORD_W-1:0] r_w [0:P_TRNG_SHA256_WORDS_N-1];

  
  
  
  logic [P_TRNG_SHA256_WORD_W-1:0] w_new_word;

  
  
  
  
  
  
  
  always_comb begin
    w_new_word = f_small_sigma1(r_w[14]) + r_w[9]
               + f_small_sigma0(r_w[1])  + r_w[0];
  end

  
  
  
  always_comb begin
    o_wt = r_w[0];
  end

  
  
  
  always_ff @(posedge i_clk or negedge i_rst_n) begin
    if (!i_rst_n) begin
      for (int i = 0; i < P_TRNG_SHA256_WORDS_N; i++) begin
        r_w[i] <= '0;
      end
    end else if (i_load) begin
      
      
      for (int i = 0; i < P_TRNG_SHA256_WORDS_N; i++) begin
        r_w[i] <= i_block[(P_TRNG_SHA256_WORDS_N - 1 - i)*P_TRNG_SHA256_WORD_W +: P_TRNG_SHA256_WORD_W];
      end
    end else if (i_round_en) begin
      
      for (int i = 0; i < P_TRNG_SHA256_WORDS_N - 1; i++) begin
        r_w[i] <= r_w[i + 1];
      end
      r_w[P_TRNG_SHA256_WORDS_N - 1] <= w_new_word;
    end
  end

endmodule : apb_trng_sha256_msg_schedule


