`timescale 1ns/1ps
// ============================================================================
// watchdog_timer : free-running clock counter. 'kick' must arrive at least once
// every TIMEOUT_CLKS clock cycles, otherwise 'timeout' pulses for one cycle
// (used to soft-reset the controller) and 'timeout_seen' latches until rst.
// ============================================================================
module watchdog_timer #(
    parameter integer TIMEOUT_CLKS = 400_000
)(
    input  logic clk,
    input  logic rst,
    input  logic kick,
    output logic timeout,        // 1-cycle pulse
    output logic timeout_seen    // sticky
);
    localparam integer CW = (TIMEOUT_CLKS > 1) ? $clog2(TIMEOUT_CLKS) : 1;
    localparam logic [CW-1:0] LAST = CW'(TIMEOUT_CLKS - 1);
    logic [CW-1:0] cnt;

    always_ff @(posedge clk) begin
        if (rst) begin
            cnt          <= '0;
            timeout      <= 1'b0;
            timeout_seen <= 1'b0;
        end
        else begin
            timeout <= 1'b0;
            if (kick) begin
                cnt <= '0;
            end
            else if (cnt == LAST) begin
                cnt          <= '0;
                timeout      <= 1'b1;
                timeout_seen <= 1'b1;
            end
            else begin
                cnt <= cnt + 1'b1;
            end
        end
    end
endmodule
