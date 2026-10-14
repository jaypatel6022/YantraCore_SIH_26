`timescale 1ns/1ps
// Board-level self-checking testbench for control_unit_fpga_top (fast clocks).
module tb_fpga_top;
    localparam integer CLKF = 100_000;     // scaled-down clock for simulation
    logic CLK100MHZ = 0;
    always #5 CLK100MHZ = ~CLK100MHZ;

    logic BTNC = 0, BTNU = 0, BTND = 0, BTNL = 0, BTNR = 0;
    logic [15:0] SW = 16'h0000;
    logic [15:0] LED; logic [6:0] SEG; logic DP; logic [7:0] AN;

    control_unit_fpga_top #(.CLK_FREQ_HZ(CLKF), .DEBOUNCE_MS(1), .SAMPLE_HZ(1000)) dut (.*);

    integer errors = 0;
    task automatic check(input string what, input logic cond);
        if (!cond) begin errors++; $display("FAIL @%0t: %s", $time, what); end
    endtask

    // 1 sample = 100 clocks
    task automatic samples(input integer n); repeat (n * 100 + 20) @(posedge CLK100MHZ); #1; endtask
    task automatic press(ref logic b); b = 1; repeat (400) @(posedge CLK100MHZ); b = 0; repeat (400) @(posedge CLK100MHZ); #1; endtask

    // ---- display decoder: remember last segment pattern seen on every digit ----
    logic [6:0] seen [8];
    always @(posedge CLK100MHZ) begin
        for (int d = 0; d < 8; d++) if (AN[d] == 1'b0) seen[d] <= SEG;
    end
    function automatic string glyph(input logic [6:0] s);
        case (s)
            7'b1000000: glyph = "0"; 7'b1111001: glyph = "1"; 7'b0100100: glyph = "2";
            7'b0110000: glyph = "3"; 7'b0011001: glyph = "4"; 7'b0010010: glyph = "5";
            7'b0111111: glyph = "-"; 7'b1111111: glyph = " "; default: glyph = "?";
        endcase
    endfunction
    function automatic string shown();   // digits left (AN7) to right (AN0)
        shown = {glyph(seen[7]), glyph(seen[6]), glyph(seen[5]), glyph(seen[4]),
                 glyph(seen[3]), glyph(seen[2]), glyph(seen[1]), glyph(seen[0])};
    endfunction

    task automatic goto_k(input integer k);
        while (dut.seu_k != k) press(BTNR);
    endtask

    initial begin
        // ---- reset; both -40 degC ----
        BTNC = 1; repeat (20) @(posedge CLK100MHZ); BTNC = 0; samples(3);
        check("cold-start after reset", dut.mode_t == 0 && dut.mode_p == 0);
        check("heater on in cold-start (LED0)", LED[0] === 1'b1);
        check("both controllers agree", LED[8] === 1'b1);
        $display("display: [%s]  (expect -40-4000)", shown());
        check("display -40 / -40 / 0 / 0", shown() == "-40-4000");

        // ---- electronics 20 degC (code 6) -> NORMAL ----
        SW[15:12] = 4'd6; samples(4);
        check("NORMAL when electronics warm", dut.mode_t == 1 && dut.mode_p == 1);
        check("heater off in NORMAL", LED[0] === 1'b0);

        // ---- battery 10 degC (code 5): heat it and charge it ----
        SW[11:8] = 4'd5; samples(4);
        check("heat_to_battery on (10C < 15C)", LED[1] === 1'b1);
        check("charge_enable on (10C > 0C)",    LED[2] === 1'b1);
        // ---- battery 30 degC (code 7): stop heating ----
        SW[11:8] = 4'd7; samples(4);
        check("heat_to_battery off (30C > 15C)", LED[1] === 1'b0);
        $display("display: [%s]  (expect  20 3011)", shown());
        check("display 20 / 30 / modes 1 1", shown() == " 20 3011");

        // ---- SEU on heater_on (k=3), copy A: TMR heals, plain keeps the wrong value ----
        SW[5:4] = 2'd0; goto_k(3);
        press(BTNL); samples(3);
        check("TMR heater_on unaffected (LED0=0)", LED[0] === 1'b0);
        check("plain heater_on corrupted (LED4=1)", LED[4] === 1'b1);
        check("outputs disagree (LED8=0)", LED[8] === 1'b0);
        check("TMR upset recorded (LED10)", LED[10] === 1'b1);

        // ---- reset clears the plain controller's corruption ----
        BTNC = 1; repeat (20) @(posedge CLK100MHZ); BTNC = 0; samples(5);
        check("agree again after reset", LED[8] === 1'b1 && LED[10] === 1'b0);

        // ---- SEU on a mode bit (k=5 -> plain jumps to FAULT), copy B ----
        SW[5:4] = 2'd1; goto_k(5);
        press(BTNL); samples(3);
        check("TMR still NORMAL", dut.mode_t == 1);
        check("plain controller corrupted into FAULT", dut.mode_p == 3);
        check("outputs disagree after mode upset", LED[8] === 1'b0);

        // ---- real fault: arc risk ----
        BTNC = 1; repeat (20) @(posedge CLK100MHZ); BTNC = 0; samples(5);
        SW[0] = 1; samples(3);
        check("FAULT on arc risk", dut.mode_t == 3 && LED[3] === 1'b1 && dut.mode_p == 3);
        SW[0] = 0; SW[3] = 1; samples(4);
        check("fault cleared -> back in SAFE modes", dut.mode_t == 1 && LED[3] === 1'b0);
        SW[3] = 0;

        // ---- watchdog demo ----
        SW[7] = 1; samples(8);
        check("watchdog LED set after stall", LED[11] === 1'b1);
        check("hardened controller reset to cold-start", dut.mode_t == 0 && LED[0] === 1'b1);
        SW[7] = 0; samples(5);
        check("recovered to NORMAL", dut.mode_t == 1);

        if (errors == 0) $display("FPGA TOP: ALL TESTS PASSED");
        else             $display("FPGA TOP: %0d ERRORS", errors);
        $finish;
    end
endmodule
