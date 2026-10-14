`timescale 1ns/1ps
// ============================================================================
// control_unit_tmr : triple-modular-redundant controller.
//
//   * Three independent copies of {next-state logic + state/output registers}.
//   * A bitwise 2-of-3 majority voter produces the real state and outputs.
//   * The VOTED value is fed back as 'current state' to all three copies, and on
//     every clock without a 'tick' the registers are reloaded with the voted
//     value -> a single upset copy is repaired within one clock (state scrubbing).
//   * tmr_mismatch flags any copy disagreeing with the vote (error reporting).
//
// Register vector per copy (7 bits):
//     [6] heartbeat  [5:4] mode (= active_mode)  [3] heater_on
//     [2] heat_to_battery  [1] charge_enable  [0] alert
//
// seu_flip_* : fault-injection masks (XORed into the register's next value for
// one clock). Tie to 0 for normal operation; remove for the ASIC netlist.
//
// Synthesis: dont_touch/keep stop the tool from merging the three copies back
// into one (Vivado: also consider  set_property KEEP_HIERARCHY yes ).
// ============================================================================
module control_unit_tmr #(
    parameter signed [15:0] T_BOOT_THRESHOLD = 16'sd50,
    parameter signed [15:0] T_TARGET         = 16'sd150,
    parameter signed [15:0] T_STORAGE_MIN    = 16'sd50,
    parameter signed [15:0] T_OVERHEAT       = 16'sd850,
    parameter signed [15:0] T_CHARGE_MIN     = 16'sd0,
    parameter bit           LATCH_ALERT      = 1'b0
)(
    input  logic               clk,
    input  logic               rst,
    input  logic               tick,

    input  logic signed [15:0] T_electronics,
    input  logic signed [15:0] T_battery,
    input  logic               arc_risk_flag,
    input  logic               moisture_flag,
    input  logic               idle_flag,
    input  logic               fault_cleared,

    input  logic [6:0]         seu_flip_a,
    input  logic [6:0]         seu_flip_b,
    input  logic [6:0]         seu_flip_c,

    output logic               heater_on,
    output logic               heat_to_battery,
    output logic               charge_enable,
    output logic               alert,
    output logic [1:0]         active_mode,

    output logic               heartbeat,
    output logic               tmr_mismatch,       // a copy currently disagrees
    output logic               tmr_mismatch_seen   // sticky until rst
);

    localparam logic [6:0] RESET_VAL = 7'b0_00_1_0_0_0;   // COLD_START, heater on

    function automatic logic [6:0] vote(input logic [6:0] a, b, c);
        vote = (a & b) | (a & c) | (b & c);
    endfunction

    (* dont_touch = "true", keep = "true" *) logic [6:0] r_a, r_b, r_c;
    logic [6:0] v;
    logic [6:0] d_a, d_b, d_c;

    assign v = vote(r_a, r_b, r_c);

    // ---------------- three copies of the next-state logic ----------------
    (* dont_touch = "true", keep = "true" *)
    control_unit_next #(.T_BOOT_THRESHOLD(T_BOOT_THRESHOLD), .T_TARGET(T_TARGET),
        .T_STORAGE_MIN(T_STORAGE_MIN), .T_OVERHEAT(T_OVERHEAT),
        .T_CHARGE_MIN(T_CHARGE_MIN), .LATCH_ALERT(LATCH_ALERT)) u_next_a (
        .mode_q(v[5:4]), .heater_on_q(v[3]), .heat_to_battery_q(v[2]),
        .charge_enable_q(v[1]), .alert_q(v[0]),
        .T_electronics(T_electronics), .T_battery(T_battery),
        .arc_risk_flag(arc_risk_flag), .moisture_flag(moisture_flag),
        .idle_flag(idle_flag), .fault_cleared(fault_cleared),
        .mode_d(d_a[5:4]), .heater_on_d(d_a[3]), .heat_to_battery_d(d_a[2]),
        .charge_enable_d(d_a[1]), .alert_d(d_a[0]));

    (* dont_touch = "true", keep = "true" *)
    control_unit_next #(.T_BOOT_THRESHOLD(T_BOOT_THRESHOLD), .T_TARGET(T_TARGET),
        .T_STORAGE_MIN(T_STORAGE_MIN), .T_OVERHEAT(T_OVERHEAT),
        .T_CHARGE_MIN(T_CHARGE_MIN), .LATCH_ALERT(LATCH_ALERT)) u_next_b (
        .mode_q(v[5:4]), .heater_on_q(v[3]), .heat_to_battery_q(v[2]),
        .charge_enable_q(v[1]), .alert_q(v[0]),
        .T_electronics(T_electronics), .T_battery(T_battery),
        .arc_risk_flag(arc_risk_flag), .moisture_flag(moisture_flag),
        .idle_flag(idle_flag), .fault_cleared(fault_cleared),
        .mode_d(d_b[5:4]), .heater_on_d(d_b[3]), .heat_to_battery_d(d_b[2]),
        .charge_enable_d(d_b[1]), .alert_d(d_b[0]));

    (* dont_touch = "true", keep = "true" *)
    control_unit_next #(.T_BOOT_THRESHOLD(T_BOOT_THRESHOLD), .T_TARGET(T_TARGET),
        .T_STORAGE_MIN(T_STORAGE_MIN), .T_OVERHEAT(T_OVERHEAT),
        .T_CHARGE_MIN(T_CHARGE_MIN), .LATCH_ALERT(LATCH_ALERT)) u_next_c (
        .mode_q(v[5:4]), .heater_on_q(v[3]), .heat_to_battery_q(v[2]),
        .charge_enable_q(v[1]), .alert_q(v[0]),
        .T_electronics(T_electronics), .T_battery(T_battery),
        .arc_risk_flag(arc_risk_flag), .moisture_flag(moisture_flag),
        .idle_flag(idle_flag), .fault_cleared(fault_cleared),
        .mode_d(d_c[5:4]), .heater_on_d(d_c[3]), .heat_to_battery_d(d_c[2]),
        .charge_enable_d(d_c[1]), .alert_d(d_c[0]));

    // heartbeat toggles on every evaluation tick (watchdog watches this bit)
    assign d_a[6] = ~v[6];
    assign d_b[6] = ~v[6];
    assign d_c[6] = ~v[6];

    // ---------------- three register banks ----------------
    always_ff @(posedge clk) begin
        if (rst) begin
            r_a <= RESET_VAL;
            r_b <= RESET_VAL;
            r_c <= RESET_VAL;
        end
        else begin
            r_a <= (tick ? d_a : v) ^ seu_flip_a;
            r_b <= (tick ? d_b : v) ^ seu_flip_b;
            r_c <= (tick ? d_c : v) ^ seu_flip_c;
        end
    end

    // ---------------- outputs and status ----------------
    assign heartbeat       = v[6];
    assign active_mode     = v[5:4];
    assign heater_on       = v[3];
    assign heat_to_battery = v[2];
    assign charge_enable   = v[1];
    assign alert           = v[0];

    assign tmr_mismatch = (r_a != v) | (r_b != v) | (r_c != v);

    always_ff @(posedge clk) begin
        if (rst)               tmr_mismatch_seen <= 1'b0;
        else if (tmr_mismatch) tmr_mismatch_seen <= 1'b1;
    end

endmodule
