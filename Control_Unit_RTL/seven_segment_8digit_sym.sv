`timescale 1ns/1ps
// ============================================================================
// seven_segment_8digit_sym : like seven_segment_8digit, but each digit takes a
// 5-bit symbol so the display can show a minus sign and blanks (for degC).
//     0..15 = hex digit   16 (5'h10) = blank   17 (5'h11) = '-'
// Nexys A7: AN[0] = rightmost digit. symbols[5*i +: 5] is shown on digit i.
// ============================================================================
module seven_segment_8digit_sym #(
    parameter integer CLK_FREQ_HZ = 100_000_000,
    parameter integer REFRESH_HZ  = 1000
)(
    input  logic        clk,
    input  logic        rst,
    input  logic [39:0] symbols,
    output logic [6:0]  seg,      // {g,f,e,d,c,b,a}, active low
    output logic        dp,
    output logic [7:0]  an        // active low
);
    localparam integer TICKS = CLK_FREQ_HZ / (REFRESH_HZ * 8);
    localparam integer W     = (TICKS <= 1) ? 1 : $clog2(TICKS);
    localparam logic [W-1:0] LAST = W'(TICKS - 1);

    logic [W-1:0] cnt;
    logic [2:0]   sel;

    always_ff @(posedge clk) begin
        if (rst) begin
            cnt <= '0;
            sel <= '0;
        end else if (cnt == LAST) begin
            cnt <= '0;
            sel <= sel + 1'b1;
        end else begin
            cnt <= cnt + 1'b1;
        end
    end

    logic [4:0] sym;

    always_comb begin
        sym = symbols[5*sel +: 5];
        an  = ~(8'b0000_0001 << sel);
        case (sym)
            5'h00: seg = 7'b1000000;
            5'h01: seg = 7'b1111001;
            5'h02: seg = 7'b0100100;
            5'h03: seg = 7'b0110000;
            5'h04: seg = 7'b0011001;
            5'h05: seg = 7'b0010010;
            5'h06: seg = 7'b0000010;
            5'h07: seg = 7'b1111000;
            5'h08: seg = 7'b0000000;
            5'h09: seg = 7'b0010000;
            5'h0A: seg = 7'b0001000;
            5'h0B: seg = 7'b0000011;
            5'h0C: seg = 7'b1000110;
            5'h0D: seg = 7'b0100001;
            5'h0E: seg = 7'b0000110;
            5'h0F: seg = 7'b0001110;
            5'h11:   seg = 7'b0111111;   // minus: only segment g on
            default: seg = 7'b1111111;   // blank
        endcase
    end

    assign dp = 1'b1;
endmodule
