###############################################################################
# Nexys A7-100T
# SRAM + ECC SRAM FPGA MVP
#
# Top module:
#   sram_ecc_fpga_top
#
# Clock:
#   CLK100MHZ
#
# Switches:
#   SW[7:0]  = write data
#   SW[15:8] = SRAM address
#
# Buttons:
#   BTNC = reset
#   BTNU = write
#   BTND = read / compare
#   BTNL = display BASE SRAM
#   BTNR = display ECC SRAM
#
# LEDs:
#   LED[0] = BASE == ECC comparison PASS
#   LED[1] = ECC single-error correction
#   LED[2] = ECC double-error detection
#   LED[3] = display selection
#
# 7-segment:
#   SEG[6:0] = segments A-G
#   DP       = decimal point
#   AN[3:0]  = digit enables
###############################################################################


###############################################################################
# CLOCK - 100 MHz
###############################################################################

set_property -dict { PACKAGE_PIN E3 IOSTANDARD LVCMOS33 } \
    [get_ports { CLK100MHZ }]

create_clock -add -name sys_clk_pin \
    -period 10.00 \
    -waveform {0 5} \
    [get_ports {CLK100MHZ}]


###############################################################################
# SWITCHES
###############################################################################

# SW[0]
set_property -dict { PACKAGE_PIN J15 IOSTANDARD LVCMOS33 } \
    [get_ports { SW[0] }]

# SW[1]
set_property -dict { PACKAGE_PIN L16 IOSTANDARD LVCMOS33 } \
    [get_ports { SW[1] }]

# SW[2]
set_property -dict { PACKAGE_PIN M13 IOSTANDARD LVCMOS33 } \
    [get_ports { SW[2] }]

# SW[3]
set_property -dict { PACKAGE_PIN R15 IOSTANDARD LVCMOS33 } \
    [get_ports { SW[3] }]

# SW[4]
set_property -dict { PACKAGE_PIN R17 IOSTANDARD LVCMOS33 } \
    [get_ports { SW[4] }]

# SW[5]
set_property -dict { PACKAGE_PIN T18 IOSTANDARD LVCMOS33 } \
    [get_ports { SW[5] }]

# SW[6]
set_property -dict { PACKAGE_PIN U18 IOSTANDARD LVCMOS33 } \
    [get_ports { SW[6] }]

# SW[7]
set_property -dict { PACKAGE_PIN R13 IOSTANDARD LVCMOS33 } \
    [get_ports { SW[7] }]


# SW[8]
set_property -dict { PACKAGE_PIN T8 IOSTANDARD LVCMOS18 } \
    [get_ports { SW[8] }]

# SW[9]
set_property -dict { PACKAGE_PIN U8 IOSTANDARD LVCMOS18 } \
    [get_ports { SW[9] }]

# SW[10]
set_property -dict { PACKAGE_PIN R16 IOSTANDARD LVCMOS33 } \
    [get_ports { SW[10] }]

# SW[11]
set_property -dict { PACKAGE_PIN T13 IOSTANDARD LVCMOS33 } \
    [get_ports { SW[11] }]

# SW[12]
set_property -dict { PACKAGE_PIN H6 IOSTANDARD LVCMOS33 } \
    [get_ports { SW[12] }]

# SW[13]
set_property -dict { PACKAGE_PIN U12 IOSTANDARD LVCMOS33 } \
    [get_ports { SW[13] }]

# SW[14]
set_property -dict { PACKAGE_PIN U11 IOSTANDARD LVCMOS33 } \
    [get_ports { SW[14] }]

# SW[15]
set_property -dict { PACKAGE_PIN V10 IOSTANDARD LVCMOS33 } \
    [get_ports { SW[15] }]


###############################################################################
# LEDs
###############################################################################

# LED[0] - comparison PASS
set_property -dict { PACKAGE_PIN H17 IOSTANDARD LVCMOS33 } \
    [get_ports { LED[0] }]

# LED[1] - ECC single error corrected
set_property -dict { PACKAGE_PIN K15 IOSTANDARD LVCMOS33 } \
    [get_ports { LED[1] }]

# LED[2] - ECC double error detected
set_property -dict { PACKAGE_PIN J13 IOSTANDARD LVCMOS33 } \
    [get_ports { LED[2] }]

# LED[3] - display selection
set_property -dict { PACKAGE_PIN N14 IOSTANDARD LVCMOS33 } \
    [get_ports { LED[3] }]

# Remaining LEDs are unused
set_property -dict { PACKAGE_PIN R18 IOSTANDARD LVCMOS33 } \
    [get_ports { LED[4] }]

set_property -dict { PACKAGE_PIN V17 IOSTANDARD LVCMOS33 } \
    [get_ports { LED[5] }]

set_property -dict { PACKAGE_PIN U17 IOSTANDARD LVCMOS33 } \
    [get_ports { LED[6] }]

