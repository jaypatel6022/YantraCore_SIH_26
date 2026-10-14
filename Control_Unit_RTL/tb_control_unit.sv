`timescale 1ns/1ps
// Self-checking testbench:
//  1. plain control_unit vs. the Stateflow chart (expected values by hand)
//  2. control_unit_tmr == control_unit on random + directed stimulus, with single-copy SEUs injected
//  3. watchdog_timer unit test
//  4. control_unit_top (tick + TMR + watchdog) smoke test with SEU injection
module tb_control_unit;
    logic clk = 0;
    always #5 clk = ~clk;

    integer errors = 0;
    task automatic check(input string what, input logic cond);
        if (!cond) begin errors++; $display("FAIL @%0t: %s", $time, what); end
    endtask

    // ---------------- stimulus ----------------
    logic rst;
    logic signed [15:0] T_el, T_bat;
    logic arc, moist, idle, fclr;

    // ---------------- DUT 1: plain ----------------
    logic h1, hb1, ch1, al1; logic [1:0] m1;
    control_unit u_plain (.clk, .rst, .tick(1'b1),
        .T_electronics(T_el), .T_battery(T_bat),
        .arc_risk_flag(arc), .moisture_flag(moist), .idle_flag(idle), .fault_cleared(fclr),
        .seu_flip(6'b0),
        .heater_on(h1), .heat_to_battery(hb1), .charge_enable(ch1), .alert(al1), .active_mode(m1));

    // ---------------- DUT 2: TMR ----------------
    logic h2, hb2, ch2, al2; logic [1:0] m2; logic hbeat, mism, mism_seen;
    logic [6:0] fa = 0, fb = 0, fc = 0;
    control_unit_tmr u_tmr (.clk, .rst, .tick(1'b1),
        .T_electronics(T_el), .T_battery(T_bat),
        .arc_risk_flag(arc), .moisture_flag(moist), .idle_flag(idle), .fault_cleared(fclr),
        .seu_flip_a(fa), .seu_flip_b(fb), .seu_flip_c(fc),
        .heater_on(h2), .heat_to_battery(hb2), .charge_enable(ch2), .alert(al2), .active_mode(m2),
        .heartbeat(hbeat), .tmr_mismatch(mism), .tmr_mismatch_seen(mism_seen));

    // ---------------- DUT 3: watchdog ----------------
    logic wd_kick = 0, wd_to, wd_seen, wd_rst = 1;
    watchdog_timer #(.TIMEOUT_CLKS(8)) u_wd (.clk, .rst(wd_rst), .kick(wd_kick), .timeout(wd_to), .timeout_seen(wd_seen));

    // ---------------- DUT 4: hardened top ----------------
    logic h4, hb4, ch4, al4; logic [1:0] m4; logic mism4, mism4_seen, wdt4_seen, stall4 = 0, tick4;
    logic seu_p = 0; logic [1:0] seu_c = 0; logic [2:0] seu_b = 0;
    control_unit_top #(.CLK_FREQ_HZ(1000), .SAMPLE_HZ(100), .WDT_MISSED_SAMPLES(4)) u_top (
        .clk, .rst,
        .T_electronics(T_el), .T_battery(T_bat),
        .arc_risk_flag(arc), .moisture_flag(moist), .idle_flag(idle), .fault_cleared(fclr),
        .stall(stall4), .seu_pulse(seu_p), .seu_copy(seu_c), .seu_bit(seu_b),
        .heater_on(h4), .heat_to_battery(hb4), .charge_enable(ch4), .alert(al4), .active_mode(m4),
        .sample_tick(tick4), .tmr_mismatch(mism4), .tmr_mismatch_seen(mism4_seen), .wdt_timeout_seen(wdt4_seen));

    task automatic step(input integer n = 1);
        repeat (n) @(posedge clk);
        #1;
    endtask

    task automatic expect_out(input string tag, input logic [1:0] m, input logic h, input logic hb,
                              input logic ch, input logic a);
        check({tag, ": mode"},            m1  === m);
        check({tag, ": heater_on"},       h1  === h);
        check({tag, ": heat_to_battery"}, hb1 === hb);
        check({tag, ": charge_enable"},   ch1 === ch);
        check({tag, ": alert"},           al1 === a);
    endtask

    // Parts 1 and 2 share one directed sequence; TMR is compared every cycle
    always @(posedge clk) begin
        #2;
        if (!rst) begin
            if ({m2,h2,hb2,ch2,al2} !== {m1,h1,hb1,ch1,al1}) begin
                errors++; $display("FAIL @%0t: TMR output differs from plain controller", $time);
            end
        end
    end

    integer i;
    initial begin
        T_el = 0; T_bat = -200; arc = 0; moist = 0; idle = 0; fclr = 0; rst = 1;
        step(3); rst = 0; step(1);

        // ---- reset state = COLD_START ----
        expect_out("reset", 2'd0, 1, 0, 0, 0);

        // ---- stays in COLD_START while electronics are cold ----
        T_el = 30; step(3);
        expect_out("cold hold", 2'd0, 1, 0, 0, 0);

        // ---- electronics warm up -> NORMAL (entry: heater off, other outputs held) ----
        T_el = 100; step(1);
        expect_out("enter NORMAL", 2'd1, 0, 0, 0, 0);
        // during: battery -20 C (<T_TARGET) -> heat on, but not above 0 -> no charge
        step(1);
        expect_out("NORMAL cold battery", 2'd1, 0, 1, 0, 0);
        // battery above 0 -> charging allowed
        T_bat = 20; step(1);
        expect_out("NORMAL battery > 0", 2'd1, 0, 1, 1, 0);
        // battery above target -> stop routing heat to it
        T_bat = 160; step(1);
        expect_out("NORMAL battery > target", 2'd1, 0, 0, 1, 0);

        // ---- STORAGE ----
        idle = 1; step(1);
        check("enter STORAGE mode", m1 === 2'd2);
        T_bat = 30; step(1);
        expect_out("STORAGE keep-warm", 2'd2, 0, 1, 1, 0);       // 3.0 C < 5.0 C min
        T_bat = 80; step(1);
        expect_out("STORAGE warm enough", 2'd2, 0, 0, 1, 0);
        idle = 0; step(1);
        check("back to NORMAL", m1 === 2'd1);

        // ---- FAULT by arc risk (priority over everything) ----
        arc = 1; step(1);
        expect_out("FAULT arc", 2'd3, 0, 0, 0, 1);
        // stays in FAULT until fault_cleared
        arc = 0; step(3);
        expect_out("FAULT hold", 2'd3, 0, 0, 0, 1);
        fclr = 1; step(1); fclr = 0;
        expect_out("FAULT cleared -> COLD_START", 2'd0, 1, 0, 0, 0);
        step(1);
        check("COLD_START -> NORMAL again", m1 === 2'd1);

        // ---- FAULT by overheat ----
        T_el = 900; step(1);
        check("FAULT overheat", m1 === 2'd3 && al1 === 1);
        T_el = 100; fclr = 1; step(1); fclr = 0; step(1);

        // ---- FAULT by moisture, also from STORAGE ----
        idle = 1; step(2);
        check("in STORAGE before moisture", m1 === 2'd2);
        moist = 1; step(1);
        check("FAULT moisture from STORAGE", m1 === 2'd3);
        moist = 0; fclr = 1; step(1); fclr = 0; idle = 0; step(2);

        // ---- part 2: TMR single-copy SEU injection on every bit of every copy ----
        T_bat = 20; T_el = 100; step(3);
        for (i = 0; i < 21; i++) begin
            // flip one bit in exactly one copy for one clock
            fa = 0; fb = 0; fc = 0;
            if (i < 7)       fa[i]    = 1;
            else if (i < 14) fb[i-7]  = 1;
            else             fc[i-14] = 1;
            step(1);
            check("mismatch flagged after SEU", mism === 1'b1);
            fa = 0; fb = 0; fc = 0;
            step(1);
            check("mismatch healed", mism === 1'b0);
        end
        check("sticky mismatch flag set", mism_seen === 1'b1);

        // ---- random stimulus: TMR must track plain controller ----
        for (i = 0; i < 4000; i++) begin
            T_el  = $urandom_range(0, 1000) - 100;
            T_bat = $urandom_range(0, 600)  - 300;
            arc   = ($urandom_range(0, 40) == 0);
            moist = ($urandom_range(0, 60) == 0);
            idle  = $urandom_range(0, 1);
            fclr  = ($urandom_range(0, 5) == 0);
            if ($urandom_range(0, 9) == 0) begin   // occasional single SEU
                fa = 0; fb = 0; fc = 0;
                case ($urandom_range(0, 2))
                    0: fa = 7'(1 << $urandom_range(0, 6));
                    1: fb = 7'(1 << $urandom_range(0, 6));
                    2: fc = 7'(1 << $urandom_range(0, 6));
                endcase
            end else begin fa = 0; fb = 0; fc = 0; end
            step(1);
        end
        fa = 0; fb = 0; fc = 0; step(2);

        // ---- part 3: watchdog ----
        wd_rst = 1; step(2); wd_rst = 0; step(1);
        // keep kicking: no timeout
        repeat (40) begin wd_kick = 1; step(1); wd_kick = 0; step(5); end
        check("watchdog quiet while kicked", wd_seen === 1'b0);
        // stop kicking: must time out
        step(12);
        check("watchdog timeout when starved", wd_seen === 1'b1);

        // ---- part 4: hardened top smoke test ----
        T_el = 0; T_bat = -100; arc = 0; moist = 0; idle = 0; fclr = 0;
        rst = 1; step(3); rst = 0;
        step(30);
        check("top: COLD_START at low temp", m4 === 2'd0 && h4 === 1'b1);
        T_el = 100; step(30);
        check("top: NORMAL after warm-up", m4 === 2'd1);
        // inject an upset into the mode bit of copy B: output must not change
        seu_c = 2'd1; seu_b = 3'd4; seu_p = 1; step(1); seu_p = 0;
        check("top: output unaffected by SEU", m4 === 2'd1);
        step(2);
        check("top: SEU recorded", mism4_seen === 1'b1);
        check("top: watchdog stayed quiet", wdt4_seen === 1'b0);
        arc = 1; step(30);
        check("top: FAULT on arc risk", m4 === 2'd3 && al4 === 1'b1 && h4 === 1'b0 && ch4 === 1'b0);
        arc = 0; fclr = 1; step(30); fclr = 0; step(30);
        check("top: back to NORMAL after clear", m4 === 2'd1);
        // stall the TMR core: heartbeat stops -> watchdog soft-resets to COLD_START
        stall4 = 1; step(60);
        check("top: watchdog fired on stall", wdt4_seen === 1'b1);
        check("top: soft-reset to COLD_START", m4 === 2'd0 && h4 === 1'b1);
        stall4 = 0; step(40);
        check("top: recovers to NORMAL after stall released", m4 === 2'd1);

        if (errors == 0) $display("ALL TESTS PASSED");
        else             $display("TESTS FAILED: %0d errors", errors);
        $finish;
    end
endmodule
