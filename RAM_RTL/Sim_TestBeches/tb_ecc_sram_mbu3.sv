`timescale 1ns/1ps

module tb_ecc_sram_mbu3;

    parameter ADDR_WIDTH = 8;
    parameter DATA_WIDTH = 8;
    parameter CODE_WIDTH = 13;

    logic clk;
    logic rst;

    logic we;

    logic [ADDR_WIDTH-1:0] addr;

    logic [DATA_WIDTH-1:0] wdata;
    logic [DATA_WIDTH-1:0] rdata;

    logic single_error_corrected;
    logic double_error_detected;

    integer bit_a;
    integer bit_b;
    integer bit_c;

    integer total_tests;

    integer detected_errors;

    integer corrected_errors;

    integer silent_errors;

    integer wrong_output_errors;

    logic [DATA_WIDTH-1:0] expected_data;


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

        .double_error_detected (double_error_detected)

    );


    // =========================================================
    // Clock
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

        rst = 1'b1;

        we = 1'b0;

        addr = 8'h00;

        wdata = 8'h00;

        expected_data = 8'b10110110;

        total_tests = 0;

        detected_errors = 0;

        corrected_errors = 0;

        silent_errors = 0;

        wrong_output_errors = 0;


        // -----------------------------------------------------
        // Reset
        // -----------------------------------------------------

        repeat (3)
            @(posedge clk);

        rst = 1'b0;


        $display("");
        $display("================================================");
        $display("       SEC-DED THREE-BIT MBU CAMPAIGN");
        $display("================================================");

        $display(
            "Three-bit combinations : %0d",
            (CODE_WIDTH * (CODE_WIDTH - 1) * (CODE_WIDTH - 2)) / 6
        );

        $display("");


        // =====================================================
        // THREE-BIT COMBINATION CAMPAIGN
        // =====================================================

        for (
            bit_a = 0;
            bit_a < CODE_WIDTH;
            bit_a = bit_a + 1
        ) begin

            for (
                bit_b = bit_a + 1;
                bit_b < CODE_WIDTH;
                bit_b = bit_b + 1
            ) begin

                for (
                    bit_c = bit_b + 1;
                    bit_c < CODE_WIDTH;
                    bit_c = bit_c + 1
                ) begin

                    total_tests = total_tests + 1;


                    // ------------------------------------------------
                    // Restore clean word
                    // ------------------------------------------------

                    write_memory(
                        8'h00,
                        expected_data
                    );


                    // ------------------------------------------------
                    // Inject three simultaneous bit upsets
                    // ------------------------------------------------

                    dut.mem[0][bit_a] =
                        ~dut.mem[0][bit_a];

                    dut.mem[0][bit_b] =
                        ~dut.mem[0][bit_b];

                    dut.mem[0][bit_c] =
                        ~dut.mem[0][bit_c];


                    // ------------------------------------------------
                    // Read corrupted word
                    // ------------------------------------------------

                    read_memory(8'h00);


                    // ------------------------------------------------
                    // Classification
                    // ------------------------------------------------

                    if (
                        (rdata == expected_data) &&
                        (single_error_corrected == 1'b1)
                    ) begin

                        corrected_errors =
                            corrected_errors + 1;

                    end

                    else if (double_error_detected) begin

                        detected_errors =
                            detected_errors + 1;

                    end

                    else if (rdata != expected_data) begin

                        silent_errors =
                            silent_errors + 1;

                        $display(
                            "POTENTIAL SILENT ERROR | TEST=%0d | BITS=%0d,%0d,%0d | Expected=%b Actual=%b",
                            total_tests,
                            bit_a,
                            bit_b,
                            bit_c,
                            expected_data,
                            rdata
                        );

                    end

                    else begin

                        wrong_output_errors =
                            wrong_output_errors + 1;

                    end

                end

            end

        end


        // =====================================================
        // FINAL RESULTS
        // =====================================================

        $display("");

        $display("================================================");
        $display("       THREE-BIT MBU RESULTS");
        $display("================================================");

        $display(
            "Total combinations : %0d",
            total_tests
        );

        $display(
            "Detected           : %0d",
            detected_errors
        );

        $display(
            "Corrected          : %0d",
            corrected_errors
        );

        $display(
            "Silent errors      : %0d",
            silent_errors
        );

        $display(
            "Other wrong output : %0d",
            wrong_output_errors
        );


        if (total_tests != 0) begin

            $display(
                "Detection Rate     : %0.2f%%",
                (detected_errors * 100.0) /
                total_tests
            );

            $display(
                "Correction Rate    : %0.2f%%",
                (corrected_errors * 100.0) /
                total_tests
            );

            $display(
                "Silent Error Rate  : %0.2f%%",
                (silent_errors * 100.0) /
                total_tests
            );

        end


        $display("================================================");

        $finish;

    end

endmodule