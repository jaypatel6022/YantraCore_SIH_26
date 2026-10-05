`timescale 1ns/1ps

module tb_ecc_modules;

    logic [7:0]  data_in;

    logic [12:0] codeword;

    logic [12:0] corrupted_codeword;

    logic [7:0] decoded_data;

    logic single_corrected;

    logic double_detected;

    integer fault_bit;


    // =========================================================
    // Encoder
    // =========================================================

    ecc_encoder_8_13 encoder (

        .data_in      (data_in),

        .codeword_out (codeword)

    );


    // =========================================================
    // Decoder
    // =========================================================

    ecc_decoder_13_8 decoder (

        .codeword_in  (corrupted_codeword),

        .data_out     (decoded_data),

        .single_error_corrected (single_corrected),

        .double_error_detected   (double_detected)

    );


    // =========================================================
    // Test
    // =========================================================

    initial begin

        data_in = 8'b10110110;

        #10;


        $display("");
        $display("==========================================");
        $display("     SEPARATED SEC-DED ECC TEST");
        $display("==========================================");


        // =====================================================
        // TEST 1 - No error
        // =====================================================

        corrupted_codeword = codeword;

        #1;

        $display("");

        $display("TEST 1: NO ERROR");

        $display("Original data : %b", data_in);

        $display("Codeword      : %b", codeword);

        $display("Decoded data  : %b", decoded_data);


        if (decoded_data == data_in)

            $display("PASS");

        else

            $display("FAIL");


        // =====================================================
        // TEST 2 - Every single bit
        // =====================================================

        $display("");

        $display("TEST 2: SINGLE-BIT ERROR CAMPAIGN");


        for (
            fault_bit = 0;
            fault_bit < 13;
            fault_bit = fault_bit + 1
        ) begin

            corrupted_codeword = codeword;

            corrupted_codeword[fault_bit] =
                ~corrupted_codeword[fault_bit];

            #1;


            if (
                (decoded_data == data_in) &&
                (single_corrected == 1'b1)
            ) begin

                $display(
                    "BIT %0d : PASS | CORRECTED",
                    fault_bit
                );

            end
            else begin

                $display(
                    "BIT %0d : FAIL | DATA=%b",
                    fault_bit,
                    decoded_data
                );

            end

        end


        // =====================================================
        // TEST 3 - Double-bit error
        // =====================================================

        $display("");

        $display("TEST 3: DOUBLE-BIT ERROR");


        corrupted_codeword = codeword;


        corrupted_codeword[0] =
            ~corrupted_codeword[0];


        corrupted_codeword[1] =
            ~corrupted_codeword[1];


        #1;


        $display(
            "Decoded data : %b",
            decoded_data
        );


        if (double_detected == 1'b1)

            $display("DOUBLE ERROR DETECTED: PASS");

        else

            $display("DOUBLE ERROR DETECTED: FAIL");


        // =====================================================
        // Finish
        // =====================================================

        $display("");

        $display("==========================================");

        $finish;

    end

endmodule