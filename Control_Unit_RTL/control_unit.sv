`timescale 1ns/1ps
// ============================================================================
// control_unit : plain (non-redundant) controller = functional reference that
//                matches the Simulink chart. Use this to compare against the
//                Simulink logged signals; use control_unit_top for the
//                radiation-hardened version.
//
// 'tick' is a clock enable (sample strobe). Tie it to 1'b1 to evaluate every
// clock cycle (equivalent to one Simulink step per clock).
// ============================================================================
module control_unit #(
    parameter signed [15:0] T_BOOT_THRESHOLD = 16'sd50,
    parameter signed [15:0] T_TARGET         = 16'sd150,
    parameter signed [15:0] T_STORAGE_MIN    = 16'sd50,
    parameter signed [15:0] T_OVERHEAT       = 16'sd850,
    parameter signed [15:0] T_CHARGE_MIN     = 16'sd0,
    parameter bit           LATCH_ALERT      = 1'b0
)(
    input  logic               clk,
    input  logic               rst,            // synchronous, active high
    input  logic               tick,

    input  logic signed [15:0] T_electronics,
    input  logic signed [15:0] T_battery,
    input  logic               arc_risk_flag,
    input  logic               moisture_flag,
    input  logic               idle_flag,
    input  logic               fault_cleared,

    // fault injection for demos: XORed into the registers for one clock
    // [5:4] mode  [3] heater_on  [2] heat_to_battery  [1] charge_enable  [0] alert
    // Tie to 6'b0 for normal operation.
    input  logic [5:0]         seu_flip,

    output logic               heater_on,
    output logic               heat_to_battery,
    output logic               charge_enable,
    output logic               alert,
    output logic [1:0]         active_mode
);

    logic [1:0] mode_d;
    logic       heater_on_d, heat_to_battery_d, charge_enable_d, alert_d;

    control_unit_next #(
        .T_BOOT_THRESHOLD(T_BOOT_THRESHOLD), .T_TARGET(T_TARGET),
        .T_STORAGE_MIN(T_STORAGE_MIN), .T_OVERHEAT(T_OVERHEAT),
        .T_CHARGE_MIN(T_CHARGE_MIN), .LATCH_ALERT(LATCH_ALERT)
    ) u_next (
        .mode_q(active_mode), .heater_on_q(heater_on),
        .heat_to_battery_q(heat_to_battery), .charge_enable_q(charge_enable),
        .alert_q(alert),
        .T_electronics(T_electronics), .T_battery(T_battery),
        .arc_risk_flag(arc_risk_flag), .moisture_flag(moisture_flag),
        .idle_flag(idle_flag), .fault_cleared(fault_cleared),
        .mode_d(mode_d), .heater_on_d(heater_on_d),
        .heat_to_battery_d(heat_to_battery_d), .charge_enable_d(charge_enable_d),
        .alert_d(alert_d)
    );

    logic [5:0] regs_q, regs_next;

    assign regs_q    = {active_mode, heater_on, heat_to_battery, charge_enable, alert};
    assign regs_next = tick ? {mode_d, heater_on_d, heat_to_battery_d, charge_enable_d, alert_d}
                            : regs_q;

    always_ff @(posedge clk) begin
        if (rst) begin
            // initial entry into SAFE -> COLD_START
            active_mode     <= 2'd0;
            heater_on       <= 1'b1;
            heat_to_battery <= 1'b0;
            charge_enable   <= 1'b0;
            alert           <= 1'b0;
        end
        else begin
            {active_mode, heater_on, heat_to_battery, charge_enable, alert} <= regs_next ^ seu_flip;
        end
    end

endmodule
