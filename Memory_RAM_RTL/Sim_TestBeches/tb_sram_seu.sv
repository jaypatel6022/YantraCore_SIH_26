`timescale 1ns/1ps

module tb_sram_seu;

    // =========================================================
    // Parameters
    // =========================================================

    parameter ADDR_WIDTH = 8;
    parameter DATA_WIDTH = 8;
    parameter DEPTH      = 256;

    // =========================================================
    // DUT signals
    // =========================================================

    logic                   clk;
    logic                   rst;

    logic                   we;
    logic [ADDR_WIDTH-1:0]  addr;
    logic [DATA_WIDTH-1:0]  wdata;
    logic [DATA_WIDTH-1:0]  rdata;

    // =========================================================
    // Fault campaign variables
    // =========================================================

    integer fault_addr;
    integer fault_bit;

    integer total_faults;
    integer silent_errors;
    integer correct_reads;

    logic [DATA_WIDTH-1:0] expected_data;
    logic [DATA_WIDTH-1:0] corrupted_data;

    // =========================================================
    // DUT
    // =========================================================

    base_sram dut (
        .clk   (clk),
        .rst   (rst),
        .we    (we),
        .addr  (addr),
        .wdata (wdata),
        .rdata (rdata)
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
        // Initialize
        // -----------------------------------------------------

        rst   = 1'b1;
        we    = 1'b0;
        addr  = 8'h00;
        wdata = 8'h00;

        total_faults = 0;
        silent_errors = 0;
        correct_reads = 0;

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
        // FAULT CAMPAIGN
        //
        // Every memory location
        // Every bit position
        //
        // 256 × 8 = 2048 faults
        // =====================================================

        for (fault_addr = 0;
             fault_addr < DEPTH;
             fault_addr = fault_addr + 1) begin

            for (fault_bit = 0;
                 fault_bit < DATA_WIDTH;
                 fault_bit = fault_bit + 1) begin

                total_faults = total_faults + 1;

                // ------------------------------------------------
                // Write known data
                // ------------------------------------------------

                write_memory(
                    fault_addr[7:0],
                    expected_data
                );

                // ------------------------------------------------
                // Inject single-bit upset
                //
                // TESTBENCH ONLY
                // Not synthesizable
                // ------------------------------------------------

                dut.mem[fault_addr][fault_bit] =
                    ~dut.mem[fault_addr][fault_bit];

                // Capture corrupted value
                corrupted_data = dut.mem[fault_addr];

                // ------------------------------------------------
                // Read memory
                // ------------------------------------------------

                read_memory(
                    fault_addr[7:0]
                );

                // ------------------------------------------------
                // Check result
                // ------------------------------------------------

                if (rdata == expected_data) begin

                    correct_reads = correct_reads + 1;

                    $display(
                        "FAULT %0d | ADDR=%0d BIT=%0d | ",
                        "MASKED",
                        total_faults,
                        fault_addr,
                        fault_bit
                    );

                end

                else begin

                    silent_errors = silent_errors + 1;

                    $display(
                        "FAULT %0d | ADDR=%0d BIT=%0d | ",
                        "SILENT ERROR | Expected=%b Actual=%b",
                        total_faults,
                        fault_addr,
                        fault_bit,
                        expected_data,
                        rdata
                    );

                end

            end

        end

        // =====================================================
        // FINAL RESULTS
        // =====================================================

        $display("");
        $display("==============================================");
        $display("       BASELINE SEU FAULT CAMPAIGN");
        $display("==============================================");

        $display(
            "Total faults injected : %0d",
            total_faults
        );

        $display(
            "Correct reads         : %0d",
            correct_reads
        );

        $display(
            "Silent errors         : %0d",
            silent_errors
        );

        if (total_faults != 0) begin

            $display(
                "Silent Error Rate     : %0.2f%%",
                (silent_errors * 100.0) / total_faults
            );

            $display(
                "Fault Masking Rate    : %0.2f%%",
                (correct_reads * 100.0) / total_faults
            );

        end

        $display("==============================================");

        $finish;

    end

endmodule