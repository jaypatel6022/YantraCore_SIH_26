`timescale 1ns/1ps

module tb_ecc_sram_seu;

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

    logic clk;
    logic rst;

    logic we;

    logic [ADDR_WIDTH-1:0] addr;

    logic [DATA_WIDTH-1:0] wdata;
    logic [DATA_WIDTH-1:0] rdata;


    // =========================================================
    // ECC status
    // =========================================================

    logic single_error_corrected;
    logic double_error_detected;


    // =========================================================
    // Fault campaign variables
    // =========================================================

    integer fault_addr;
    integer fault_bit;

    integer total_faults;

    integer corrected_errors;

    integer detected_errors;

    integer silent_errors;

    integer unexpected_errors;


    // =========================================================
    // Test data
    // =========================================================

    logic [DATA_WIDTH-1:0] expected_data;


    // =========================================================
    // Waveform observation signals
    //
    // These exist purely so the corrupted word and the
    // corrected/read-back word show up as clean, stable
    // signals in the wave viewer instead of having to be
    // reverse-engineered from $display text or from a
    // continuously-changing loop variable.
    // =========================================================

    // Raw physical codeword stored in memory, BEFORE the
    // single-bit upset is injected (clean reference word).
    logic [CODE_WIDTH-1:0] clean_codeword;

    // Raw physical codeword stored in memory, AFTER the
    // single-bit upset is injected (this is the "corrupted
    // data" - the actual bits sitting in the SRAM array).
    logic [CODE_WIDTH-1:0] corrupted_codeword;

    // DUT's data output latched right after each read. This
    // is the "corrected data" (or whatever the ECC decoder
    // produced, including a possibly-wrong value on an
    // unexpected/miscorrected result).
    logic [DATA_WIDTH-1:0] corrected_data_out;

    // Registered copies of the loop counters. fault_addr and
    // fault_bit change continuously inside the for-loops and
    // don't give you a clean edge to anchor on in the
    // waveform - these hold steady for the duration of each
    // fault iteration.
    integer fault_addr_r;
    integer fault_bit_r;

    // One code per fault outcome, so you can group/color by
    // result in the wave viewer instead of reading $display
    // text:
    //   0 = corrected   (single_error_corrected, data restored)
    //   1 = detected     (double_error_detected)
    //   2 = silent        (wrong data, no flag raised)
    //   3 = unexpected  (none of the above matched)
    logic [1:0] fault_result;

    localparam FAULT_RESULT_CORRECTED  = 2'd0;
    localparam FAULT_RESULT_DETECTED   = 2'd1;
    localparam FAULT_RESULT_SILENT     = 2'd2;
    localparam FAULT_RESULT_UNEXPECTED = 2'd3;

    // Toggles once per fault iteration - use this as a
    // step marker to jump fault-by-fault in the wave viewer.
    logic fault_strobe;


    // =========================================================
    // DUT
    // =========================================================

    ecc_sram dut (

        .clk   (clk),
        .rst   (rst),

        .we    (we),
        .addr  (addr),

        .wdata (wdata),
        .rdata (rdata),

        .single_error_corrected (single_error_corrected),

        .double_error_detected   (double_error_detected)

    );


    // =========================================================
    // Clock generation
    // =========================================================

    initial begin

        clk = 1'b0;

        forever #5 clk = ~clk;

    end


    // =========================================================
    // Write task
    // =========================================================

    task automatic write_memory(

        input logic [7:0] write_addr,

        input logic [7:0] write_data

    );

        begin

            @(negedge clk);

            we    = 1'b1;

            addr  = write_addr;

            wdata = write_data;

            @(negedge clk);

            we = 1'b0;

        end

    endtask


    // =========================================================
    // Read task
    // =========================================================

    task automatic read_memory(

        input logic [7:0] read_addr

    );

        begin

            @(negedge clk);

            we   = 1'b0;

            addr = read_addr;

            @(posedge clk);

            #1;

        end

    endtask


    // =========================================================
    // Main test
    // =========================================================

    initial begin

        // -----------------------------------------------------
        // Waveform dump
        //
        // Generic VCD dump so this works the same way across
        // Icarus / ModelSim / Questa / Vivado xsim. If your
        // simulator/GUI has its own signal-logging flow (e.g.
        // a .do file with `log -r /*` in ModelSim/Questa), you
        // can use that instead - this is just the portable
        // default.
        // -----------------------------------------------------

        $dumpfile("tb_ecc_sram_seu.vcd");
        $dumpvars(0, tb_ecc_sram_seu);


        // -----------------------------------------------------
        // Initialize
        // -----------------------------------------------------

        rst   = 1'b1;

        we    = 1'b0;

        addr  = 8'h00;

        wdata = 8'h00;


        total_faults     = 0;

        corrected_errors = 0;

        detected_errors  = 0;

        silent_errors    = 0;

        unexpected_errors = 0;

        fault_addr_r        = 0;
        fault_bit_r          = 0;
        clean_codeword       = '0;
        corrupted_codeword = '0;
        corrected_data_out = '0;
        fault_result         = FAULT_RESULT_CORRECTED;
        fault_strobe          = 1'b0;


        // -----------------------------------------------------
        // Reset
        // -----------------------------------------------------

        repeat (3)
            @(posedge clk);

        rst = 1'b0;


        // -----------------------------------------------------
        // Known test pattern
        // -----------------------------------------------------

        expected_data = 8'b10110110;


        // =====================================================
        // START CAMPAIGN
        // =====================================================

        $display("");
        $display("================================================");
        $display("       ECC-PROTECTED SRAM SEU CAMPAIGN");
        $display("================================================");

        $display(
            "Memory depth          : %0d",
            DEPTH
        );

        $display(
            "Physical bits/word    : %0d",
            CODE_WIDTH
        );

        $display(
            "Expected fault count  : %0d",
            DEPTH * CODE_WIDTH
        );

        $display("");


        // =====================================================
        // FAULT CAMPAIGN
        //
        // 256 addresses x 13 physical bits
        // =====================================================

        for (
            fault_addr = 0;
            fault_addr < DEPTH;
            fault_addr = fault_addr + 1
        ) begin


            for (
                fault_bit = 0;
                fault_bit < CODE_WIDTH;
                fault_bit = fault_bit + 1
            ) begin


                total_faults = total_faults + 1;

                // Hold stable, waveform-friendly copies of the
                // loop counters for this iteration.
                fault_addr_r = fault_addr;
                fault_bit_r  = fault_bit;


                // ------------------------------------------------
                // Restore clean memory word
                // ------------------------------------------------

                write_memory(
                    fault_addr[7:0],
                    expected_data
                );

                // Capture the clean, pre-fault codeword exactly
                // as it sits in the memory array.
                clean_codeword = dut.mem[fault_addr];


                // ------------------------------------------------
                // Inject exactly ONE physical bit upset
                //
                // TESTBENCH ONLY
                // NOT SYNTHESIZABLE
                // ------------------------------------------------

                dut.mem[fault_addr][fault_bit] =
                    ~dut.mem[fault_addr][fault_bit];

                // Capture the corrupted codeword - this is the
                // actual "corrupted data" sitting in the SRAM
                // array after the upset, before any ECC decode.
                corrupted_codeword = dut.mem[fault_addr];


                // ------------------------------------------------
                // Read corrupted word
                // ------------------------------------------------

                read_memory(
                    fault_addr[7:0]
                );

                // Latch the DUT's output data into its own
                // signal - this is the "corrected data" (or
                // whatever the decoder produced).
                corrected_data_out = rdata;


                // ------------------------------------------------
                // Evaluate result
                // ------------------------------------------------

                if (
                    (rdata == expected_data) &&
                    (single_error_corrected == 1'b1)
                ) begin

                    corrected_errors =
                        corrected_errors + 1;

                    fault_result = FAULT_RESULT_CORRECTED;


                end

                else if (double_error_detected) begin

                    detected_errors =
                        detected_errors + 1;

                    fault_result = FAULT_RESULT_DETECTED;


                end

                else if (rdata != expected_data) begin

                    silent_errors =
                        silent_errors + 1;

                    fault_result = FAULT_RESULT_SILENT;


                    // Print failures only.
                    //
                    // This keeps the TCL console manageable
                    // during the 3328-fault campaign.

                    $display(
                        "SILENT ERROR | FAULT=%0d ADDR=%0d BIT=%0d | Expected=%b Actual=%b",
                        total_faults,
                        fault_addr,
                        fault_bit,
                        expected_data,
                        rdata
                    );

                end

                else begin

                    unexpected_errors =
                        unexpected_errors + 1;

                    fault_result = FAULT_RESULT_UNEXPECTED;

                end

                // Step marker: one toggle per completed fault,
                // so you can jump iteration-by-iteration in the
                // wave viewer using this edge.
                fault_strobe = ~fault_strobe;


                // ------------------------------------------------
                // Progress indicator
                // ------------------------------------------------

                if ((total_faults % 256) == 0) begin

                    $display(
                        "Progress: %0d / %0d faults completed",
                        total_faults,
                        DEPTH * CODE_WIDTH
                    );

                end

            end

        end


        // =====================================================
        // FINAL RESULTS
        // =====================================================

        $display("");

        $display("================================================");

        $display("       FINAL ECC SEU CAMPAIGN RESULTS");

        $display("================================================");


        $display(
            "Total faults injected : %0d",
            total_faults
        );


        $display(
            "Corrected errors      : %0d",
            corrected_errors
        );


        $display(
            "Detected errors       : %0d",
            detected_errors
        );


        $display(
            "Silent errors         : %0d",
            silent_errors
        );


        $display(
            "Unexpected results    : %0d",
            unexpected_errors
        );


        // =====================================================
        // Percentages
        // =====================================================

        if (total_faults != 0) begin

            $display(
                "Correction Rate       : %0.2f%%",
                (corrected_errors * 100.0) /
                total_faults
            );


            $display(
                "Detection Rate        : %0.2f%%",
                (detected_errors * 100.0) /
                total_faults
            );


            $display(
                "Silent Error Rate     : %0.2f%%",
                (silent_errors * 100.0) /
                total_faults
            );

        end


        // =====================================================
        // Overall verdict
        // =====================================================

        $display("");

        if (
            (total_faults == DEPTH * CODE_WIDTH) &&
            (corrected_errors == total_faults) &&
            (silent_errors == 0) &&
            (detected_errors == 0) &&
            (unexpected_errors == 0)
        ) begin

            $display(
                "RESULT: PASS - ALL SINGLE-BIT SEUs CORRECTED"
            );

        end

        else begin

            $display(
                "RESULT: REVIEW REQUIRED"
            );

        end


        $display("================================================");


        $finish;

    end

endmodule