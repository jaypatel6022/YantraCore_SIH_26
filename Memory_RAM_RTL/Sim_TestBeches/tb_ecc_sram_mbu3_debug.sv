`timescale 1ns/1ps

module tb_ecc_sram_mbu3_debug;

    // =========================================================
    // Parameters
    // =========================================================

    parameter ADDR_WIDTH = 8;
    parameter DATA_WIDTH = 8;
    parameter CODE_WIDTH = 13;
    parameter DEPTH      = 256;


    // =========================================================
    // DUT signals
    // =========================================================

    logic                  clk;
    logic                  rst;
    logic                  we;

    logic [ADDR_WIDTH-1:0] addr;

    logic [DATA_WIDTH-1:0] wdata;

    logic [DATA_WIDTH-1:0] rdata;

    logic single_error_corrected;

    logic double_error_detected;


    // =========================================================
    // DEBUG signals
    // =========================================================

    logic [3:0] syndrome_dbg;

    logic overall_parity_dbg;

    logic [3:0] correction_position_dbg;

    logic correction_applied_dbg;

    logic [2:0] error_class_dbg;


    // =========================================================
    // DUT
    // =========================================================

    ecc_sram_debug #(

        .ADDR_WIDTH (ADDR_WIDTH),

        .DATA_WIDTH (DATA_WIDTH),

        .CODE_WIDTH (CODE_WIDTH),

        .DEPTH      (DEPTH)

    ) dut (

        .clk                    (clk),

        .rst                    (rst),

        .we                     (we),

        .addr                   (addr),

        .wdata                  (wdata),

        .rdata                  (rdata),

        .single_error_corrected (single_error_corrected),

        .double_error_detected  (double_error_detected),

        .syndrome_dbg           (syndrome_dbg),

        .overall_parity_dbg     (overall_parity_dbg),

        .correction_position_dbg(correction_position_dbg),

        .correction_applied_dbg (correction_applied_dbg),

        .error_class_dbg        (error_class_dbg)

    );


    // =========================================================
    // Test variables
    // =========================================================

    logic [7:0] expected_data;

    logic [12:0] original_codeword;

    logic [12:0] corrupted_codeword;

    logic [3:0] syndrome;

    logic overall_parity;


    integer i;
    integer j;
    integer k;

    integer test_number;


    // =========================================================
    // Classification counters
    // =========================================================

    integer no_error_count;

    integer single_correct_count;

    integer double_detected_count;

    integer odd_zero_syndrome_count;

    integer invalid_syndrome_count;


    // =========================================================
    // Data correctness counters
    // =========================================================

    integer correct_data_count;

    integer incorrect_data_count;


    // =========================================================
    // Additional syndrome statistics
    // =========================================================

    integer syndrome_count [0:15];


    // =========================================================
    // Error-class statistics
    // =========================================================

    integer class_count [0:4];


    // =========================================================
    // Clock
    // =========================================================

    always #5 clk = ~clk;


    // =========================================================
    // Syndrome calculation
    //
    // Exactly matches the decoder.
    // =========================================================

    function automatic [3:0] calculate_syndrome(

        input logic [12:0] cw

    );

        begin

            // -------------------------------------------------
            // P1
            // -------------------------------------------------

            calculate_syndrome[0] =

                cw[0] ^
                cw[2] ^
                cw[4] ^
                cw[6] ^
                cw[8] ^
                cw[10];


            // -------------------------------------------------
            // P2
            // -------------------------------------------------

            calculate_syndrome[1] =

                cw[1] ^
                cw[2] ^
                cw[5] ^
                cw[6] ^
                cw[9] ^
                cw[10];


            // -------------------------------------------------
            // P4
            // -------------------------------------------------

            calculate_syndrome[2] =

                cw[3] ^
                cw[4] ^
                cw[5] ^
                cw[6] ^
                cw[11];


            // -------------------------------------------------
            // P8
            // -------------------------------------------------

            calculate_syndrome[3] =

                cw[7] ^
                cw[8] ^
                cw[9] ^
                cw[10] ^
                cw[11];

        end

    endfunction


    // =========================================================
    // Main test
    // =========================================================

    initial begin


        // =====================================================
        // Initial values
        // =====================================================

        clk = 1'b0;

        rst = 1'b1;

        we = 1'b0;

        addr = 8'd0;

        wdata = 8'h00;

        expected_data = 8'hB6;

        test_number = 0;


        // -----------------------------------------------------
        // Reset counters
        // -----------------------------------------------------

        no_error_count = 0;

        single_correct_count = 0;

        double_detected_count = 0;

        odd_zero_syndrome_count = 0;

        invalid_syndrome_count = 0;


        correct_data_count = 0;

        incorrect_data_count = 0;


        // -----------------------------------------------------
        // Initialize syndrome histogram
        // -----------------------------------------------------

        for (i = 0; i < 16; i = i + 1) begin

            syndrome_count[i] = 0;

        end


        // -----------------------------------------------------
        // Initialize class histogram
        // -----------------------------------------------------

        for (i = 0; i < 5; i = i + 1) begin

            class_count[i] = 0;

        end


        // =====================================================
        // RESET
        // =====================================================

        repeat (2)

            @(posedge clk);

        rst = 1'b0;


        // =====================================================
        // WRITE KNOWN DATA
        // =====================================================

        addr  = 8'd0;

        wdata = expected_data;

        we    = 1'b1;


        // -----------------------------------------------------
        // Perform write
        // -----------------------------------------------------

        @(posedge clk);

        #1;


        // -----------------------------------------------------
        // Encoder / SRAM write diagnostic
        // -----------------------------------------------------

        $display("");

        $display("==============================================================");

        $display("                 WRITE PATH SANITY CHECK");

        $display("==============================================================");

        $display("Expected data     = %08b", expected_data);

        $display("Encoded data      = %013b", dut.encoded_data);

        $display("Expected codeword = %013b", 13'h1BB8);

        $display("Stored mem[0]     = %013b", dut.mem[0]);

        $display("");


        // -----------------------------------------------------
        // Stop writing
        // -----------------------------------------------------

        we = 1'b0;


        // -----------------------------------------------------
        // Allow signals to settle
        // -----------------------------------------------------

        @(posedge clk);

        #1;


        // -----------------------------------------------------
        // Capture clean codeword
        // -----------------------------------------------------

        original_codeword = dut.mem[0];


        // =====================================================
        // Verify encoder
        // =====================================================

        $display("==============================================================");

        $display("                 ENCODER SANITY CHECK");

        $display("==============================================================");

        $display("Input data        = %08b", expected_data);

        $display("Encoder output    = %013b", dut.encoded_data);

        $display("Expected codeword = %013b", 13'h1BB8);

        $display("Captured codeword = %013b", original_codeword);

        $display("");


        if (dut.encoded_data == 13'h1BB8)

            $display("ENCODER CHECK      : PASS");

        else

            $display("ENCODER CHECK      : FAIL");


        if (original_codeword == 13'h1BB8)

            $display("SRAM WRITE CHECK   : PASS");

        else

            $display("SRAM WRITE CHECK   : FAIL");


        $display("");


        // =====================================================
        // MAIN TEST HEADER
        // =====================================================

        $display("==============================================================");

        $display("       SEC-DED THREE-BIT MBU SYNDROME ANALYSIS");

        $display("==============================================================");

        $display("Original data     = %08b", expected_data);

        $display("Original codeword = %013b", original_codeword);

        $display("Total combinations: 286");

        $display("");


        // =====================================================
        // Verify expected clean codeword before continuing
        // =====================================================

        if (original_codeword != 13'h1BB8) begin

            $display("==============================================================");

            $display("ERROR: CLEAN CODEWORD IS NOT EXPECTED VALUE");

            $display("Expected = %013b", 13'h1BB8);

            $display("Actual   = %013b", original_codeword);

            $display("==============================================================");

            $finish;

        end


        // =====================================================
        // EXHAUSTIVE THREE-BIT MBU CAMPAIGN
        //
        // 13 choose 3 = 286
        //
        // Every test starts from the same clean codeword.
        // =====================================================

        for (i = 0; i < 13; i = i + 1) begin

            for (j = i + 1; j < 13; j = j + 1) begin

                for (k = j + 1; k < 13; k = k + 1) begin


                    test_number = test_number + 1;


                    // =================================================
                    // Start from CLEAN codeword
                    // =================================================

                    corrupted_codeword = original_codeword;


                    // =================================================
                    // Inject exactly three physical bit flips
                    // =================================================

                    corrupted_codeword[i] =
                        ~corrupted_codeword[i];

                    corrupted_codeword[j] =
                        ~corrupted_codeword[j];

                    corrupted_codeword[k] =
                        ~corrupted_codeword[k];


                    // =================================================
                    // Calculate expected syndrome
                    // =================================================

                    syndrome =
                        calculate_syndrome(corrupted_codeword);


                    overall_parity =
                        ^corrupted_codeword;


                    // =================================================
                    // Store syndrome statistics
                    // =================================================

                    syndrome_count[syndrome] =
                        syndrome_count[syndrome] + 1;


                    // =================================================
                    // Inject corrupted codeword directly into SRAM
                    // =================================================

                    dut.mem[0] =
                        corrupted_codeword;


                    // =================================================
                    // Allow combinational decoder to settle
                    // =================================================

                    #1;


                    // =================================================
                    // Store class statistics
                    // =================================================

                    class_count[error_class_dbg] =
                        class_count[error_class_dbg] + 1;


                    // =================================================
                    // Classification
                    // =================================================

                    if ((overall_parity == 1'b0) &&
                        (syndrome == 4'd0)) begin

                        no_error_count =
                            no_error_count + 1;

                    end

                    else if ((overall_parity == 1'b1) &&
                             (syndrome != 4'd0) &&
                             (syndrome <= 4'd12)) begin

                        single_correct_count =
                            single_correct_count + 1;

                    end

                    else if ((overall_parity == 1'b0) &&
                             (syndrome != 4'd0)) begin

                        double_detected_count =
                            double_detected_count + 1;

                    end

                    else if ((overall_parity == 1'b1) &&
                             (syndrome == 4'd0)) begin

                        odd_zero_syndrome_count =
                            odd_zero_syndrome_count + 1;

                    end

                    else begin

                        invalid_syndrome_count =
                            invalid_syndrome_count + 1;

                    end


                    // =================================================
                    // Read decoder output
                    // =================================================

                    @(posedge clk);

                    #1;


                    // =================================================
                    // Check final data
                    // =================================================

                    if (rdata == expected_data) begin

                        correct_data_count =
                            correct_data_count + 1;

                    end

                    else begin

                        incorrect_data_count =
                            incorrect_data_count + 1;

                    end


                    // =================================================
                    // Diagnostic output
                    // =================================================

                    $display(

                        "TEST=%03d | ",

                        test_number

                    );


                    $display(

                        "BITS=%02d,%02d,%02d | ",

                        i,
                        j,
                        k

                    );


                    $display(

                        "CW=%013b | ",

                        corrupted_codeword

                    );


                    $display(

                        "SYNDROME=%02d (%04b) | ",

                        syndrome,
                        syndrome

                    );


                    $display(

                        "OP=%0b | ",

                        overall_parity

                    );


                    $display(

                        "CLASS=%0d | ",

                        error_class_dbg

                    );


                    $display(

                        "CORR_POS=%02d | ",

                        correction_position_dbg

                    );


                    $display(

                        "CORR_APPLIED=%0b | ",

                        correction_applied_dbg

                    );


                    $display(

                        "SEC=%0b | ",

                        single_error_corrected

                    );


                    $display(

                        "DED=%0b | ",

                        double_error_detected

                    );


                    $display(

                        "RDATA=%08b | ",

                        rdata

                    );


                    if (rdata == expected_data)

                        $display("CORRECT");

                    else

                        $display("INCORRECT");


                end

            end

        end


        // =====================================================
        // FINAL RESULTS
        // =====================================================

        $display("");

        $display("==============================================================");

        $display("             SYNDROME ANALYSIS RESULTS");

        $display("==============================================================");


        $display(
            "Total tests                    : %0d",
            test_number
        );


        // =====================================================
        // Decoder classification
        // =====================================================

        $display("");

        $display("Decoder classification:");

        $display(
            "NO ERROR                       : %0d",
            no_error_count
        );

        $display(
            "SINGLE-BIT CORRECTION          : %0d",
            single_correct_count
        );

        $display(
            "DOUBLE-BIT DETECTED            : %0d",
            double_detected_count
        );

        $display(
            "ODD PARITY + ZERO SYNDROME     : %0d",
            odd_zero_syndrome_count
        );

        $display(
            "INVALID SYNDROME               : %0d",
            invalid_syndrome_count
        );


        // =====================================================
        // Syndrome histogram
        // =====================================================

        $display("");

        $display("--------------------------------------------------------------");

        $display("SYNDROME DISTRIBUTION");

        $display("--------------------------------------------------------------");


        for (i = 0; i < 16; i = i + 1) begin

            $display(

                "Syndrome %04b (%2d)              : %0d",

                i,

                i,

                syndrome_count[i]

            );

        end


        // =====================================================
        // Error class histogram
        // =====================================================

        $display("");

        $display("--------------------------------------------------------------");

        $display("DEBUG ERROR CLASS DISTRIBUTION");

        $display("--------------------------------------------------------------");


        $display(
            "CLASS 0 - NO_ERROR              : %0d",
            class_count[0]
        );

        $display(
            "CLASS 1 - SINGLE_CORRECTION     : %0d",
            class_count[1]
        );

        $display(
            "CLASS 2 - DOUBLE_DETECTED       : %0d",
            class_count[2]
        );

        $display(
            "CLASS 3 - ODD_ZERO_SYNDROME     : %0d",
            class_count[3]
        );

        $display(
            "CLASS 4 - INVALID_SYNDROME      : %0d",
            class_count[4]
        );


        // =====================================================
        // Final data results
        // =====================================================

        $display("");

        $display("--------------------------------------------------------------");

        $display("FINAL DATA RESULTS");

        $display("--------------------------------------------------------------");


        $display(
            "Correct final data             : %0d",
            correct_data_count
        );

        $display(
            "Incorrect final data           : %0d",
            incorrect_data_count
        );


        // =====================================================
        // Sanity checks
        // =====================================================

        $display("");

        $display("--------------------------------------------------------------");

        $display("SANITY CHECKS");

        $display("--------------------------------------------------------------");


        $display(
            "Classification total           : %0d",

            no_error_count +
            single_correct_count +
            double_detected_count +
            odd_zero_syndrome_count +
            invalid_syndrome_count
        );


        $display(
            "Expected classification total  : 286"
        );


        $display(
            "Data result total              : %0d",

            correct_data_count +
            incorrect_data_count
        );


        $display(
            "Expected data result total     : 286"
        );


        // =====================================================
        // Final test result
        // =====================================================

        $display("");

        $display("==============================================================");


        if ((test_number == 286) &&

            ((no_error_count +
              single_correct_count +
              double_detected_count +
              odd_zero_syndrome_count +
              invalid_syndrome_count) == 286) &&

            ((correct_data_count +
              incorrect_data_count) == 286)) begin

            $display(
                "RESULT: 286/286 THREE-BIT CASES ANALYZED"
            );

        end

        else begin

            $display(
                "RESULT: TESTBENCH SANITY CHECK FAILED"
            );

        end


        $display("==============================================================");


        $finish;

    end

endmodule