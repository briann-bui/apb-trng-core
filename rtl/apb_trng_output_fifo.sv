module apb_trng_output_fifo #(
  parameter int OUTPUT_WIDTH = 32,
  parameter int FIFO_DEPTH   = 8
) (
  input  logic                    i_trng_clk,
  input  logic                    i_trng_rst_n,
  input  logic                    i_trng_clear,
  input  logic [31:0]             i_trng_conditioned_data,
  input  logic                    i_trng_conditioned_valid,
  output logic                    o_trng_conditioned_ready,
  input  logic                    i_trng_stream_mode,
  input  logic                    i_trng_apb_read,
  output logic [31:0]             o_trng_apb_data,
  output logic                    o_trng_apb_data_valid,
  output logic [OUTPUT_WIDTH-1:0] o_trng_stream_data,
  output logic                    o_trng_stream_valid,
  input  logic                    i_trng_stream_ready,
  output logic                    o_trng_fifo_empty,
  output logic                    o_trng_fifo_full,
  output logic [6:0]              o_trng_fifo_level,
  output logic                    o_trng_output_pulse,
  output logic                    o_trng_not_ready_pulse
);

  localparam int PTR_WIDTH = (FIFO_DEPTH <= 2) ? 1 : $clog2(FIFO_DEPTH);
  localparam int COUNT_WIDTH = $clog2(FIFO_DEPTH + 1);
  localparam int APB_SLICES = (OUTPUT_WIDTH <= 32) ? 1 : (OUTPUT_WIDTH / 32);
  localparam int APB_SLICE_WIDTH = (APB_SLICES <= 1) ? 1 : $clog2(APB_SLICES);

  logic [OUTPUT_WIDTH-1:0] r_fifo_mem [FIFO_DEPTH];
  logic [PTR_WIDTH-1:0]    r_write_ptr;
  logic [PTR_WIDTH-1:0]    r_read_ptr;
  logic [COUNT_WIDTH-1:0]  r_fifo_count;
  logic [APB_SLICE_WIDTH-1:0] r_apb_slice;
  logic                    w_fifo_push;
  logic [OUTPUT_WIDTH-1:0] w_fifo_push_data;
  logic                    w_fifo_pop;
  logic                    w_input_accept;
  logic                    w_apb_pop;
  logic                    w_stream_pop;

  initial begin
    assert ((OUTPUT_WIDTH == 8) || (OUTPUT_WIDTH == 16) ||
            (OUTPUT_WIDTH == 32) || (OUTPUT_WIDTH == 64) ||
            (OUTPUT_WIDTH == 128))
      else $error("OUTPUT_WIDTH must be 8, 16, 32, 64, or 128");
    assert ((FIFO_DEPTH >= 4) && (FIFO_DEPTH <= 64))
      else $error("FIFO_DEPTH must be in the range 4..64");
  end

  assign o_trng_fifo_empty = (r_fifo_count == 0);
  assign o_trng_fifo_full  = (r_fifo_count == FIFO_DEPTH);
  assign o_trng_fifo_level = r_fifo_count;
  assign o_trng_stream_data  = r_fifo_mem[r_read_ptr];
  assign o_trng_stream_valid = !o_trng_fifo_empty && i_trng_stream_mode;
  assign o_trng_apb_data_valid = !o_trng_fifo_empty && !i_trng_stream_mode;
  assign w_stream_pop = o_trng_stream_valid && i_trng_stream_ready;
  assign w_apb_pop = i_trng_apb_read && o_trng_apb_data_valid &&
                     (r_apb_slice == (APB_SLICES-1));
  assign w_fifo_pop = w_stream_pop || w_apb_pop;
  assign w_input_accept = i_trng_conditioned_valid && o_trng_conditioned_ready;

  always @* begin
    if (OUTPUT_WIDTH <= 32)
      o_trng_apb_data = r_fifo_mem[r_read_ptr];
    else
      o_trng_apb_data = r_fifo_mem[r_read_ptr] >> (r_apb_slice * 32);
  end

  generate
    if (OUTPUT_WIDTH == 32) begin : g_equal_width
      always @* begin
        o_trng_conditioned_ready = !o_trng_fifo_full;
        w_fifo_push = w_input_accept;
        w_fifo_push_data = i_trng_conditioned_data;
      end
    end else if (OUTPUT_WIDTH > 32) begin : g_pack_width
      localparam int PACK_WORDS = OUTPUT_WIDTH / 32;
      localparam int PACK_COUNT_WIDTH = $clog2(PACK_WORDS);
      logic [OUTPUT_WIDTH-1:0] r_pack_data;
      logic [PACK_COUNT_WIDTH-1:0] r_pack_count;

      always @* begin
        o_trng_conditioned_ready = (r_pack_count < (PACK_WORDS-1)) || !o_trng_fifo_full;
        w_fifo_push = w_input_accept && (r_pack_count == (PACK_WORDS-1));
        w_fifo_push_data = r_pack_data;
        w_fifo_push_data[r_pack_count*32 +: 32] = i_trng_conditioned_data;
      end

      always_ff @(posedge i_trng_clk or negedge i_trng_rst_n) begin
        if (!i_trng_rst_n) begin
          r_pack_data  <= '0;
          r_pack_count <= '0;
        end else if (i_trng_clear) begin
          r_pack_data  <= '0;
          r_pack_count <= '0;
        end else if (w_input_accept) begin
          r_pack_data[r_pack_count*32 +: 32] <= i_trng_conditioned_data;
          if (r_pack_count == (PACK_WORDS-1)) begin
            r_pack_data  <= '0;
            r_pack_count <= '0;
          end else begin
            r_pack_count <= r_pack_count + 1'b1;
          end
        end
      end
    end else begin : g_split_width
      localparam int SPLIT_WORDS = 32 / OUTPUT_WIDTH;
      localparam int SPLIT_COUNT_WIDTH = $clog2(SPLIT_WORDS + 1);
      logic [31:0] r_split_data;
      logic [SPLIT_COUNT_WIDTH-1:0] r_split_remaining;

      always @* begin
        o_trng_conditioned_ready = (r_split_remaining == 0);
        w_fifo_push = (r_split_remaining != 0) && !o_trng_fifo_full;
        w_fifo_push_data = r_split_data[OUTPUT_WIDTH-1:0];
      end

      always_ff @(posedge i_trng_clk or negedge i_trng_rst_n) begin
        if (!i_trng_rst_n) begin
          r_split_data      <= 32'd0;
          r_split_remaining <= '0;
        end else if (i_trng_clear) begin
          r_split_data      <= 32'd0;
          r_split_remaining <= '0;
        end else if (w_input_accept) begin
          r_split_data      <= i_trng_conditioned_data;
          r_split_remaining <= SPLIT_WORDS;
        end else if (w_fifo_push) begin
          r_split_data      <= r_split_data >> OUTPUT_WIDTH;
          r_split_remaining <= r_split_remaining - 1'b1;
        end
      end
    end
  endgenerate

  always_ff @(posedge i_trng_clk or negedge i_trng_rst_n) begin
    if (!i_trng_rst_n) begin
      r_write_ptr             <= '0;
      r_read_ptr              <= '0;
      r_fifo_count            <= '0;
      r_apb_slice             <= '0;
      o_trng_output_pulse     <= 1'b0;
      o_trng_not_ready_pulse  <= 1'b0;
    end else begin
      o_trng_output_pulse    <= 1'b0;
      o_trng_not_ready_pulse <= 1'b0;

      if (i_trng_clear) begin
        r_write_ptr  <= '0;
        r_read_ptr   <= '0;
        r_fifo_count <= '0;
        r_apb_slice  <= '0;
      end else begin
        if (i_trng_apb_read && !o_trng_apb_data_valid)
          o_trng_not_ready_pulse <= 1'b1;

        if (i_trng_apb_read && o_trng_apb_data_valid) begin
          if (r_apb_slice == (APB_SLICES-1)) r_apb_slice <= '0;
          else r_apb_slice <= r_apb_slice + 1'b1;
        end
        if (w_stream_pop) r_apb_slice <= '0;

        if (w_fifo_push) begin
          r_fifo_mem[r_write_ptr] <= w_fifo_push_data;
          if (r_write_ptr == (FIFO_DEPTH-1)) r_write_ptr <= '0;
          else r_write_ptr <= r_write_ptr + 1'b1;
          o_trng_output_pulse <= 1'b1;
        end

        if (w_fifo_pop) begin
          if (r_read_ptr == (FIFO_DEPTH-1)) r_read_ptr <= '0;
          else r_read_ptr <= r_read_ptr + 1'b1;
        end

        unique case ({w_fifo_push, w_fifo_pop})
          2'b10: r_fifo_count <= r_fifo_count + 1'b1;
          2'b01: r_fifo_count <= r_fifo_count - 1'b1;
          default: ;
        endcase
      end
    end
  end

endmodule
