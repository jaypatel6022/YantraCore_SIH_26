`timescale 1ns/1ps
// ============================================================================
// Nexys A7 demo : radiation-hardened (TMR + watchdog) control unit  vs.
//                 an identical PLAIN (unprotected) control unit.
// Same port names as the RAM demo -> reuse nexys_a7.xdc unchanged.
//
// Both controllers get the same sensor inputs and the same SEU injection. The
// hardened one outvotes and heals the upset; the plain one is corrupted.
//
// ---------------------------------------------------------------- INPUTS
//  SW[15:12]  T_electronics code n_e (0..15)  ->  degC = -40 + 10*n_e
//  SW[11:8]   T_battery     code n_b (0..15)  ->  degC = -40 + 10*n_b
//  SW[7]      STALL  : freeze the hardened core (watchdog demo)
//  SW[6]      (unused)
//  SW[5:4]    SEU target copy inside the TMR core: 0 = A, 1 = B, 2 = C
//  SW[3]      fault_cleared
//  SW[2]      idle_flag
//  SW[1]      moisture_flag
//  SW[0]      arc_risk_flag
//  BTNL       inject SEU: flip bit k in the plain controller AND in one TMR copy
//  BTNR       k = k+1 (0..6), shown on LED[14:12]
//             k: 0 alert, 1 charge_enable, 2 heat_to_battery, 3 heater_on,
//                4 mode[0], 5 mode[1], 6 heartbeat (TMR only)
//  BTNC       reset
//  BTNU, BTND unused
//
// -------------------------------------------------------------- 7-SEGMENT
//   AN7 AN6 AN5 | AN4 AN3 AN2 | AN1    | AN0
//   T_electronics| T_battery   | TMR mode | PLAIN mode        (degC, mode 0..3)
//   mode: 0 cold-start, 1 normal, 2 storage, 3 fault
//
// ------------------------------------------------------------------ LEDs
//   LED[0] heater_on   LED[1] heat_to_battery   LED[2] charge_enable  LED[3] alert    (HARDENED)
//   LED[4] heater_on   LED[5] heat_to_battery   LED[6] charge_enable  LED[7] alert    (PLAIN)
//   LED[8]  outputs of hardened and plain controllers agree
//   LED[9]  TMR is currently correcting an upset (stretched blink)
//   LED[10] TMR has corrected an upset since reset (sticky)
//   LED[11] watchdog has fired since reset (sticky)
//   LED[14:12] SEU bit index k      LED[15] heartbeat
//
// Thresholds (parameters) are in units of 0.1 degC. With the 10 degC switch
// steps, keep each threshold BETWEEN two steps (e.g. 5, 15, 85 degC).
// ============================================================================
module control_unit_fpga_top #(
    parameter integer CLK_FREQ_HZ = 100_000_000,
    parameter integer DEBOUNCE_MS = 20,
    parameter integer SAMPLE_HZ   = 100,
    // *** set equal to your Simulink workspace values (0.1 degC units) ***
    parameter signed [15:0] T_BOOT_THRESHOLD = 16'sd50,
    parameter signed [15:0] T_TARGET         = 16'sd150,
    parameter signed [15:0] T_STORAGE_MIN    = 16'sd50,
    parameter signed [15:0] T_OVERHEAT       = 16'sd850,
    parameter signed [15:0] T_CHARGE_MIN     = 16'sd0,
    parameter bit           LATCH_ALERT      = 1'b0
)(
    input  logic        CLK100MHZ,
    input  logic        BTNC, BTNU, BTND, BTNL, BTNR,
    input  logic [15:0] SW,
    output logic [15:0] LED,
    output logic [6:0]  SEG,
    output logic        DP,
    output logic [7:0]  AN
);

    // ---------------- reset ----------------
    logic [1:0] rst_ff = 2'b11;
    logic       rst;
    always_ff @(posedge CLK100MHZ) rst_ff <= {rst_ff[0], BTNC};
    assign rst = rst_ff[1];

    // ---------------- switch synchroniser (2 flops) ----------------
    logic [15:0] sw_s1, sw_s2;
    always_ff @(posedge CLK100MHZ) begin
        sw_s1 <= SW;
        sw_s2 <= sw_s1;
    end

    logic [3:0] code_e, code_b;
    logic       sw_stall, sw_fault_cleared, sw_idle, sw_moist, sw_arc;
    logic [1:0] sw_seu_copy;

    assign code_e           = sw_s2[15:12];
    assign code_b           = sw_s2[11:8];
    assign sw_stall         = sw_s2[7];
    assign sw_seu_copy      = sw_s2[5:4];
    assign sw_fault_cleared = sw_s2[3];
    assign sw_idle          = sw_s2[2];
    assign sw_moist         = sw_s2[1];
    assign sw_arc           = sw_s2[0];

    // switch code -> temperature in 0.1 degC:  (-40 + 10*n) degC
    function automatic logic signed [15:0] code_to_t(input logic [3:0] n);
        code_to_t = $signed({12'b0, n}) * 16'sd100 - 16'sd400;
    endfunction

    logic signed [15:0] T_electronics, T_battery;
    assign T_electronics = code_to_t(code_e);
    assign T_battery     = code_to_t(code_b);

    // ---------------- buttons ----------------
    logic btn_seu, btn_next;

    button_debounce #(.CLK_FREQ_HZ(CLK_FREQ_HZ), .DEBOUNCE_MS(DEBOUNCE_MS))
        db_s (.clk(CLK100MHZ), .rst(rst), .btn_in(BTNL), .btn_pulse(btn_seu));
    button_debounce #(.CLK_FREQ_HZ(CLK_FREQ_HZ), .DEBOUNCE_MS(DEBOUNCE_MS))
        db_n (.clk(CLK100MHZ), .rst(rst), .btn_in(BTNR), .btn_pulse(btn_next));

    // ---------------- SEU bit select ----------------
    logic [2:0] seu_k;
    always_ff @(posedge CLK100MHZ) begin
        if (rst)           seu_k <= 3'd0;
        else if (btn_next) seu_k <= (seu_k == 3'd6) ? 3'd0 : seu_k + 3'd1;
    end

    // ---------------- hardened controller ----------------
    logic       h_t, hb_t, ch_t, al_t;
    logic [1:0] mode_t;
    logic       sample_tick, tmr_mismatch, tmr_mismatch_seen, wdt_seen;

    control_unit_top #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ), .SAMPLE_HZ(SAMPLE_HZ), .WDT_MISSED_SAMPLES(4),
        .T_BOOT_THRESHOLD(T_BOOT_THRESHOLD), .T_TARGET(T_TARGET),
        .T_STORAGE_MIN(T_STORAGE_MIN), .T_OVERHEAT(T_OVERHEAT),
        .T_CHARGE_MIN(T_CHARGE_MIN), .LATCH_ALERT(LATCH_ALERT)
    ) u_hard (
        .clk(CLK100MHZ), .rst(rst),
        .T_electronics(T_electronics), .T_battery(T_battery),
        .arc_risk_flag(sw_arc), .moisture_flag(sw_moist),
        .idle_flag(sw_idle), .fault_cleared(sw_fault_cleared),
        .stall(sw_stall),
        .seu_pulse(btn_seu), .seu_copy(sw_seu_copy), .seu_bit(seu_k),
        .heater_on(h_t), .heat_to_battery(hb_t), .charge_enable(ch_t),
        .alert(al_t), .active_mode(mode_t),
        .sample_tick(sample_tick),
        .tmr_mismatch(tmr_mismatch), .tmr_mismatch_seen(tmr_mismatch_seen),
        .wdt_timeout_seen(wdt_seen)
    );

    // ---------------- plain (unprotected) reference controller ----------------
    logic       h_p, hb_p, ch_p, al_p;
    logic [1:0] mode_p;
    logic [5:0] plain_flip;

    always_comb begin
        plain_flip = 6'b0;
        if (seu_k <= 3'd5) plain_flip[seu_k] = btn_seu;   // bit 6 (heartbeat) exists only in the TMR core
    end

    control_unit #(
        .T_BOOT_THRESHOLD(T_BOOT_THRESHOLD), .T_TARGET(T_TARGET),
        .T_STORAGE_MIN(T_STORAGE_MIN), .T_OVERHEAT(T_OVERHEAT),
        .T_CHARGE_MIN(T_CHARGE_MIN), .LATCH_ALERT(LATCH_ALERT)
    ) u_plain (
        .clk(CLK100MHZ), .rst(rst), .tick(sample_tick),
        .T_electronics(T_electronics), .T_battery(T_battery),
        .arc_risk_flag(sw_arc), .moisture_flag(sw_moist),
        .idle_flag(sw_idle), .fault_cleared(sw_fault_cleared),
        .seu_flip(plain_flip),
        .heater_on(h_p), .heat_to_battery(hb_p), .charge_enable(ch_p),
        .alert(al_p), .active_mode(mode_p)
    );

    // ---------------- display ----------------
    localparam logic [4:0] SYM_BLANK = 5'h10;
    localparam logic [4:0] SYM_MINUS = 5'h11;

    // returns {hundreds/sign, tens, ones} symbols for (-40 + 10*n) degC
    function automatic logic [14:0] temp_syms(input logic [3:0] n);
        logic [3:0] k;
        logic [4:0] h, t;
        if (n < 4'd4) begin                       // -40 .. -10
            k = 4'd4 - n;
            h = SYM_MINUS;
            t = {1'b0, k};
        end else begin
            k = n - 4'd4;                         // 0 .. 11  (tens of degC)
            if (k >= 4'd10) begin                 // 100, 110
                h = 5'd1;
                t = {1'b0, k - 4'd10};
            end else begin
                h = SYM_BLANK;
                t = (k == 4'd0) ? SYM_BLANK : {1'b0, k};
            end
        end
        temp_syms = {h, t, 5'd0};
    endfunction

    logic [39:0] symbols;
    assign symbols = {temp_syms(code_e), temp_syms(code_b), {3'b0, mode_t}, {3'b0, mode_p}};

    seven_segment_8digit_sym #(.CLK_FREQ_HZ(CLK_FREQ_HZ), .REFRESH_HZ(1000)) seven_seg (
        .clk(CLK100MHZ), .rst(rst), .symbols(symbols),
        .seg(SEG), .dp(DP), .an(AN)
    );

    // ---------------- LEDs ----------------
    localparam integer STRETCH = (CLK_FREQ_HZ / 6 > 1) ? (CLK_FREQ_HZ / 6) : 2;   // ~0.17 s
    logic [$clog2(STRETCH+1)-1:0] mism_cnt;
    logic [26:0] hb_cnt;

    always_ff @(posedge CLK100MHZ) begin
        hb_cnt <= hb_cnt + 1'b1;
        if (rst)               mism_cnt <= '0;
        else if (tmr_mismatch) mism_cnt <= STRETCH[$clog2(STRETCH+1)-1:0];
        else if (mism_cnt != 0) mism_cnt <= mism_cnt - 1'b1;
    end

    logic agree;
    assign agree = ({mode_t, h_t, hb_t, ch_t, al_t} == {mode_p, h_p, hb_p, ch_p, al_p});

    always_comb begin
        LED       = 16'h0000;
        LED[0]    = h_t;
        LED[1]    = hb_t;
        LED[2]    = ch_t;
        LED[3]    = al_t;
        LED[4]    = h_p;
        LED[5]    = hb_p;
        LED[6]    = ch_p;
        LED[7]    = al_p;
        LED[8]    = agree;
        LED[9]    = (mism_cnt != 0);
        LED[10]   = tmr_mismatch_seen;
        LED[11]   = wdt_seen;
        LED[14:12]= seu_k;
        LED[15]   = hb_cnt[26];
    end

endmodule
