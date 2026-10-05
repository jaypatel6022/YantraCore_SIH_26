`timescale 1ns/1ps
module tb_top;
  logic clk=0, BTNC=0,BTNU=0,BTND=0,BTNL=0,BTNR=0; logic [15:0] SW=0;
  wire [15:0] LED; wire [6:0] SEG; wire DP; wire [7:0] AN;
  sram_ecc_fpga_top #(.CLK_FREQ_HZ(1_000_000), .DEBOUNCE_MS(1)) dut(
    .CLK100MHZ(clk),.BTNC(BTNC),.BTNU(BTNU),.BTND(BTND),.BTNL(BTNL),.BTNR(BTNR),
    .SW(SW),.LED(LED),.SEG(SEG),.DP(DP),.AN(AN));
  always #5 clk=~clk;

  task press(input int which); begin
    case(which) 0:BTNU=1; 1:BTND=1; 2:BTNL=1; 3:BTNR=1; endcase
    repeat(3000) @(posedge clk);
    BTNU=0;BTND=0;BTNL=0;BTNR=0;
    repeat(3000) @(posedge clk);
  end endtask

  task show(input string s); begin
    $display("%-30s addr=%02h  base=%02h  ecc_raw=%02h  ecc_corr=%02h   raw==corr=%b sec=%b ded=%b base==corr=%b  k=%0d",
      s, dut.sram_addr, dut.base_rdata, dut.ecc_rdata_raw, dut.ecc_rdata,
      LED[0], LED[1], LED[2], LED[3], LED[6:4]);
  end endtask

  initial begin
    BTNC=1; repeat(10) @(posedge clk); BTNC=0; repeat(10) @(posedge clk);

    SW = {8'h05, 8'hA5};
    press(0); show("1) after write A5 @05");

    press(2); show("2) after SEU (bit k=0)   <- both RAMs corrupted");

    // no button needed: ecc_rdata is already auto-corrected combinationally
    show("3) (same state) ECC auto-corrects on read, BASE still wrong");

    press(1); show("4) after SCRUB           <- ECC storage repaired, BASE still wrong");

    press(3); press(2); show("5) new SEU on bit k=1 (fresh corruption)");
    press(1); show("6) after SCRUB again     <- repaired again");

    $finish;
  end
endmodule
