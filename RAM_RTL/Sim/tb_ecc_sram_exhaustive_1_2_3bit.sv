`timescale 1ns/1ps

module tb_ecc_sram_exhaustive;

    // =========================================================
    // PARAMETERS
    // =========================================================

    parameter ADDR_WIDTH = 8;
    parameter DATA_WIDTH = 8;
    parameter CODE_WIDTH = 13;
    parameter DEPTH      = 256;


    // =========================================================
    // DUT SIGNALS
    // =========================================================

    logic clk;
    logic rst;

    logic we;
    logic [ADDR_WIDTH-1:0] addr;
    logic [DATA_WIDTH-1:0] wdata;

    logic [DATA_WIDTH-1:0] rdata;

    logic single_error_corrected;
    logic double_error_detected;
    
    
    // =========================================================
    // DEBUG SIGNALS
    // =========================================================

    logic [3:0] syndrome_dbg;
    logic       overall_parity_dbg;

    logic [3:0] correction_position_dbg;

    logic       correction_applied_dbg;

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

        .syndrome_dbg            (syndrome_dbg),
        .overall_parity_dbg      (overall_parity_dbg),
        .correction_position_dbg (correction_position_dbg),
        .correction_applied_dbg  (correction_applied_dbg),
        .error_class_dbg         (error_class_dbg)
    );


    


    // =========================================================
    // TEST VARIABLES
    // =========================================================

    logic [7:0] expected_data;

    logic [12:0] original_codeword;
    logic [12:0] corrupted_codeword;


    integer i;
    integer j;
    integer k;

    integer test_number;


    // =========================================================
    // RESULT COUNTERS
    // =========================================================

    integer total_tests;

    // 1-bit
    integer one_bit_tests;
    integer one_bit_correct;
    integer one_bit_incorrect;
    integer one_bit_single;
    integer one_bit_double;
    integer one_bit_unexpected;

    // 2-bit
    integer two_bit_tests;
    integer two_bit_correct;
    integer two_bit_incorrect;
    integer two_bit_single;
    integer two_bit_double;
    integer two_bit_unexpected;

    // 3-bit
    integer three_bit_tests;
    integer three_bit_correct;
    integer three_bit_incorrect;
    integer three_bit_single;
    integer three_bit_double;
    integer three_bit_no_error;
    integer three_bit_odd_zero;
    integer three_bit_invalid;


    // =========================================================
    // CLASS COUNTERS
    // =========================================================

    integer class_count_1bit [0:4];
    integer class_count_2bit [0:4];
    integer class_count_3bit [0:4];


    // =========================================================
    // SYNDROME HISTOGRAM
    // =========================================================

    integer syndrome_count_1bit [0:15];
    integer syndrome_count_2bit [0:15];
    integer syndrome_count_3bit [0:15];


    // =========================================================
    // CLOCK
    // =========================================================

    always #5 clk = ~clk;


    // =========================================================
    // MAIN TEST
    // =========================================================

    initial begin

        // -----------------------------------------------------
        // INITIALIZATION
        // -----------------------------------------------------

        clk = 1'b0;

        rst = 1'b1;

        we = 1'b0;

        addr = 8'd0;

        wdata = 8'h00;

        expected_data = 8'hB6;

        test_number = 0;

        total_tests = 0;


        // -----------------------------------------------------
        // Initialize counters
        // -----------------------------------------------------

        one_bit_tests = 0;
        one_bit_correct = 0;
        one_bit_incorrect = 0;
        one_bit_single = 0;
        one_bit_double = 0;
        one_bit_unexpected = 0;

        two_bit_tests = 0;
        two_bit_correct = 0;
        two_bit_incorrect = 0;
        two_bit_single = 0;
        two_bit_double = 0;
        two_bit_unexpected = 0;

        three_bit_tests = 0;
        three_bit_correct = 0;
        three_bit_incorrect = 0;
        three_bit_single = 0;
        three_bit_double = 0;
        three_bit_no_error = 0;
        three_bit_odd_zero = 0;
        three_bit_invalid = 0;


        for (i = 0; i < 5; i = i + 1) begin

            class_count_1bit[i] = 0;
            class_count_2bit[i] = 0;
            class_count_3bit[i] = 0;

        end


        for (i = 0; i < 16; i = i + 1) begin

            syndrome_count_1bit[i] = 0;
            syndrome_count_2bit[i] = 0;
            syndrome_count_3bit[i] = 0;

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

        @(negedge clk);

        we = 1'b1;

        addr = 8'd0;

        wdata = expected_data;


        @(posedge clk);

        // Give NBA assignment time to complete

        #1;


        // Disable write

        @(negedge clk);

        we = 1'b0;


        // Give SRAM write path a complete cycle

        @(posedge clk);

        #1;


        // =====================================================
        // CAPTURE ORIGINAL CODEWORD
        // =====================================================

        original_codeword = dut.mem[0];


        // =====================================================
        // WRITE PATH SANITY CHECK
        // =====================================================

        $display("");
        $display("==============================================================");
        $display("                 WRITE PATH SANITY CHECK");
        $display("==============================================================");

        $display(
            "Expected data     = %08b",
            expected_data
        );

        $display(
            "Encoded data      = %013b",
            dut.encoded_data
        );

        $display(
            "Stored mem[0]     = %013b",
            original_codeword
        );

        if (original_codeword == dut.encoded_data)
            $display("WRITE CHECK        : PASS");
        else
            $display("WRITE CHECK        : FAIL");


        // =====================================================
        // START CAMPAIGN
        // =====================================================

        $display("");
        $display("==============================================================");
        $display("          EXHAUSTIVE 1-BIT + 2-BIT + 3-BIT CAMPAIGN");
        $display("==============================================================");

        $display(
            "Expected data     = %08b",
            expected_data
        );

        $display(
            "Original codeword = %013b",
            original_codeword
        );

        $display("");


        // =====================================================
        // 1-BIT CAMPAIGN
        // =====================================================

        $display("");
        $display("==============================================================");
        $display("                 1-BIT FAULT CAMPAIGN");
        $display("==============================================================");


        for (i = 0; i < 13; i = i + 1) begin

            test_number = test_number + 1;
            total_tests = total_tests + 1;

            one_bit_tests = one_bit_tests + 1;


            // -------------------------------------------------
            // Start from clean codeword
            // -------------------------------------------------

            corrupted_codeword = original_codeword;


            // -------------------------------------------------
            // Inject one fault
            // -------------------------------------------------

            corrupted_codeword[i] =
                ~corrupted_codeword[i];


            // -------------------------------------------------
            // Inject into SRAM
            // -------------------------------------------------

            @(negedge clk);

            dut.mem[0] = corrupted_codeword;


            // Allow decoder to settle

            #1;


            // -------------------------------------------------
            // Classification
            // -------------------------------------------------

            class_count_1bit[error_class_dbg] =
                class_count_1bit[error_class_dbg] + 1;

            syndrome_count_1bit[syndrome_dbg] =
                syndrome_count_1bit[syndrome_dbg] + 1;


            if (single_error_corrected)
                one_bit_single = one_bit_single + 1;

            if (double_error_detected)
                one_bit_double = one_bit_double + 1;


            // -------------------------------------------------
            // Read corrected data
            // -------------------------------------------------

            @(posedge clk);

            #1;


            // -------------------------------------------------
            // Data verification
            // -------------------------------------------------

            if (rdata == expected_data) begin

                one_bit_correct =
                    one_bit_correct + 1;

            end

            else begin

                one_bit_incorrect =
                    one_bit_incorrect + 1;

            end


            // -------------------------------------------------
            // Expected classification
            //
            // Bits 0-11:
            // CLASS_SINGLE
            //
            // Bit 12:
            // CLASS_ODD_ZERO
            //
            // Both are valid for 1-bit faults.
            // -------------------------------------------------

            if (i < 12) begin

                if (error_class_dbg != 3'd1)
                    one_bit_unexpected =
                        one_bit_unexpected + 1;

            end

            else begin

                if (error_class_dbg != 3'd3)
                    one_bit_unexpected =
                        one_bit_unexpected + 1;

            end


            $display(
                "1BIT | BIT=%02d | CW=%013b | SYN=%02d | OP=%0b | CLASS=%0d | POS=%02d | CORR=%0b | DATA=%08b | %s",
                i,
                corrupted_codeword,
                syndrome_dbg,
                overall_parity_dbg,
                error_class_dbg,
                correction_position_dbg,
                correction_applied_dbg,
                rdata,
                (rdata == expected_data)
                    ? "CORRECT"
                    : "INCORRECT"
            );

        end


        // =====================================================
        // 2-BIT CAMPAIGN
        // =====================================================

        $display("");
        $display("==============================================================");
        $display("                 2-BIT FAULT CAMPAIGN");
        $display("==============================================================");


        for (i = 0; i < 12; i = i + 1) begin

            for (j = i + 1; j < 13; j = j + 1) begin

                test_number = test_number + 1;
                total_tests = total_tests + 1;

                two_bit_tests = two_bit_tests + 1;


                // -------------------------------------------------
                // Clean codeword
                // -------------------------------------------------

                corrupted_codeword =
                    original_codeword;


                // -------------------------------------------------
                // Inject two faults
                // -------------------------------------------------

                corrupted_codeword[i] =
                    ~corrupted_codeword[i];

                corrupted_codeword[j] =
                    ~corrupted_codeword[j];


                // -------------------------------------------------
                // Inject SRAM fault
                // -------------------------------------------------

                @(negedge clk);

                dut.mem[0] =
                    corrupted_codeword;


                #1;


                // -------------------------------------------------
                // Classification
                // -------------------------------------------------

                class_count_2bit[error_class_dbg] =
                    class_count_2bit[error_class_dbg] + 1;

                syndrome_count_2bit[syndrome_dbg] =
                    syndrome_count_2bit[syndrome_dbg] + 1;


                if (single_error_corrected)
                    two_bit_single =
                        two_bit_single + 1;

                if (double_error_detected)
                    two_bit_double =
                        two_bit_double + 1;


                // -------------------------------------------------
                // Read
                // -------------------------------------------------

                @(posedge clk);

                #1;


                // -------------------------------------------------
                // Data result
                //
                // SEC-DED detects the double fault but cannot
                // correct it. Therefore the requirement here is
                // DETECTION, not correct data.
                // -------------------------------------------------

                if (double_error_detected &&
                    (error_class_dbg == 3'd2)) begin

                    // Detection success

                end


                // -------------------------------------------------
                // Classification requirement
                // -------------------------------------------------

                if (error_class_dbg != 3'd2)
                    two_bit_unexpected =
                        two_bit_unexpected + 1;


                $display(
                    "2BIT | BITS=%02d,%02d | CW=%013b | SYN=%02d | OP=%0b | CLASS=%0d | POS=%02d | CORR=%0b | DATA=%08b",
                    i,
                    j,
                    corrupted_codeword,
                    syndrome_dbg,
                    overall_parity_dbg,
                    error_class_dbg,
                    correction_position_dbg,
                    correction_applied_dbg,
                    rdata
                );

            end

        end


        // =====================================================
        // 3-BIT CAMPAIGN
        // =====================================================

        $display("");
        $display("==============================================================");
        $display("                 3-BIT FAULT CAMPAIGN");
        $display("==============================================================");


        for (i = 0; i < 11; i = i + 1) begin

            for (j = i + 1; j < 12; j = j + 1) begin

                for (k = j + 1; k < 13; k = k + 1) begin

                    test_number = test_number + 1;
                    total_tests = total_tests + 1;

                    three_bit_tests =
                        three_bit_tests + 1;


                    // -------------------------------------------------
                    // Clean codeword
                    // -------------------------------------------------

                    corrupted_codeword =
                        original_codeword;


                    // -------------------------------------------------
                    // Inject three faults
                    // -------------------------------------------------

                    corrupted_codeword[i] =
                        ~corrupted_codeword[i];

                    corrupted_codeword[j] =
                        ~corrupted_codeword[j];

                    corrupted_codeword[k] =
                        ~corrupted_codeword[k];


                    // -------------------------------------------------
                    // Inject
                    // -------------------------------------------------

                    @(negedge clk);

                    dut.mem[0] =
                        corrupted_codeword;


                    #1;


                    // -------------------------------------------------
                    // Classification
                    // -------------------------------------------------

                    class_count_3bit[error_class_dbg] =
                        class_count_3bit[error_class_dbg] + 1;

                    syndrome_count_3bit[syndrome_dbg] =
                        syndrome_count_3bit[syndrome_dbg] + 1;


                    if (single_error_corrected)
                        three_bit_single =
                            three_bit_single + 1;

                    if (double_error_detected)
                        three_bit_double =
                            three_bit_double + 1;


                    case (error_class_dbg)

                        3'd0:
                            three_bit_no_error =
                                three_bit_no_error + 1;

                        3'd3:
                            three_bit_odd_zero =
                                three_bit_odd_zero + 1;

                        3'd4:
                            three_bit_invalid =
                                three_bit_invalid + 1;

                        default:
                            ;

                    endcase


                    // -------------------------------------------------
                    // Read
                    // -------------------------------------------------

                    @(posedge clk);

                    #1;


                    // -------------------------------------------------
                    // Data result
                    //
                    // For 3-bit faults, data correctness is measured
                    // only. It is NOT a SEC-DED requirement.
                    // -------------------------------------------------

                    if (rdata == expected_data)

                        three_bit_correct =
                            three_bit_correct + 1;

                    else

                        three_bit_incorrect =
                            three_bit_incorrect + 1;


                    // -------------------------------------------------
                    // Diagnostic output
                    // -------------------------------------------------

                    $display(
                        "3BIT | BITS=%02d,%02d,%02d | CW=%013b | SYN=%02d | OP=%0b | CLASS=%0d | POS=%02d | CORR=%0b | DATA=%08b | %s",
                        i,
                        j,
                        k,
                        corrupted_codeword,
                        syndrome_dbg,
                        overall_parity_dbg,
                        error_class_dbg,
                        correction_position_dbg,
                        correction_applied_dbg,
                        rdata,
                        (rdata == expected_data)
                            ? "CORRECT"
                            : "INCORRECT"
                    );

                end

            end

        end


        // =====================================================
        // FINAL RESULTS
        // =====================================================

        $display("");
        $display("==============================================================");
        $display("              EXHAUSTIVE CAMPAIGN RESULTS");
        $display("==============================================================");


        $display("");
        $display("Total tests performed           : %0d",
                 total_tests);

        $display("Expected total                  : 377");


        // =====================================================
        // 1-BIT RESULTS
        // =====================================================

        $display("");
        $display("--------------------------------------------------------------");
        $display("1-BIT RESULTS");
        $display("--------------------------------------------------------------");

        $display("Tests                           : %0d",
                 one_bit_tests);

        $display("Correct final data              : %0d",
                 one_bit_correct);

        $display("Incorrect final data            : %0d",
                 one_bit_incorrect);

        $display("Single correction flag          : %0d",
                 one_bit_single);

        $display("Double detection flag           : %0d",
                 one_bit_double);

        $display("Unexpected classification       : %0d",
                 one_bit_unexpected);


        // =====================================================
        // 2-BIT RESULTS
        // =====================================================

        $display("");
        $display("--------------------------------------------------------------");
        $display("2-BIT RESULTS");
        $display("--------------------------------------------------------------");

        $display("Tests                           : %0d",
                 two_bit_tests);

        $display("Correct final data              : %0d",
                 two_bit_correct);

        $display("Incorrect final data            : %0d",
                 two_bit_incorrect);

        $display("Single correction flag          : %0d",
                 two_bit_single);

        $display("Double detection flag           : %0d",
                 two_bit_double);

        $display("Unexpected classification       : %0d",
                 two_bit_unexpected);


        // =====================================================
        // 3-BIT RESULTS
        // =====================================================

        $display("");
        $display("--------------------------------------------------------------");
        $display("3-BIT RESULTS");
        $display("--------------------------------------------------------------");

        $display("Tests                           : %0d",
                 three_bit_tests);

        $display("Correct final data              : %0d",
                 three_bit_correct);

        $display("Incorrect final data            : %0d",
                 three_bit_incorrect);

        $display("Single correction flag          : %0d",
                 three_bit_single);

        $display("Double detection flag           : %0d",
                 three_bit_double);

        $display("NO_ERROR classification         : %0d",
                 three_bit_no_error);

        $display("ODD_ZERO classification         : %0d",
                 three_bit_odd_zero);

        $display("INVALID classification          : %0d",
                 three_bit_invalid);


        // =====================================================
        // CLASS DISTRIBUTION
        // =====================================================

        $display("");
        $display("==============================================================");
        $display("                  ERROR CLASS DISTRIBUTION");
        $display("==============================================================");


        $display("");
        $display("1-BIT:");

        $display("CLASS 0 NO_ERROR                 : %0d",
                 class_count_1bit[0]);

        $display("CLASS 1 SINGLE_CORRECTION        : %0d",
                 class_count_1bit[1]);

        $display("CLASS 2 DOUBLE_DETECTED          : %0d",
                 class_count_1bit[2]);

        $display("CLASS 3 ODD_ZERO                 : %0d",
                 class_count_1bit[3]);

        $display("CLASS 4 INVALID                  : %0d",
                 class_count_1bit[4]);


        $display("");
        $display("2-BIT:");

        $display("CLASS 0 NO_ERROR                 : %0d",
                 class_count_2bit[0]);

        $display("CLASS 1 SINGLE_CORRECTION        : %0d",
                 class_count_2bit[1]);

        $display("CLASS 2 DOUBLE_DETECTED          : %0d",
                 class_count_2bit[2]);

        $display("CLASS 3 ODD_ZERO                 : %0d",
                 class_count_2bit[3]);

        $display("CLASS 4 INVALID                  : %0d",
                 class_count_2bit[4]);


        $display("");
        $display("3-BIT:");

        $display("CLASS 0 NO_ERROR                 : %0d",
                 class_count_3bit[0]);

        $display("CLASS 1 SINGLE_CORRECTION        : %0d",
                 class_count_3bit[1]);

        $display("CLASS 2 DOUBLE_DETECTED          : %0d",
                 class_count_3bit[2]);

        $display("CLASS 3 ODD_ZERO                 : %0d",
                 class_count_3bit[3]);

        $display("CLASS 4 INVALID                  : %0d",
                 class_count_3bit[4]);


        // =====================================================
        // SYNDROME DISTRIBUTION
        // =====================================================

        $display("");
        $display("==============================================================");
        $display("                  SYNDROME DISTRIBUTION");
        $display("==============================================================");

        $display("");
        $display("SYNDROME | 1-BIT | 2-BIT | 3-BIT");

        for (i = 0; i < 16; i = i + 1) begin

            $display(
                "%04b     | %5d | %5d | %5d",
                i,
                syndrome_count_1bit[i],
                syndrome_count_2bit[i],
                syndrome_count_3bit[i]
            );

        end


        // =====================================================
        // SANITY CHECKS
        // =====================================================

        $display("");
        $display("==============================================================");
        $display("                    SANITY CHECKS");
        $display("==============================================================");

        $display("");
        $display("1-bit count:");
        $display("  Actual       = %0d", one_bit_tests);
        $display("  Expected     = 13");

        $display("");
        $display("2-bit count:");
        $display("  Actual       = %0d", two_bit_tests);
        $display("  Expected     = 78");

        $display("");
        $display("3-bit count:");
        $display("  Actual       = %0d", three_bit_tests);
        $display("  Expected     = 286");

        $display("");
        $display("Total count:");
        $display("  Actual       = %0d", total_tests);
        $display("  Expected     = 377");


        // =====================================================
        // FINAL VERIFICATION
        // =====================================================

        $display("");
        $display("==============================================================");
        $display("                    VERIFICATION STATUS");
        $display("==============================================================");


        if ((original_codeword != 13'b0) &&

            (one_bit_tests == 13) &&
            (one_bit_correct == 13) &&
            (one_bit_single == 13) &&
            (one_bit_double == 0) &&
            (one_bit_unexpected == 0) &&

            (two_bit_tests == 78) &&
            (two_bit_single == 0) &&
            (two_bit_double == 78) &&
            (two_bit_unexpected == 0) &&

            (three_bit_tests == 286) &&

            (total_tests == 377)) begin

            $display("");
            $display("RESULT: BASELINE SEC-DED VERIFICATION PASSED");
            $display("");
            $display("1-bit : 13/13 data recoveries");
            $display("2-bit : 78/78 faults detected");
            $display("3-bit : 286 cases characterized");
            $display("");
            $display("==============================================================");

        end

        else begin

            $display("");
            $display("RESULT: BASELINE VERIFICATION FAILED");
            $display("");
            $display("Inspect the detailed campaign output.");
            $display("");
            $display("==============================================================");

        end


        $finish;

    end

endmodule