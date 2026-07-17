

module apb_trng_sha256_datapath
  import apb_trng_sha256_pkg::*;
(
  input  logic        i_clk,
  input  logic        i_rst_n,

  
  input  logic        i_init_hash,     
  input  logic        i_load_block,    
  input  logic        i_round_en,      
  input  logic        i_update_hash,   
  input  logic        i_digest_valid,  
  input  logic [5:0]  i_round_index,   
  input  logic [1:0]  i_mode,          

  
  input  logic [P_TRNG_SHA256_BLOCK_W-1:0]  i_block,  

  
  output logic [P_TRNG_SHA256_DIGEST_W-1:0] o_digest,       
  output logic                         o_digest_valid   
);

  
  
  
  logic [P_TRNG_SHA256_WORD_W-1:0] r_h [0:7];

  
  
  
  logic [P_TRNG_SHA256_WORD_W-1:0] r_a, r_b, r_c, r_d;
  logic [P_TRNG_SHA256_WORD_W-1:0] r_e, r_f, r_g, r_h_var;

  
  
  
  logic [P_TRNG_SHA256_WORD_W-1:0] w_wt;          
  logic [P_TRNG_SHA256_WORD_W-1:0] w_kt;          
  logic [P_TRNG_SHA256_WORD_W-1:0] w_next_a;      
  logic [P_TRNG_SHA256_WORD_W-1:0] w_next_b;      
  logic [P_TRNG_SHA256_WORD_W-1:0] w_next_c;      
  logic [P_TRNG_SHA256_WORD_W-1:0] w_next_d;      
  logic [P_TRNG_SHA256_WORD_W-1:0] w_next_e;      
  logic [P_TRNG_SHA256_WORD_W-1:0] w_next_f;      
  logic [P_TRNG_SHA256_WORD_W-1:0] w_next_g;      
  logic [P_TRNG_SHA256_WORD_W-1:0] w_next_h;      

  
  
  

  
  apb_trng_sha256_msg_schedule u_msg_schedule (
    .i_clk      (i_clk),
    .i_rst_n    (i_rst_n),
    .i_load     (i_load_block),
    .i_round_en (i_round_en),
    .i_block    (i_block),
    .o_wt       (w_wt)
  );

  
  apb_trng_sha256_constants u_constants (
    .i_round_index (i_round_index),
    .o_kt          (w_kt)
  );

  
  apb_trng_sha256_round u_round (
    .i_a      (r_a),
    .i_b      (r_b),
    .i_c      (r_c),
    .i_d      (r_d),
    .i_e      (r_e),
    .i_f      (r_f),
    .i_g      (r_g),
    .i_h      (r_h_var),
    .i_wt     (w_wt),
    .i_kt     (w_kt),
    .o_next_a (w_next_a),
    .o_next_b (w_next_b),
    .o_next_c (w_next_c),
    .o_next_d (w_next_d),
    .o_next_e (w_next_e),
    .o_next_f (w_next_f),
    .o_next_g (w_next_g),
    .o_next_h (w_next_h)
  );

  
  
  
  always_ff @(posedge i_clk or negedge i_rst_n) begin
    if (!i_rst_n) begin
      for (int i = 0; i < 8; i++) begin
        r_h[i] <= '0;
      end
    end else if (i_init_hash) begin
      
      case (i_mode)
        E_MODE_TRNG_SHA256: begin
          r_h[0] <= P_TRNG_SHA256_H0_INIT;
          r_h[1] <= P_TRNG_SHA256_H1_INIT;
          r_h[2] <= P_TRNG_SHA256_H2_INIT;
          r_h[3] <= P_TRNG_SHA256_H3_INIT;
          r_h[4] <= P_TRNG_SHA256_H4_INIT;
          r_h[5] <= P_TRNG_SHA256_H5_INIT;
          r_h[6] <= P_TRNG_SHA256_H6_INIT;
          r_h[7] <= P_TRNG_SHA256_H7_INIT;
        end
        E_MODE_SHA224: begin
          
          
          r_h[0] <= P_SHA224_H0_INIT;
          r_h[1] <= P_SHA224_H1_INIT;
          r_h[2] <= P_SHA224_H2_INIT;
          r_h[3] <= P_SHA224_H3_INIT;
          r_h[4] <= P_SHA224_H4_INIT;
          r_h[5] <= P_SHA224_H5_INIT;
          r_h[6] <= P_SHA224_H6_INIT;
          r_h[7] <= P_SHA224_H7_INIT;
        end
        default: begin
          
          for (int i = 0; i < 8; i++) begin
            r_h[i] <= '0;
          end
        end
      endcase
    end else if (i_update_hash) begin
      
      r_h[0] <= r_h[0] + r_a;
      r_h[1] <= r_h[1] + r_b;
      r_h[2] <= r_h[2] + r_c;
      r_h[3] <= r_h[3] + r_d;
      r_h[4] <= r_h[4] + r_e;
      r_h[5] <= r_h[5] + r_f;
      r_h[6] <= r_h[6] + r_g;
      r_h[7] <= r_h[7] + r_h_var;
    end
  end

  
  
  
  always_ff @(posedge i_clk or negedge i_rst_n) begin
    if (!i_rst_n) begin
      r_a     <= '0;
      r_b     <= '0;
      r_c     <= '0;
      r_d     <= '0;
      r_e     <= '0;
      r_f     <= '0;
      r_g     <= '0;
      r_h_var <= '0;
    end else if (i_load_block) begin
      
      r_a     <= r_h[0];
      r_b     <= r_h[1];
      r_c     <= r_h[2];
      r_d     <= r_h[3];
      r_e     <= r_h[4];
      r_f     <= r_h[5];
      r_g     <= r_h[6];
      r_h_var <= r_h[7];
    end else if (i_round_en) begin
      
      r_a     <= w_next_a;
      r_b     <= w_next_b;
      r_c     <= w_next_c;
      r_d     <= w_next_d;
      r_e     <= w_next_e;
      r_f     <= w_next_f;
      r_g     <= w_next_g;
      r_h_var <= w_next_h;
    end
  end

  
  
  
  always_comb begin
    
    o_digest = {r_h[0], r_h[1], r_h[2], r_h[3],
                r_h[4], r_h[5], r_h[6], r_h[7]};
  end

  
  
  
  always_comb begin
    o_digest_valid = i_digest_valid;
  end

endmodule : apb_trng_sha256_datapath