set_property -dict { PACKAGE_PIN U16 IOSTANDARD LVCMOS33 } \
    [get_ports { LED[7] }]

set_property -dict { PACKAGE_PIN V16 IOSTANDARD LVCMOS33 } \
    [get_ports { LED[8] }]

set_property -dict { PACKAGE_PIN T15 IOSTANDARD LVCMOS33 } \
    [get_ports { LED[9] }]

set_property -dict { PACKAGE_PIN U14 IOSTANDARD LVCMOS33 } \
    [get_ports { LED[10] }]

set_property -dict { PACKAGE_PIN T16 IOSTANDARD LVCMOS33 } \
    [get_ports { LED[11] }]

set_property -dict { PACKAGE_PIN V15 IOSTANDARD LVCMOS33 } \
    [get_ports { LED[12] }]

set_property -dict { PACKAGE_PIN V14 IOSTANDARD LVCMOS33 } \
    [get_ports { LED[13] }]

set_property -dict { PACKAGE_PIN V12 IOSTANDARD LVCMOS33 } \
    [get_ports { LED[14] }]

set_property -dict { PACKAGE_PIN V11 IOSTANDARD LVCMOS33 } \
    [get_ports { LED[15] }]


###############################################################################
# 7-SEGMENT DISPLAY
#
# Nexys A7 uses active-low segment and digit enables.
###############################################################################

# Segment A
set_property -dict { PACKAGE_PIN T10 IOSTANDARD LVCMOS33 } \
    [get_ports { SEG[0] }]

# Segment B
set_property -dict { PACKAGE_PIN R10 IOSTANDARD LVCMOS33 } \
    [get_ports { SEG[1] }]

# Segment C
set_property -dict { PACKAGE_PIN K16 IOSTANDARD LVCMOS33 } \
    [get_ports { SEG[2] }]

# Segment D
set_property -dict { PACKAGE_PIN K13 IOSTANDARD LVCMOS33 } \
    [get_ports { SEG[3] }]

# Segment E
set_property -dict { PACKAGE_PIN P15 IOSTANDARD LVCMOS33 } \
    [get_ports { SEG[4] }]

# Segment F
set_property -dict { PACKAGE_PIN T11 IOSTANDARD LVCMOS33 } \
    [get_ports { SEG[5] }]

# Segment G
set_property -dict { PACKAGE_PIN L18 IOSTANDARD LVCMOS33 } \
    [get_ports { SEG[6] }]

# Decimal point
set_property -dict { PACKAGE_PIN H15 IOSTANDARD LVCMOS33 } \
    [get_ports { DP }]


###############################################################################
# 7-SEGMENT DIGIT ENABLES
###############################################################################

# Digit 0
set_property -dict { PACKAGE_PIN J17 IOSTANDARD LVCMOS33 } \
    [get_ports { AN[0] }]

# Digit 1
set_property -dict { PACKAGE_PIN J18 IOSTANDARD LVCMOS33 } \
    [get_ports { AN[1] }]

# Digit 2
set_property -dict { PACKAGE_PIN T9 IOSTANDARD LVCMOS33 } \
    [get_ports { AN[2] }]

# Digit 3
set_property -dict { PACKAGE_PIN J14 IOSTANDARD LVCMOS33 } \
    [get_ports { AN[3] }]


###############################################################################
# BUTTONS
###############################################################################

# Center button - RESET
set_property -dict { PACKAGE_PIN N17 IOSTANDARD LVCMOS33 } \
    [get_ports { BTNC }]

# Up button - WRITE
set_property -dict { PACKAGE_PIN M18 IOSTANDARD LVCMOS33 } \
    [get_ports { BTNU }]

# Left button - DISPLAY BASE SRAM
set_property -dict { PACKAGE_PIN P17 IOSTANDARD LVCMOS33 } \
    [get_ports { BTNL }]

# Right button - DISPLAY ECC SRAM
set_property -dict { PACKAGE_PIN M17 IOSTANDARD LVCMOS33 } \
    [get_ports { BTNR }]

# Down button - READ / COMPARE
set_property -dict { PACKAGE_PIN P18 IOSTANDARD LVCMOS33 } \
    [get_ports { BTND }]


###############################################################################
# END OF CONSTRAINTS
###############################################################################
## ---- Added: left 4-digit block (AN[7:4]) ----
set_property -dict { PACKAGE_PIN P14 IOSTANDARD LVCMOS33 } [get_ports { AN[4] }]
set_property -dict { PACKAGE_PIN T14 IOSTANDARD LVCMOS33 } [get_ports { AN[5] }]
set_property -dict { PACKAGE_PIN K2  IOSTANDARD LVCMOS33 } [get_ports { AN[6] }]
set_property -dict { PACKAGE_PIN U13 IOSTANDARD LVCMOS33 } [get_ports { AN[7] }]
