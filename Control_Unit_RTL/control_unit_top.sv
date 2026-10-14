`timescale 1ns/1ps
// ============================================================================
// control_unit_top : radiation-hardened control unit
//     sample-tick generator  +  TMR controller  +  watchdog (soft reset)
//
// Watchdog: the TMR core toggles 'heartbeat' on every sample tick. If the
// heartbeat stops changing for WDT_MISSED_SAMPLES sample periods, the watchdog
// soft-resets the controller back to COLD_START (heater on, charging blocked);
// the next evaluation immediately re-checks the fault conditions (overheat /
// arc / moisture take priority), so this is a safe restart state.
//
// Fault injection for the FPGA demo (like the RAM demo):
//     seu_pulse = 1 for one clock flips bit 'seu_bit' (0..6) in copy 'seu_copy'
//     (0 = A, 1 = B, 2 = C). One flipped copy is outvoted and healed;
//     tmr_mismatch / tmr_mismatch_seen report it.
//     stall = 1 freezes the TMR core (no heartbeat) -> watchdog soft-reset demo
//     seu_bit: 0 alert, 1 charge_enable, 2 heat_to_battery, 3 heater_on,
//              4-5 mode bits, 6 heartbeat
// ============================================================================
module control_unit_top #(
    parameter integer CLK_FREQ_HZ        = 100_000_000,
    parameter integer SAMPLE_HZ          = 100,        // controller evaluation rate
    parameter integer WDT_MISSED_SAMPLES = 4,
    parameter signed [15:0] T_BOOT_THRESHOLD = 16'sd50,
    parameter signed [15:0] T_TARGET         = 16'sd150,
    parameter signed [15:0] T_STORAGE_MIN    = 16'sd50,
    parameter signed [15:0] T_OVERHEAT       = 16'sd850,
    parameter signed [15:0] T_CHARGE_MIN     = 16'sd0,
    parameter bit           LATCH_ALERT      = 1'b0
)(
    input  logic               clk,
    input  logic               rst,

    input  logic signed [15:0] T_electronics,
    input  logic signed [15:0] T_battery,
    input  logic               arc_risk_flag,
    input  logic               moisture_flag,
    input  logic               idle_flag,
    input  logic               fault_cleared,

    input  logic               stall,         // demo hook: freezes the controller so the watchdog fires
    input  logic               seu_pulse,
    input  logic [1:0]         seu_copy,
    input  logic [2:0]         seu_bit,

    output logic               heater_on,
    output logic               heat_to_battery,
    output logic               charge_enable,
    output logic               alert,
    output logic [1:0]         active_mode,

    output logic               sample_tick,   // evaluation strobe (for a reference controller)
    output logic               tmr_mismatch,
    output logic               tmr_mismatch_seen,
    output logic               wdt_timeout_seen
);

    // ---------------- sample tick ----------------
    localparam integer TICK_DIV = (CLK_FREQ_HZ / SAMPLE_HZ > 1) ? (CLK_FREQ_HZ / SAMPLE_HZ) : 1;
    localparam integer CW       = (TICK_DIV > 1) ? $clog2(TICK_DIV) : 1;

    localparam logic [CW-1:0] TICK_LAST = CW'(TICK_DIV - 1);
    logic [CW-1:0] tick_cnt;
    logic          tick;

    assign tick        = (tick_cnt == TICK_LAST);
    assign sample_tick = tick;

    always_ff @(posedge clk) begin
        if (rst || tick) tick_cnt <= '0;
        else             tick_cnt <= tick_cnt + 1'b1;
    end

    // ---------------- SEU injection masks ----------------
    logic [6:0] flip_a, flip_b, flip_c;
    logic [6:0] flip_onehot;

    always_comb begin
        flip_onehot = 7'b0;
        if (seu_bit <= 3'd6) flip_onehot[seu_bit] = seu_pulse;
        flip_a = (seu_copy == 2'd0) ? flip_onehot : 7'b0;
        flip_b = (seu_copy == 2'd1) ? flip_onehot : 7'b0;
        flip_c = (seu_copy == 2'd2) ? flip_onehot : 7'b0;
    end

    // ---------------- TMR controller ----------------
    logic heartbeat, wdt_timeout, soft_rst;

    assign soft_rst = rst | wdt_timeout;

    control_unit_tmr #(
        .T_BOOT_THRESHOLD(T_BOOT_THRESHOLD), .T_TARGET(T_TARGET),
        .T_STORAGE_MIN(T_STORAGE_MIN), .T_OVERHEAT(T_OVERHEAT),
        .T_CHARGE_MIN(T_CHARGE_MIN), .LATCH_ALERT(LATCH_ALERT)
    ) u_tmr (
        .clk(clk), .rst(soft_rst), .tick(tick & ~stall),
        .T_electronics(T_electronics), .T_battery(T_battery),
        .arc_risk_flag(arc_risk_flag), .moisture_flag(moisture_flag),
        .idle_flag(idle_flag), .fault_cleared(fault_cleared),
        .seu_flip_a(flip_a), .seu_flip_b(flip_b), .seu_flip_c(flip_c),
        .heater_on(heater_on), .heat_to_battery(heat_to_battery),
        .charge_enable(charge_enable), .alert(alert), .active_mode(active_mode),
        .heartbeat(heartbeat),
        .tmr_mismatch(tmr_mismatch), .tmr_mismatch_seen(tmr_mismatch_seen)
    );

    // ---------------- watchdog ----------------
    logic hb_prev, kick;

    always_ff @(posedge clk) begin
        if (rst) hb_prev <= 1'b0;
        else     hb_prev <= heartbeat;
    end

    assign kick = heartbeat ^ hb_prev;

    watchdog_timer #(.TIMEOUT_CLKS(TICK_DIV * WDT_MISSED_SAMPLES)) u_wdt (
        .clk(clk), .rst(rst), .kick(kick),
        .timeout(wdt_timeout), .timeout_seen(wdt_timeout_seen)
    );

endmodule
