# YantraCore – SIH 2026 (SIH26049)

**Radiation-hardened memory and control electronics for extreme high-altitude environments.**

Our entry for Smart India Hackathon 2026, problem statement **SIH26049** (DRDO, Smart Automation theme).
We protect electronics against radiation-induced bit flips, cold-induced battery damage, poor cooling in thin air, arcing, moisture and antenna icing, using hardened digital design plus a thermally managed enclosure.


---

## Table of contents

1. [The problem](#the-problem)
2. [Our solution](#our-solution)
3. [System architecture](#system-architecture)
4. [Repository structure](#repository-structure)
5. [Memory: radiation-hardened ECC RAM](#memory-radiation-hardened-ecc-ram)
6. [Control unit: thermal and safety controller](#control-unit-thermal-and-safety-controller)
7. [Simulink model](#simulink-model)
8. [FPGA demos (Nexys A7)](#fpga-demos-nexys-a7)
9. [Getting started](#getting-started)
10. [Verification results](#verification-results)
11. [Roadmap](#roadmap)
12. [Known limitations](#known-limitations)
13. [Team](#team) · [License](#license)

---

## The problem

Equipment deployed at high altitude (for example Ladakh) is attacked by several environmental factors at once:

| Factor | What goes wrong | Our countermeasure |
| --- | --- | --- |
| Radiation | A single-event upset (SEU) flips a stored bit and silently corrupts data or controller state | ECC RAM with scrubbing; control FSMs with TMR and watchdog |
| Extreme cold (to about -55 °C) | Battery degrades if charged below 0 °C; electronics struggle to boot | Heat pipe routes waste heat to the battery; cold-start heater; charge gate |
| Low air pressure | Weaker convective cooling; higher arcing risk | Pressure-aware thermal model, fan and heat sink, arc-risk fault mode |
| Moisture, freeze-thaw | Condensation, corrosion, shorts | Closed-cell foam moisture barrier, sealing, desiccant |
| Antenna icing | Degraded signal | FTO transparent conductive layers on the antenna |
| Mountainous terrain | Direct device-to-device links blocked | Relay through a High Altitude Platform Station (HAPS) |

## Our solution

Four coordinated subsystems:

1. **Radiation-hardened memory and control.** SEC-DED ECC RAM with scrubbing, and control-unit state machines in RTL hardened with triple modular redundancy (TMR) and a watchdog. Both are implemented and FPGA-ready.
2. **Thermal and safety control logic.** A Simulink-modelled controller with cold-start, normal, storage and fault modes. It reuses electronics waste heat to warm the battery, blocks charging below 0 °C, and enters a fault mode on overheating, arc risk or moisture.
3. **Enclosure.** Closed-cell silicone foam wrap (insulation to -55 °C, UV and solar protection, moisture barrier, thermal-stress tolerance), aluminium battery casing, heat pipe, heat sink and exhaust fan.
4. **Communication.** FTO-coated antenna to prevent icing, linked through a HAPS to get around terrain.

## System architecture

Target architecture: sensors feed a radiation-hardened SoC (control unit + RAM), which drives the thermal-management actuators (heater, heat exchanger, exhaust fan) and the system outputs.

![System architecture](Control_Unit_RTL/Logic_%26_Architecture/System_architecture_TOP.png)

### Heat flow

Waste heat from the electronics warms the battery first. When the battery reaches its target temperature the transfer to it is blocked, and surplus heat goes to the heat exchanger and out through the exhaust fan.

![Heat flow path](Control_Unit_RTL/Logic_%26_Architecture/Heat_flow.png)

### Layered hardening

![Thermal system architecture](Control_Unit_RTL/Logic_%26_Architecture/Thermal_System_Architecture.jpeg)



## Repository structure

```
YantraCore_SIH_26/
├── Memory_RAM_RTL/                 Radiation-hardened ECC RAM
│   ├── base_sram.sv                Unprotected 256 x 8 RAM (reference)
│   ├── ecc_sram.sv                 ECC RAM: 256 x 13-bit codewords, fault injection, scrub
│   ├── ecc_encoder_8_13.sv         8-bit data -> 13-bit SEC-DED codeword
│   ├── ecc_decoder_13_8.sv         Corrects 1-bit errors, detects 2-bit errors
│   ├── ecc_secded_8bit.sv          Combined encoder/decoder (standalone variant)
│   ├── ecc_sram_debug.sv           ECC RAM with debug outputs (syndrome, error class)
│   ├── ecc_decoder_13_8_debug.sv   Decoder with debug outputs
│   ├── sram_ecc_fpga_top.sv        Nexys A7 demo top: base RAM vs ECC RAM
│   ├── seven_segment_8digit.sv     8-digit 7-segment driver
│   ├── button_debounce.sv          Button debounce and one-shot pulse
│   ├── nexys_a7.xdc                Pin constraints (includes AN[7:4])
│   ├── tb_top.sv                   Top-level testbench
│   ├── constraints/nexys_a7.xdc    Older copy of the constraints (no AN[7:4])
│   └── Sim_TestBeches/             Fault-injection testbenches
│
├── Control_Unit_RTL/               Hardened thermal and safety controller
│   ├── control_unit_next.sv        Next-state and output logic (mirrors the Stateflow chart)
│   ├── control_unit.sv             Plain controller (reference for comparing with Simulink)
│   ├── control_unit_tmr.sv         Triple-modular-redundant controller with voter
│   ├── watchdog_timer.sv           Watchdog counter
│   ├── control_unit_top.sv         Hardened top: sample tick + TMR + watchdog
│   ├── control_unit_fpga_top.sv    Nexys A7 demo top: hardened vs plain controller
│   ├── seven_segment_8digit_sym.sv Display driver with minus sign and blanks
│   ├── button_debounce.sv          Button debounce and one-shot pulse
│   ├── nexys_a7.xdc                Pin constraints
│   ├── tb_control_unit.sv          Core testbench (self-checking)
│   ├── tb_fpga_top.sv              Board-level testbench (self-checking)
│   └── Logic_&_Architecture/       Simulink model, state chart and architecture diagrams
│
└── MATLAB_Simulink/                Simulink files (same content as Logic_&_Architecture/)
```

## Memory: radiation-hardened ECC RAM

### How it works

- **Code:** each 8-bit word is stored as a 13-bit codeword: 8 data bits, 4 Hamming parity bits and 1 overall parity bit. This is a **SEC-DED** code (single-error correct, double-error detect).
- **Read path:** the decoder recomputes parity. A single-bit error is located and corrected on the fly; a double-bit error is flagged and the data is not trusted.
- **Scrubbing:** a scrub reads a word, corrects it, re-encodes it and writes it back, so the flipped bit is repaired in storage and errors do not accumulate. In the current FPGA demo scrubbing is a one-shot button press at the selected address.
- **Cost:** 5 extra bits per 8-bit word (62.5% overhead). Wider words reduce this (7 check bits for 32 data bits, 8 for 64), which matters for the planned ASIC.

### Fault injection

Both RAMs have a fault-injection input that flips a chosen bit at the current address, so the unprotected RAM and the ECC RAM can be hit by exactly the same fault and compared side by side.

## Control unit: thermal and safety controller

The control unit is the RTL implementation of the Simulink state chart. It reads electronics and battery temperatures plus arc, moisture and idle flags, and drives the heater, the heat path to the battery, the charge gate and an alert.

![Control unit state chart](Control_Unit_RTL/Logic_%26_Architecture/ControlUnit_States.jpeg)

### Modes

| Mode (`active_mode`) | Heater | Heat to battery | Charging | Enters when |
| --- | --- | --- | --- | --- |
| Cold-start (0) | On | Off | Blocked | Power-up, or after a fault is cleared |
| Normal (1) | Off | On while battery is below its target | Allowed only if battery is above 0 °C | Electronics warm above the boot threshold; or idle ends |
| Storage (2) | Not used | On only if battery is below its storage minimum | Allowed only if battery is above 0 °C | `idle_flag` = 1 |
| Fault (3) | Off | Off | Blocked, alert = 1 | Overheat, arc risk or moisture |

Fault has the highest priority and is checked before every other transition. The unit leaves Fault when `fault_cleared` = 1.

![Control logic flow](Control_Unit_RTL/Logic_%26_Architecture/control%20logic.jpeg)

### Radiation hardening

- **TMR:** three copies of the next-state logic and state registers feed a bitwise 2-of-3 majority voter. The voted value is fed back to all copies and reloaded on every clock between samples, so a single upset copy is outvoted and healed within one clock. `tmr_mismatch` and a sticky `tmr_mismatch_seen` report any disagreement.
- **Watchdog:** the core toggles a heartbeat on every sample tick. If it stops for 4 sample periods, the watchdog soft-resets the controller to cold-start, which is a safe restart because fault conditions are re-checked first.
- **Demo hooks:** `seu_pulse`, `seu_copy` and `seu_bit` inject a bit flip into one copy; `stall` freezes the core to trigger the watchdog.

### Parameters

Temperatures are signed 16-bit values in units of 0.1 °C (−55.0 °C is −550). The thresholds `T_BOOT_THRESHOLD`, `T_TARGET`, `T_STORAGE_MIN`, `T_OVERHEAT` and `T_CHARGE_MIN` are module parameters.

> **Defaults are placeholders** (5, 15, 5 and 85 °C). Set them to the values in your Simulink workspace before comparing results. `LATCH_ALERT = 1` keeps the alert set after leaving Fault, exactly as the chart is drawn; the default clears it.

## Simulink model

The thermal plant and the controller are modelled in `Control_Unit_RTL/Logic_&_Architecture/` (also copied in `MATLAB_Simulink/`):

| File | Content |
| --- | --- |
| `System_Modelled_SIMULINK.slx` | The model: electronics and battery thermal masses, supplemental heater, heat-pipe conduction, pressure-dependent sink convection, sensors, loggers, and the control unit |
| `Ambient_Scenario.mat` | Ambient temperature and pressure scenario fed to the model |
| `System_Modelling_in_Simulink.jpeg` | Screenshot of the model |
| `ControlUnit_States.jpeg` | Screenshot of the Stateflow chart |

![Simulink model](Control_Unit_RTL/Logic_%26_Architecture/System_Modelling_in_Simulink.jpeg)

At low pressure the air carries less heat, so the sink's convection coefficient is looked up from ambient pressure and the heat rejected by the sink changes with altitude. The model uses Stateflow and Simscape thermal blocks, so open it in MATLAB with those installed. The files `.slxc`, `checksumOfCache.mat` and `varInfo.mat` are Simulink cache files that MATLAB regenerates.

## FPGA demos (Nexys A7)

Both demos use the same board pin names, so the same `nexys_a7.xdc` works for either.

### Demo 1: base RAM versus ECC RAM (`Memory_RAM_RTL/sram_ecc_fpga_top.sv`)

The top module places the base RAM and the ECC RAM side by side with the same address, data and fault injection.

| Input | Function |
| --- | --- |
| `SW[15:8]` | Address |
| `SW[7:0]` | Write data |
| `BTNU` | Write the data into both RAMs |
| `BTNL` | Inject a fault: flip data bit *k* at the current address in both RAMs |
| `BTNR` | Step the bit index *k* (0 to 7), shown on `LED[6:4]` |
| `BTND` | Scrub the ECC RAM at the current address |
| `BTNC` | Reset |

The 8 digits show, left to right in hex: **ECC corrected output**, **ECC raw stored data**, **base RAM output**, **address**.

| LED | Meaning |
| --- | --- |
| 0 | ECC storage is clean (raw equals corrected) |
| 1 | A single-bit error was corrected |
| 2 | An uncorrectable double-bit error was detected |
| 3 | The unprotected RAM currently matches the correct value |
| 6:4 | Fault bit index *k* |
| 15 | Heartbeat |

**Walk-through:** (1) set address `05`, data `A5`, press write; all three readouts show `A5`. (2) Press inject on bit 0: the base RAM shows `A4` (silent corruption), ECC raw also shows `A4`, but ECC corrected still shows `A5` and LED 1 lights. (3) Press scrub: ECC raw returns to `A5`, LED 0 comes back on, the base RAM stays wrong. (4) Optionally inject two different bits in one word: LED 2 flags an uncorrectable error.

### Demo 2: hardened versus plain control unit (`Control_Unit_RTL/control_unit_fpga_top.sv`)

Two controllers get the same sensor inputs and the same fault injection: the TMR + watchdog controller and a plain one. The hardened one outvotes and heals the upset; the plain one is corrupted.

| Input | Function |
| --- | --- |
| `SW[15:12]` | Electronics temperature: °C = −40 + 10 × code |
| `SW[11:8]` | Battery temperature, same scale |
| `SW[7]` | Stall: freezes the hardened controller to trigger the watchdog |
| `SW[5:4]` | Which TMR copy gets the bit flip (0 = A, 1 = B, 2 = C) |
| `SW[3]` / `SW[2]` | `fault_cleared` / `idle_flag` |
| `SW[1]` / `SW[0]` | `moisture_flag` / `arc_risk_flag` |
| `BTNL` | Inject a bit flip into the plain controller and one TMR copy |
| `BTNR` | Step the bit index *k* (0 to 6), shown on `LED[14:12]` |
| `BTNC` | Reset |

The display shows `T_electronics | T_battery | TMR mode | plain mode` (modes 0 to 3).

| LED | Meaning |
| --- | --- |
| 0 to 3 | Hardened controller: `heater_on`, `heat_to_battery`, `charge_enable`, `alert` |
| 4 to 7 | Plain controller: the same four outputs |
| 8 | Outputs of the two controllers agree |
| 9 | TMR is currently correcting an upset |
| 10 | TMR has corrected an upset since reset (sticky) |
| 11 | Watchdog has fired since reset (sticky) |
| 14:12 | Fault bit index *k* |
| 15 | Heartbeat |

**Walk-through:** (1) set electronics to code 6 (20 °C): both controllers go to mode 1. (2) Set battery to code 5 (10 °C): heat-to-battery and charge-enable light. (3) Step *k* to 3 (`heater_on`) and press `BTNL`: the hardened heater LED stays off, the plain one lights and stays wrong, LED 8 goes off, LEDs 9 and 10 show the correction. (4) Reset, step *k* to 5 (a mode bit), press `BTNL`: the plain controller jumps to mode 3 while the hardened one stays in mode 1. (5) Raise `SW[7]`: after about 40 ms the watchdog fires (LED 11) and the hardened controller restarts in cold-start. (6) Raise `SW[0]`: both controllers go to fault mode with the alert on.

With 10 °C switch steps, keep each threshold between two steps (for example 5, 15 and 85 °C) so the display stays consistent.

## Getting started

### Requirements

- Vivado (any recent version) and a **Nexys A7** board (100T or 50T).
- For simulation: Vivado Simulator (xsim), or Verilator 5.x.
- For the Simulink model: MATLAB with Simulink, Stateflow and Simscape.

### Build and program

**Memory demo**
1. Create a Vivado RTL project and add from `Memory_RAM_RTL/`: `sram_ecc_fpga_top.sv`, `base_sram.sv`, `ecc_sram.sv`, `ecc_encoder_8_13.sv`, `ecc_decoder_13_8.sv`, `seven_segment_8digit.sv`, `button_debounce.sv`.
2. Add the constraints `Memory_RAM_RTL/nexys_a7.xdc` (not the one in `constraints/`, which lacks the left four display digits).
3. Set `sram_ecc_fpga_top` as the top module, then synthesise, implement and program.

**Control-unit demo**
1. Create a Vivado RTL project and add from `Control_Unit_RTL/`: `control_unit_fpga_top.sv`, `control_unit_top.sv`, `control_unit_tmr.sv`, `control_unit.sv`, `control_unit_next.sv`, `watchdog_timer.sv`, `seven_segment_8digit_sym.sv`, `button_debounce.sv`.
2. Add `Control_Unit_RTL/nexys_a7.xdc`.
3. Set `control_unit_fpga_top` as the top module, set the threshold parameters to your Simulink values, then synthesise, implement and program.
4. To keep the three TMR copies from being merged, check the utilisation report after synthesis; the design uses `dont_touch` attributes for this.

### Simulation

With Verilator, from inside `Memory_RAM_RTL/`:

```bash
# single-bit SEU campaign on the ECC RAM
verilator --binary --timing -Wno-fatal -Wno-lint -Wno-style -Wno-BLKLOOPINIT \
  --top-module tb_ecc_sram_seu \
  Sim_TestBeches/tb_ecc_sram_seu.sv ecc_sram.sv ecc_encoder_8_13.sv ecc_decoder_13_8.sv -o sim
./obj_dir/sim

# base RAM (shows silent errors)
verilator --binary --timing -Wno-fatal -Wno-lint -Wno-style -Wno-BLKLOOPINIT \
  --top-module tb_sram_seu Sim_TestBeches/tb_sram_seu.sv base_sram.sv -o sim
./obj_dir/sim

# exhaustive 1-, 2- and 3-bit patterns (uses the debug variants)
verilator --binary --timing -Wno-fatal -Wno-lint -Wno-style -Wno-BLKLOOPINIT \
  --top-module tb_ecc_sram_exhaustive \
  Sim_TestBeches/tb_ecc_sram_exhaustive_1_2_3bit.sv ecc_sram_debug.sv \
  ecc_encoder_8_13.sv ecc_decoder_13_8_debug.sv -o sim
./obj_dir/sim
```

`-Wno-BLKLOOPINIT` is needed because the memory reset loop uses non-blocking assignments, which Verilator rejects by default.

From inside `Control_Unit_RTL/`:

```bash
SRC="control_unit_next.sv control_unit.sv control_unit_tmr.sv watchdog_timer.sv control_unit_top.sv"

# core testbench: reference chart behaviour, TMR vs plain on 4,000 random cycles, watchdog
verilator --binary --timing -Wno-fatal -Wno-WIDTH -Wno-UNOPTFLAT \
  --top-module tb_control_unit tb_control_unit.sv $SRC -o sim
./obj_dir/sim          # prints "ALL TESTS PASSED"

# board-level testbench: switches, buttons, display and LEDs of the FPGA top
verilator --binary --timing -Wno-fatal -Wno-WIDTH -Wno-UNOPTFLAT \
  --top-module tb_fpga_top tb_fpga_top.sv control_unit_fpga_top.sv \
  seven_segment_8digit_sym.sv button_debounce.sv $SRC -o sim
./obj_dir/sim          # prints "FPGA TOP: ALL TESTS PASSED"
```

In Vivado xsim, add the testbench and the matching design files and set the testbench as the simulation top.

## Verification results

### Memory (`Memory_RAM_RTL/Sim_TestBeches/`, Verilator 5.020)

| Testbench | What it injects | Result |
| --- | --- | --- |
| `tb_sram_seu` (base RAM) | Single-bit faults, 2,048 cases | **100% silent errors**: every fault silently returns wrong data |
| `tb_ecc_sram_seu` (ECC RAM) | A single-bit fault in every bit of every address, 3,328 cases | **100% corrected**, 0 silent errors |
| `tb_ecc_sram_single` | Single-bit fault in each of the 13 codeword bits | 13 / 13 pass |
| `tb_ecc_sram_mbu2` | Every 2-bit combination, 78 cases | **100% detected**, 0 silent errors |
| `tb_ecc_sram_exhaustive_1_2_3bit` | All 1-, 2- and 3-bit patterns, 377 tests | 1-bit and 2-bit: no incorrect final data. 3-bit: characterised | (Solution: Bit Interleavung)
| `tb_ecc_sram_mbu3` | Every 3-bit combination, 286 cases | 23.1% detected, 76.9% silently miscorrected (Solution: Bit Interleavung)

Unit tests: `tb_ecc_modules` and `tb_ecc_secded` (encoder/decoder, every single-bit correction passes). Analysis: `tb_ecc_sram_mbu3_debug` (syndrome analysis of all 286 three-bit cases). Board top: `tb_top`.

### Control unit (`Control_Unit_RTL/`, Verilator 5.020)

| Testbench | What it checks | Result |
| --- | --- | --- |
| `tb_control_unit` | Hand-checked mode sequence against the Stateflow chart; a single-bit flip in every register bit of every TMR copy is outvoted and healed; TMR output equals the plain controller over 4,000 random cycles with injected upsets; watchdog fires only when starved; hardened top recovers after a stall | **ALL TESTS PASSED** |
| `tb_fpga_top` | Board-level: display digits, LEDs, hardened versus plain behaviour under SEUs, arc-risk fault, fault clear, watchdog demo | **ALL TESTS PASSED** |

Deliberately breaking the TMR voter makes these testbenches fail, so the tests do detect a faulty voter.


## Roadmap

- SEC-DED ECC RAM with fault injection and scrubbing
- Fault-injection verification (single, double and triple-bit)
- Nexys A7 demo: base RAM versus ECC RAM
- Thermal and control logic modelled in Simulink
- TMR + watchdog control-unit RTL with self-checking testbenches
- Nexys A7 demo wrapper: hardened versus plain control unit
- Run the control-unit demo on the board and record results
- Compare RTL outputs against logged Simulink signals
- Automatic (periodic) background scrubber
- TMR on the RAM control logic
- Project documentation in `docs/`
- ASIC tapeout of the ECC RAM and hardened control logic
- Enclosure prototype, cold and low-pressure chamber testing, coated-antenna RF tests, HAPS link study



- Mitigations under consideration: more frequent scrubbing, bit interleaving, and a stronger code for the ASIC.
- **TMR voter** is a single point of failure in the current RTL; a hardened voter is planned for the ASIC.
- **Controller thresholds** in the RTL are placeholders until set to the Simulink values.
- **Fault injection is simulated.**


## Acknowledgments

Smart India Hackathon 2026 and DRDO, for the problem statement SIH26049.
