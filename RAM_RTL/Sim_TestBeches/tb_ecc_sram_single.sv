`timescale 1ns/1ps

module tb_ecc_sram_single;

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

    integer fault_bit;

    integer passed;
    integer failed;

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

        // -----------------------------------------------------
        // Initialize
        // -----------------------------------------------------

        rst   = 1'b1;

        we    = 1'b0;

        addr  = 8'h00;

        wdata = 8'h00;

        expected_data = 8'b10110110;

        passed = 0;

        failed = 0;


        // -----------------------------------------------------
        // Reset
        // -----------------------------------------------------

        repeat (3)
            @(posedge clk);

        rst = 1'b0;


        $display("");
        $display("==============================================");
        $display("       ECC SRAM SINGLE-ADDRESS TEST");
        $display("==============================================");

        $display(
            "Expected data : %b",
            expected_data
        );


        // =====================================================
        // Test all 13 physical bits
        // =====================================================

        for (
            fault_bit = 0;
            fault_bit < CODE_WIDTH;
            fault_bit = fault_bit + 1
        ) begin

            // -------------------------------------------------
            // Write clean data
            // -------------------------------------------------

            write_memory(
                8'h00,
                expected_data
            );


            // -------------------------------------------------
            // Inject ONE physical bit upset
            // -------------------------------------------------

            dut.mem[0][fault_bit] =
                ~dut.mem[0][fault_bit];


            // -------------------------------------------------
            // Read corrupted memory
            // -------------------------------------------------

            read_memory(8'h00);


            // -------------------------------------------------
            // Check ECC result
            // -------------------------------------------------

            if (
                (rdata == expected_data) &&
                (single_error_corrected == 1'b1)
            ) begin

                passed = passed + 1;

                $display(
                    "BIT %0d : PASS | CORRECTED | DATA=%b",
                    fault_bit,
                    rdata
                );

            end
            else begin

                failed = failed + 1;

                $display(
                    "BIT %0d : FAIL | DATA=%b | CORRECT=%b",
                    fault_bit,
                    rdata,
                    single_error_corrected
                );

            end

        end


        // =====================================================
        // Final result
        // =====================================================

        $display("");

        $display("==============================================");

        $display(
            "Single-bit faults tested : %0d",
            CODE_WIDTH
        );

        $display(
            "Passed                  : %0d",
            passed
        );

        $display(
            "Failed                  : %0d",
            failed
        );


        if (failed == 0)

            $display(
                "RESULT                  : PASS"
            );

        else

            $display(
                "RESULT                  : FAIL"
            );


        $display("==============================================");

        $finish;

    end

endmodule