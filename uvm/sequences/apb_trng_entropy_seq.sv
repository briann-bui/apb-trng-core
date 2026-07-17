class apb_trng_entropy_seq extends apb_trng_base_seq;
  `uvm_object_utils(apb_trng_entropy_seq)

  function new(string name = "apb_trng_entropy_seq");
    super.new(name);
  endfunction

  task body();
    logic [31:0] status;
    logic [31:0] random_word;
    logic [31:0] sha_word_1;
    logic [31:0] sha_word_2;
    logic [31:0] sha_word_3;

    apb_write(ADDR_CTRL, 32'h0000_0002);
    configure_fast();

    apb_read(ADDR_SOURCE_ACT, status);
    if (status[7:0] !== 8'h0F)
      `uvm_error(get_type_name(), $sformatf("Active source mask mismatch: 0x%08x", status))

    wait_status_bit(1, 500);
    apb_read(ADDR_DATA, random_word);
    if (^random_word === 1'bx)
      `uvm_error(get_type_name(), "Conditioned random word contains X")

    apb_write(ADDR_COND_CFG, 32'h0000_0007);
    wait_status_bit(1, 1000);
    apb_read(ADDR_DATA, sha_word_1);
    wait_status_bit(1, 1000);
    apb_read(ADDR_DATA, sha_word_2);
    wait_status_bit(1, 1000);
    apb_read(ADDR_DATA, sha_word_3);

    if ((^sha_word_1 === 1'bx) || (^sha_word_2 === 1'bx) ||
        (^sha_word_3 === 1'bx))
      `uvm_error(get_type_name(), "SHA-conditioned word contains X")
    if ((sha_word_1 == sha_word_2) || (sha_word_2 == sha_word_3) ||
        (sha_word_1 == sha_word_3))
      `uvm_error(get_type_name(),
        $sformatf("Repeated deterministic SHA words: %08x %08x %08x",
                  sha_word_1, sha_word_2, sha_word_3))

    `uvm_info(get_type_name(),
      $sformatf("Entropy sequence passed: DATA=%08x SHA=%08x/%08x/%08x",
                random_word, sha_word_1, sha_word_2, sha_word_3), UVM_LOW)
  endtask
endclass
