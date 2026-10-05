`timescale 1ns/1ps

// Nexys A7 has 8 digits (two 4-digit blocks). AN[0] = rightmost digit.
// value[4*i +: 4] is shown on digit i as a hex character; blank[i]=1 turns it off.
module seven_segment_8digit #(
    parameter integer CLK_FREQ_HZ = 100_000_000,
    parameter integer REFRESH_HZ  = 1000          // full-frame rate
)(
    input  logic        clk,
    input  logic        rst,
    input  logic [31:0] value,
    input  logic [7:0]  blank,
    output logic [6:0]  seg,      // {g,f,e,d,c,b,a}, active low
    output logic        dp,
    output logic [7:0]  an        // active low
);

    localparam integer TICKS = CLK_FREQ_HZ / (REFRESH_HZ * 8);
    localparam integer W     = (TICKS <= 1) ? 1 : $clog2(TICKS);

    logic [W-1:0] cnt;
    logic [2:0]   sel;

    always_ff @(posedge clk) begin
        if (rst) begin
            cnt <= '0;
            sel <= '0;
        end else if (cnt == TICKS - 1) begin
            cnt <= '0;
            sel <= sel + 1'b1;
        end else begin
            cnt <= cnt + 1'b1;
        end
    end

    logic [3:0] nib;

    always_comb begin
        nib = value[4*sel +: 4];
        an  = ~(8'b0000_0001 << sel);
        if (blank[sel]) an = 8'hFF;
    end

    always_comb begin
        case (nib)
            4'h0: seg = 7'b1000000;
            4'h1: seg = 7'b1111001;
            4'h2: seg = 7'b0100100;
            4'h3: seg = 7'b0110000;
            4'h4: seg = 7'b0011001;
            4'h5: seg = 7'b0010010;
            4'h6: seg = 7'b0000010;
            4'h7: seg = 7'b1111000;
            4'h8: seg = 7'b0000000;
            4'h9: seg = 7'b0010000;
            4'hA: seg = 7'b0001000;
            4'hB: seg = 7'b0000011;   // shown as 'b'
            4'hC: seg = 7'b1000110;
            4'hD: seg = 7'b0100001;   // shown as 'd'
            4'hE: seg = 7'b0000110;
            4'hF: seg = 7'b0001110;
        endcase
    end

    assign dp = 1'b1;

endmodule
