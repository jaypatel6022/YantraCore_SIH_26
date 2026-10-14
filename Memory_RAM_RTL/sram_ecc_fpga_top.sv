`timescale 1ns/1ps

// ============================================================================
// Nexys A7 : base_sram vs ecc_sram, with a visible "corrupt -> auto-correct
// -> scrub" story.
//
//  SW[15:8]  address        SW[7:0]  write data
//  BTNU  write (same addr/data into BOTH RAMs)
//  BTNL  inject SEU: flip data bit k at the current address in BOTH RAMs
//  BTNR  k = k+1 (0..7), shown on LED[6:4]
//  BTND  SCRUB: rewrite ECC RAM's stored codeword at the current address
//        with the corrected data (repairs storage; a one-shot scrubber)
//  BTNC  reset
//
//  Reads are continuous: displayed values track SW[15:8] every cycle, no
//  read button needed.
//
//  7-segment (all 8 digits, hex, left to right):
//     AN7 AN6 | AN5 AN4 | AN3 AN2 | AN1 AN0
//     ECC     | ECC     | BASE    | address
//     corrected| raw/stored |      |
//
//  LED0 = ECC raw == ECC corrected   (storage currently clean)
//  LED1 = ECC single-error corrected (this cycle)
//  LED2 = ECC double/uncorrectable error detected
//  LED3 = BASE == ECC corrected      (unprotected RAM currently right)
//  LED[6:4] = SEU bit index k
//  LED15 = heartbeat
// ============================================================================
module sram_ecc_fpga_top #(
    parameter integer CLK_FREQ_HZ = 100_000_000,
    parameter integer DEBOUNCE_MS = 20
)(
    input  logic        CLK100MHZ,
    input  logic        BTNC, BTNU, BTND, BTNL, BTNR,
    input  logic [15:0] SW,
    output logic [15:0] LED,
    output logic [6:0]  SEG,
    output logic        DP,
    output logic [7:0]  AN
);

    // ---------------- reset: synchronise the raw button ----------------
    logic [1:0] rst_ff = 2'b11;
    logic       rst;
    always_ff @(posedge CLK100MHZ) rst_ff <= {rst_ff[0], BTNC};
    assign rst = rst_ff[1];

    // ---------------- buttons ----------------
    logic btn_write, btn_scrub, btn_seu, btn_next;

    button_debounce #(.CLK_FREQ_HZ(CLK_FREQ_HZ), .DEBOUNCE_MS(DEBOUNCE_MS))
        db_w (.clk(CLK100MHZ), .rst(rst), .btn_in(BTNU), .btn_pulse(btn_write));
    button_debounce #(.CLK_FREQ_HZ(CLK_FREQ_HZ), .DEBOUNCE_MS(DEBOUNCE_MS))
        db_scr (.clk(CLK100MHZ), .rst(rst), .btn_in(BTND), .btn_pulse(btn_scrub));
    button_debounce #(.CLK_FREQ_HZ(CLK_FREQ_HZ), .DEBOUNCE_MS(DEBOUNCE_MS))
        db_s (.clk(CLK100MHZ), .rst(rst), .btn_in(BTNL), .btn_pulse(btn_seu));
    button_debounce #(.CLK_FREQ_HZ(CLK_FREQ_HZ), .DEBOUNCE_MS(DEBOUNCE_MS))
        db_n (.clk(CLK100MHZ), .rst(rst), .btn_in(BTNR), .btn_pulse(btn_next));

    // ---------------- SEU bit select ----------------
    logic [2:0] seu_k;
    always_ff @(posedge CLK100MHZ) begin
        if (rst)           seu_k <= 3'd0;
        else if (btn_next) seu_k <= seu_k + 3'd1;
    end

    // data bit k -> physical position inside the 13-bit ECC codeword
    function automatic logic [3:0] ecc_pos(input logic [2:0] k);
        case (k)
            3'd0: ecc_pos = 4'd2;
            3'd1: ecc_pos = 4'd4;
            3'd2: ecc_pos = 4'd5;
            3'd3: ecc_pos = 4'd6;
            3'd4: ecc_pos = 4'd8;
            3'd5: ecc_pos = 4'd9;
            3'd6: ecc_pos = 4'd10;
            default: ecc_pos = 4'd11;
        endcase
    endfunction

    // ---------------- the two memories ----------------
    logic [7:0] sram_addr, sram_wdata;
    assign sram_addr  = SW[15:8];
    assign sram_wdata = SW[7:0];

    logic [7:0] base_rdata;
    logic [7:0] ecc_rdata, ecc_rdata_raw;
    logic       ecc_sec, ecc_ded;

    base_sram base_memory (
        .clk        (CLK100MHZ),
        .rst        (rst),
        .we         (btn_write),
        .addr       (sram_addr),
        .wdata      (sram_wdata),
        .seu_inject (btn_seu),
        .seu_bit    (seu_k),
        .rdata      (base_rdata)
    );

    ecc_sram #(.ADDR_WIDTH(8), .DATA_WIDTH(8), .CODE_WIDTH(13), .DEPTH(256))
    ecc_memory (
        .clk                    (CLK100MHZ),
        .rst                    (rst),
        .we                     (btn_write),
        .addr                   (sram_addr),
        .wdata                  (sram_wdata),
        .rdata                  (ecc_rdata),
        .rdata_raw              (ecc_rdata_raw),
        .single_error_corrected (ecc_sec),
        .double_error_detected  (ecc_ded),
        .seu_inject             (btn_seu),
        .seu_bit                (ecc_pos(seu_k)),
        .scrub                  (btn_scrub)
    );

    // ---------------- display: all 4 values, all 8 digits, no gaps ----------------
    seven_segment_8digit #(.CLK_FREQ_HZ(CLK_FREQ_HZ), .REFRESH_HZ(1000)) seven_seg (
        .clk   (CLK100MHZ),
        .rst   (rst),
        .value ({ecc_rdata, ecc_rdata_raw, base_rdata, sram_addr}),
        .blank (8'h00),
        .seg   (SEG),
        .dp    (DP),
        .an    (AN)
    );

    // ---------------- LEDs ----------------
    logic [26:0] hb;
    always_ff @(posedge CLK100MHZ) hb <= hb + 1'b1;

    always_comb begin
        LED      = 16'h0000;
        LED[0]   = (ecc_rdata_raw == ecc_rdata);   // storage clean (no residual flip)
        LED[1]   = ecc_sec;
        LED[2]   = ecc_ded;
        LED[3]   = (base_rdata == ecc_rdata);      // unprotected RAM currently correct
        LED[6:4] = seu_k;
        LED[15]  = hb[26];
    end

endmodule
