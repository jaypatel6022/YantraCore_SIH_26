`timescale 1ns/1ps
// ============================================================================
// control_unit_next : pure combinational next-state / next-output logic of the
//                     SIH26049 thermal & safety controller.
//
// Mirrors the Simulink/Stateflow chart:
//   SAFE { COLD_START, NORMAL, STORAGE }  +  FAULT
//   * SAFE -> FAULT   when T_electronics > T_overheat || arc_risk || moisture
//                     (outer transition: checked BEFORE any inner transition)
//   * FAULT -> SAFE   when fault_cleared == 1  (SAFE default state = COLD_START)
//   * COLD_START -> NORMAL   when T_electronics > T_boot_threshold
//   * NORMAL <-> STORAGE     on idle_flag
//
// State encoding == active_mode output:  0 COLD_START, 1 NORMAL, 2 STORAGE, 3 FAULT
//
// Stateflow semantics kept:
//   - on a state change only the ENTRY actions of the new state run
//   - while staying in a state only its DURING actions run
//   - an output that is not assigned keeps its previous value
//
// Temperatures: signed 16-bit, units of 0.1 degC  (e.g. -55.0 degC = -550).
// Thresholds are parameters: SET THEM EQUAL TO YOUR SIMULINK WORKSPACE VALUES.
// ============================================================================
module control_unit_next #(
    parameter signed [15:0] T_BOOT_THRESHOLD = 16'sd50,   //   5.0 degC  (placeholder)
    parameter signed [15:0] T_TARGET         = 16'sd150,  //  15.0 degC  (placeholder)
    parameter signed [15:0] T_STORAGE_MIN    = 16'sd50,   //   5.0 degC  (placeholder)
    parameter signed [15:0] T_OVERHEAT       = 16'sd850,  //  85.0 degC  (placeholder)
    parameter signed [15:0] T_CHARGE_MIN     = 16'sd0,    //   0.0 degC  (chart: T_battery > 0)
    parameter bit           LATCH_ALERT      = 1'b0       // 1 = alert stays set after FAULT (as in the chart as drawn)
)(
    // current registered values
    input  logic [1:0]         mode_q,
    input  logic               heater_on_q,
    input  logic               heat_to_battery_q,
    input  logic               charge_enable_q,
    input  logic               alert_q,
    // sensor / flag inputs
    input  logic signed [15:0] T_electronics,
    input  logic signed [15:0] T_battery,
    input  logic               arc_risk_flag,
    input  logic               moisture_flag,
    input  logic               idle_flag,
    input  logic               fault_cleared,
    // next values
    output logic [1:0]         mode_d,
    output logic               heater_on_d,
    output logic               heat_to_battery_d,
    output logic               charge_enable_d,
    output logic               alert_d
);

    localparam logic [1:0] COLD_START = 2'd0,
                           NORMAL     = 2'd1,
                           STORAGE    = 2'd2,
                           FAULT      = 2'd3;

    logic fault_cond;
    logic [1:0] nxt;

    assign fault_cond = (T_electronics > T_OVERHEAT) | arc_risk_flag | moisture_flag;

    // ---------------- transitions ----------------
    always_comb begin
        nxt = mode_q;
        if (mode_q == FAULT) begin
            if (fault_cleared) nxt = COLD_START;
        end
        else if (fault_cond) begin               // parent (SAFE) transition has priority
            nxt = FAULT;
        end
        else begin
            case (mode_q)
                COLD_START: if (T_electronics > T_BOOT_THRESHOLD) nxt = NORMAL;
                NORMAL:     if (idle_flag)                         nxt = STORAGE;
                STORAGE:    if (!idle_flag)                        nxt = NORMAL;
                default:    nxt = COLD_START;
            endcase
        end
    end

    // ---------------- entry / during actions ----------------
    always_comb begin
        mode_d            = nxt;
        heater_on_d       = heater_on_q;
        heat_to_battery_d = heat_to_battery_q;
        charge_enable_d   = charge_enable_q;
        alert_d           = alert_q;

        if (nxt != mode_q) begin
            // ----- entry actions of the state being entered -----
            case (nxt)
                COLD_START: begin
                    heater_on_d       = 1'b1;
                    heat_to_battery_d = 1'b0;
                    charge_enable_d   = 1'b0;
                    if (!LATCH_ALERT) alert_d = 1'b0;
                end
                NORMAL: begin
                    heater_on_d = 1'b0;
                end
                STORAGE: begin
                    // only active_mode = 2 (carried by mode_d)
                end
                FAULT: begin
                    heat_to_battery_d = 1'b0;
                    heater_on_d       = 1'b0;
                    charge_enable_d   = 1'b0;
                    alert_d           = 1'b1;
                end
                default: ;
            endcase
        end
        else begin
            // ----- during actions of the current state -----
            case (mode_q)
                NORMAL: begin
                    heat_to_battery_d = (T_battery < T_TARGET);
                    charge_enable_d   = (T_battery > T_CHARGE_MIN);
                end
                STORAGE: begin
                    heat_to_battery_d = (T_battery < T_STORAGE_MIN);
                    charge_enable_d   = (T_battery > T_CHARGE_MIN);
                end
                default: ;   // COLD_START, FAULT have no during actions
            endcase
        end
    end

endmodule
