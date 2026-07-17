

module apb_trng_sha256_ctrl
  import apb_trng_sha256_pkg::*;
(
  input  logic       i_clk,
  input  logic       i_rst_n,

  
  input  logic       i_start,
  input  logic       i_init,
  input  logic       i_next,
  input  logic       i_final,
  input  logic [1:0] i_mode,
  input  logic       i_block_valid,

  
  output logic       o_block_ready,
  output logic       o_busy,
  output logic       o_done,
  output logic       o_error,

  
  output logic       o_init_hash,
  output logic       o_load_block,
  output logic       o_round_en,
  output logic       o_update_hash,
  output logic       o_digest_valid,
  output logic [5:0] o_round_index
);

  
  
  
  apb_trng_sha256_fsm_e          r_state;
  apb_trng_sha256_fsm_e          r_next_state;
  logic [5:0]        r_round_cnt;
  logic              r_is_final;       
  logic              r_is_init;        

  
  
  
  logic              w_mode_valid;
  logic              w_round_last;

  
  
  
  
  
  always_comb begin
    w_mode_valid = (i_mode == E_MODE_TRNG_SHA256) || (i_mode == E_MODE_SHA224);
  end

  
  
  
  always_comb begin
    w_round_last = (r_round_cnt == 6'(P_TRNG_SHA256_ROUND_N - 1));
  end

  
  
  
  always_comb begin
    r_next_state = r_state;

    case (r_state)
      S_IDLE: begin
        if (i_start) begin
          if (!w_mode_valid) begin
            r_next_state = S_ERROR;
          end else if (i_init) begin
            r_next_state = S_INIT;
          end else if (i_next && i_block_valid) begin
            r_next_state = S_LOAD;
          end
          
        end
      end

      S_INIT: begin
        
        if (i_block_valid) begin
          r_next_state = S_LOAD;
        end
        
      end

      S_LOAD: begin
        
        r_next_state = S_ROUND;
      end

      S_ROUND: begin
        if (w_round_last) begin
          r_next_state = S_UPDATE;
        end
        
      end

      S_UPDATE: begin
        r_next_state = S_DIGEST;
      end

      S_DIGEST: begin
        r_next_state = S_DONE;
      end

      S_DONE: begin
        r_next_state = S_IDLE;
      end

      S_ERROR: begin
        r_next_state = S_IDLE;
      end

      default: begin
        r_next_state = S_IDLE;
      end
    endcase
  end

  
  
  
  always_ff @(posedge i_clk or negedge i_rst_n) begin
    if (!i_rst_n) begin
      r_state <= S_IDLE;
    end else begin
      r_state <= r_next_state;
    end
  end

  
  
  
  always_ff @(posedge i_clk or negedge i_rst_n) begin
    if (!i_rst_n) begin
      r_round_cnt <= 6'd0;
    end else begin
      if (r_state == S_LOAD) begin
        
        r_round_cnt <= 6'd0;
      end else if (r_state == S_ROUND) begin
        r_round_cnt <= r_round_cnt + 6'd1;
      end
    end
  end

  
  
  
  
  always_ff @(posedge i_clk or negedge i_rst_n) begin
    if (!i_rst_n) begin
      r_is_final <= 1'b0;
      r_is_init  <= 1'b0;
    end else begin
      if (r_state == S_IDLE && i_start && w_mode_valid) begin
        r_is_final <= i_final;
        r_is_init  <= i_init;
      end else if (r_state == S_INIT && i_block_valid) begin
        
        r_is_final <= r_is_final | i_final;
      end
    end
  end

  
  
  
  always_comb begin
    
    o_block_ready  = 1'b0;
    o_busy         = 1'b0;
    o_done         = 1'b0;
    o_error        = 1'b0;
    o_init_hash    = 1'b0;
    o_load_block   = 1'b0;
    o_round_en     = 1'b0;
    o_update_hash  = 1'b0;
    o_digest_valid = 1'b0;
    o_round_index  = r_round_cnt;

    case (r_state)
      S_IDLE: begin
        o_block_ready = 1'b1;  
      end

      S_INIT: begin
        o_busy      = 1'b1;
        o_init_hash = 1'b1;    
        
        o_block_ready = 1'b1;
      end

      S_LOAD: begin
        o_busy       = 1'b1;
        o_load_block = 1'b1;   
      end

      S_ROUND: begin
        o_busy     = 1'b1;
        o_round_en = 1'b1;     
      end

      S_UPDATE: begin
        o_busy        = 1'b1;
        o_update_hash = 1'b1;  
      end

      S_DIGEST: begin
        o_busy         = 1'b1;
        o_digest_valid = r_is_final;  
      end

      S_DONE: begin
        o_done         = 1'b1;        
        o_digest_valid = r_is_final;  
      end

      S_ERROR: begin
        o_error = 1'b1;        
      end

      default: begin
        
      end
    endcase
  end

endmodule : apb_trng_sha256_ctrl


