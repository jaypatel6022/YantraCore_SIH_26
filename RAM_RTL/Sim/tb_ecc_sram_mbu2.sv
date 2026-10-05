`timescale 1ns/1ps

module tb_ecc_sram_mbu2;

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

    integer total_tests;
    integer detected_errors;
    integer incorrect_data;
    integer silent_errors;

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
        .double_error_detected  (double_error_detected)

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

        incorrect_data = 0;

        silent_errors = 0;


        // -----------------------------------------------------
        // Reset
        // -----------------------------------------------------

        repeat (3)
            @(posedge clk);

        rst = 1'b0;


        $display("");
        $display("================================================");
        $display("       SEC-DED TWO-BIT MBU CAMPAIGN");
        $display("================================================");

        $display(
            "Two-bit combinations : %0d",
            (CODE_WIDTH * (CODE_WIDTH - 1)) / 2
        );

        $display("");


        // =====================================================
        // TWO-BIT COMBINATION CAMPAIGN
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

                total_tests = total_tests + 1;


                // ------------------------------------------------
                // Restore clean codeword
                // ------------------------------------------------

                write_memory(
                    8'h00,
                    expected_data
                );


                // ------------------------------------------------
                // Inject two simultaneous bit upsets
                // ------------------------------------------------

                dut.mem[0][bit_a] =
                    ~dut.mem[0][bit_a];

                dut.mem[0][bit_b] =
                    ~dut.mem[0][bit_b];


                // ------------------------------------------------
                // Read corrupted codeword
                // ------------------------------------------------

                read_memory(8'h00);


                // ------------------------------------------------
                // Classification
                // ------------------------------------------------

                if (double_error_detected) begin

                    detected_errors =
                        detected_errors + 1;

                end

                else if (rdata != expected_data) begin

                    silent_errors =
                        silent_errors + 1;

                    $display(
                        "SILENT ERROR | TEST=%0d | BIT_A=%0d BIT_B=%0d | Expected=%b Actual=%b",
                        total_tests,
                        bit_a,
                        bit_b,
                        expected_data,
                        rdata
                    );

                end

                else begin

                    incorrect_data =
                        incorrect_data + 1;

                end

            end

        end


        // =====================================================
        // Final results
        // =====================================================

        $display("");

        $display("================================================");
        $display("       TWO-BIT MBU RESULTS");
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
            "Incorrect data     : %0d",
            incorrect_data
        );

        $display(
            "Silent errors      : %0d",
            silent_errors
        );


        if (total_tests != 0) begin

            $display(
                "Detection Rate     : %0.2f%%",
                (detected_errors * 100.0) /
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