# SIH26049 – Project Documentation

## Executive summary

Our solution keeps electronics working in high-altitude, subzero, low-pressure, radiation-exposed conditions by combining four coordinated subsystems: a radiation-hardened memory and control unit, a thermal and safety control layer, a closed-cell silicone foam enclosure, and a de-iced antenna linked through a High Altitude Platform Station (HAPS).

The problem is SIH26049, a DRDO problem statement under the Smart Automation theme. In these conditions a stray particle can flip a memory bit, a cold battery degrades when charged, thin air cools electronics poorly, and low pressure raises the risk of electrical arcing. The design answers each of these directly instead of treating them as separate projects.

| Subsystem | Main risk it addresses | Status today |
| --- | --- | --- |
| Radiation-hardened RAM (ECC + scrubbing) | Bit flips (single-event upsets) corrupting data | Implemented and demonstrated on a Nexys A7 FPGA; ASIC tapeout planned |
| Control unit (state machines in RTL, watchdog + TMR) | Controller itself failing under radiation | Implemented as RTL and demonstrated on FPGA and ASIC demonstration planned |
| Thermal and safety control logic | Cold battery, poor cooling, arcing, moisture | Modelled in Simulink |
| Enclosure (closed-cell silicone foam) | Cold, UV, moisture, thermal stress | Rough design done(CAD) |
| Communication (FTO-coated antenna, HAPS relay) | Antenna icing, terrain blocking direct links | Concept defined(Materials/Components acquisition) |

This document explains each part, how the parts connect, what is already built, and what remains, so that every team member can see both their own piece and the whole system.

## Problem statement and operating environment

SIH26049 asks for electronics that stay reliable in extreme high-altitude conditions such as Ladakh, where the environment attacks the system in several ways at once. Our architecture notes describe the target as subzero, low-pressure conditions with added radiation exposure.

Each environmental factor causes a specific failure, and our design maps one countermeasure to each:

| Environmental factor | What goes wrong | Our countermeasure |
| --- | --- | --- |
| Radiation (cosmic and solar particles) | A bit flip in memory or in controller state silently corrupts data or logic | ECC RAM with scrubbing; control Unit FSMs with watchdog and TMR |
| Extreme cold (down to about -55 °C) | Battery loses capacity and degrades if charged below 0 °C; electronics struggle to boot | Heat pipe routes waste heat to the battery; supplemental heater for cold start; charge gate blocks charging below 0 °C |
| Low air pressure | Thin air weakens convective cooling, and the lower breakdown voltage raises arcing risk | Pressure-aware heat-sink model, fan exhaust, arc-risk flag that forces a fault mode |
| Moisture and freeze-thaw cycles | Condensation and ice ingress cause corrosion and short circuits | Closed-cell foam moisture barrier, sealed enclosure, desiccant, ramped power cycling |
| UV and solar exposure, thermal stress | Materials age and crack | Silicone foam wrap with UV and thermal-stress resistance |
| Ice on the antenna | Signal degradation | FTO transparent conductive layers on the antenna |
| Mountainous terrain | Direct device-to-device links are blocked | Relay through a HAPS overhead |

The key point for the team is that these are not independent. Cold makes the battery need heat, the electronics produce heat that can be reused, and low pressure makes getting rid of surplus heat harder. That coupling is why a single controller manages the thermal, safety and battery behaviour together.

## Proposed solution and system architecture

The system is a layered design: passive protection around everything, a shared heat network inside, and one central controller that reads sensors and decides what to do.

**Layer 1, passive protection.** A sealed enclosure wrapped in closed-cell silicone foam, conformal coating on the electronics, and derated creepage and clearance spacing so arcs are less likely at low pressure.

**Heat network.** The electronics (CPU, RF, power electronics) are a source of waste heat, and a low-power supplemental heater adds heat only during cold start. Both feed a heat-pipe distribution manifold. From there heat goes to the battery warming bay, an isolated compartment where the battery sits in an aluminium casing, or to a passive heat sink that rejects surplus heat by convection and radiation. An exhaust fan removes internal heat.

**Battery protection.** A battery-management-system (BMS) charge gate blocks charging whenever the battery is below 0 °C, because charging a frozen lithium battery damages it.

**Moisture and condensation control.** Desiccant, a hermetic seal, and ramped power cycling so that warm-up does not create freeze-thaw moisture ingress.

**Central multi-mode controller.** It reads multi-point temperature, pressure, humidity and voltage sensors and runs four modes: cold-start, normal, storage and fault. Its finite-state machines are implemented in RTL and hardened with a watchdog and triple modular redundancy (TMR), and any memory it uses is the ECC-protected RAM.

**Communication.** An FTO-coated antenna on top of the enclosure talks to a HAPS, which relays traffic between devices that have no direct line of sight.

&#91;embedded content: system architecture · heat network, controller, antenna and HAPS\]

Heat flows down from the electronics and heater to the battery or the heat sink, while the controller (dashed lines) sets the heater, the heat routing and the charge gate, and sends alerts out through the antenna.

## Subsystem 1: radiation-hardened memory and control (FPGA implementation)

This subsystem is already built and demonstrated: an ECC-protected RAM with scrubbing corrects flipped memory Bit on every read, while an unprotected RAM next to it returns wrong data for the same fault.

### The threat

A single-event upset (SEU) happens when a charged particle flips one stored bit. In ordinary memory nothing notices, so the system reads corrupted data as if it were valid. If a second bit in the same word flips before the first is repaired, a single-error-correcting code can no longer fix the word, which is why errors must be cleaned out of storage over time.

### How the ECC RAM works

- **Code:** each 8-bit data word is stored as a 13-bit codeword: 8 data bits, 4 Hamming parity bits and 1 overall parity bit. This is a SEC-DED code (single-error correct, double-error detect).
- **Write path:** the encoder computes the parity bits and the 13-bit codeword is stored.
- **Read path:** the decoder recomputes parity on the stored codeword. A Bit error is located and corrected, and the corrected byte is returned. Bit interleaving is implemented to counter MBUs(Multiple Bits Upsets).
- **Scrubbing:** a scrub reads the word, corrects it, re-encodes it and writes it back, so the flipped bit is repaired in storage and not only hidden at the output.&#32;

### The FPGA design on the Nexys A7

The top module places a base RAM and the ECC RAM side by side. Both are 256 words deep, take the same address and write data, and receive the same fault injection, so the comparison is direct.

| Source file | Role |
| --- | --- |
| sram\_ecc\_fpga\_top.sv | Top module: wires buttons, switches, both RAMs, the display and the LEDs |
| base\_sram.sv | Unprotected 8-bit RAM with a fault-injection input |
| ecc\_sram.sv | ECC-protected RAM: encoder, decoder, corrected and raw outputs, error flags, scrub |
| ecc\_encoder\_8\_13.sv | Builds the 13-bit codeword from 8 data bits |
| ecc\_decoder\_13\_8.sv | Finds and corrects error. |
| seven\_segment\_8digit.sv | Multiplexes all eight display digits |
| button\_debounce.sv | 20 ms debounce, one clean pulse per button press |
| tb\_top.sv | Testbench for simulation |
| nexys\_a7.xdc | Pin constraints for the board (100 MHz clock, switches, buttons, LEDs, display) |

### Board controls

| Input | Function |
| --- | --- |
| Switches 15 to 8 | Address (reads are continuous, so the display follows the address) |
| Switches 7 to 0 | Write data |
| Top button | Write the data into both RAMs |
| Left button | Inject a fault: flip data bit k at the current address in both RAMs |
| Right button | Step the bit index k from 0 to 7 (shown on LEDs 6 to 4) |
| Bottom button | Scrub the ECC RAM at the current address |
| Centre button | Reset |

### Reading the outputs

The eight display digits, left to right in hex, show: ECC corrected output, ECC raw stored data, base RAM output, then the address.

| LED | Meaning |
| --- | --- |
| 0 | ECC storage is clean (raw equals corrected) |
| 1 | A single-bit error was corrected |
| 2 | An double-bit error was detected |
| 3 | The unprotected RAM currently matches the correct value |
| 6 to 4 | Selected fault bit index |
| 15 | Heartbeat (design is running) |

### Demo walk-through

1. **Write.** Set address 05 and data A5, press write. All three data readouts show A5 and LEDs 0 and 3 are on.
2. **Inject a fault.** Press the left button on bit 0. The base RAM now shows A4 (silent corruption). The ECC raw value shows A4 too, but the ECC corrected output still shows A5, and LED 1 lights.
3. **Scrub.** Press the bottom button. The ECC raw value returns to A5, LED 0 comes back on and LED 1 goes off. The base RAM stays wrong.

The values A5 and 05 are examples; any address and data work.

### Hardening the control unit

A reliable memory is not enough if the controller reading it can be upset. The control unit's state machines are written in RTL with two protections: **triple modular redundancy** (three copies of the logic feed a majority voter, so one corrupted copy is outvoted) and a **watchdog** (a timer that resets the controller if it stops making progress). The hardened control FSM is implemented in RTL; running it on the FPGA and on an ASIC is the next demonstration.

### ASIC path

The FPGA build proves the design in real hardware. The planned ASIC tapeout would carry the ECC RAM and the hardened control logic into silicon, where wider ECC words lower the storage overhead and radiation behaviour can be designed in at the cell and layout level.

## Subsystem 2: thermal management and control logic (Simulink)

The control logic uses the electronics' own waste heat to protect the battery, and switches into a safe fault mode on overheating, arcing risk or moisture. It is modelled in Simulink as a thermal plant plus a state-machine controller.

### Problems it addresses

- **Reduced cooling efficiency:** at low pressure the air carries less heat, so the heat sink works worse. The model feeds ambient pressure into a convection-coefficient lookup table, so the heat rejected through the sink changes with altitude.
- **Battery degradation:** a battery that is too cold loses capacity, and charging it below 0 °C causes lasting damage. The controller warms the battery with electronics waste heat and blocks charging until it is above 0 °C.
- **Arcing and moisture faults:** low pressure lowers the voltage at which air breaks down across a gap (Paschen's law), and condensation can short circuits. Either condition puts the system into a fault mode that cuts the heat path and raises an alert.

### The Simulink model

The plant side represents the physical system as thermal blocks:

- **Electronics mass** with a waste-heat input, and a **supplemental heater** for cold start.
- **Heat-pipe conduction** carrying heat from the electronics to the **battery warming** thermal mass, driven by a battery actuator.
- **Sink convection**, whose coefficient comes from a lookup table indexed by pressure, connected to an ambient reference.
- A **scenario** block supplying ambient temperature and pressure.
- **Temperature sensors** on the electronics and the battery, and logging blocks for temperatures, heater state, heat sent to the battery, charge enable and active mode.

The **control unit** block takes T\_electronics, T\_battery, arc\_risk\_flag, moisture\_flag, idle\_flag and fault\_cleared, and outputs heater\_on, heat\_to\_battery, charge\_enable, alert and active\_mode. In the screenshot of the model, the four flag inputs are tied to constant 0, so a fault or idle scenario is tested by driving those inputs.

### The four operating modes

The controller is a state machine with a SAFE superstate holding three modes, and a FAULT state that overrides it.

| Mode (active\_mode) | Heater | Heat to battery | Charging | Enters when |
| --- | --- | --- | --- | --- |
| Cold-start (0) | On | Off | Blocked | Power-up; electronics below the boot threshold |
| Normal (1) | Off | On while battery is below its target temperature | Allowed only if battery is above 0 °C | T\_electronics rises above T\_boot\_threshold; or idle\_flag returns to 0 |
| Storage (2) | Not used | On only if battery is below its minimum storage temperature | Allowed only if battery is above 0 °C | idle\_flag is 1 (equipment idle or stored) |
| Fault (3) | Off | Off | Blocked | T\_electronics above T\_overheat, or arc\_risk\_flag, or moisture\_flag |

Fault has the highest priority and is checked first. The system returns from Fault to the SAFE modes when fault\_cleared is 1. On fault the alert output is set to 1.

### Reading the decision flow

On every cycle the controller reads the sensors and applies these checks in order: overheat, arc or moisture fault first; then whether the electronics are below the boot temperature (cold-start); then normal operation, which routes waste heat by priority; then the battery charge gate, which is checked independently of warming; and finally the idle check for storage mode. This ordering means a safety fault can never be overridden by a comfort or efficiency decision.

## Subsystem 3: enclosure

The enclosure is the physical shell that houses the battery, the RAM and control electronics, and the thermal hardware, and it is wrapped in closed-cell silicone foam. Closed-cell foam does not absorb water, which is why it works as a moisture barrier as well as an insulator.

### What the foam wrap provides

- Thermal insulation for operation down to -55 °C, so waste heat stays inside and reaches the battery instead of leaking out.
- Protection from UV and solar radiation, which degrade many plastics and coatings at altitude.
- An environmental and moisture barrier against rain, snow and condensation.
- Tolerance of thermal stress from large temperature swings between day and night.

### What is inside

| Component | Purpose |
| --- | --- |
| Aluminium casing around the battery | Spreads heat evenly so the battery warms uniformly |
| Heat pipe | Carries waste heat from the electronics to the battery |
| Supplemental heating element | Pre-warms the system for cold start |
| Heat sink | Rejects surplus heat when the battery is warm enough |
| Exhaust cooling fan | Removes internal heat when needed |
| SoC, ASIC or FPGA with RAM, control unit and critical FSMs | The computing and control core |
| Internal temperature sensors | Measure component temperatures |
| Temperature, pressure and humidity sensors | Measure the environment |
| Antenna on top | Communication (see the next subsystem) |

### Design intent

The insulation and the heat network work together: insulation keeps heat in, the heat pipe puts it where it is useful, and the heat sink and fan are the release valve for when there is too much. The enclosure design so far is a rough sketch; detailed mechanical drawings, foam thickness and material selection are still to be done.

## Subsystem 4: communication (FTO antenna and HAPS)

The communication subsystem keeps the link working in two ways: it stops ice from forming on the antenna, and it relays around mountains through a High Altitude Platform Station (HAPS).

### Antenna de-icing with FTO

Ice on an antenna detunes it and blocks signal. We coat the antenna with layers of FTO (fluorine-doped tin oxide), a transparent conductive film, on both the top and the bottom of the antenna surface. The intended mechanism is that a small electric current through the conductive film warms the surface enough to prevent or melt ice, and because the film is transparent it does not hide the antenna.

Design considerations for this part:

- The film conducts electricity, so its thickness and sheet resistance must be chosen to keep radio-frequency loss low while still heating effectively.
- The heating power draws on the same battery the thermal controller is protecting, so it should be enabled only when the environmental sensors indicate icing conditions.

### Relay through a HAPS

In mountainous terrain a mountain can sit between two devices, so a direct link is blocked even if they are close. A HAPS is a platform (for example an airship) that stays high above the terrain, typically in the stratosphere. Both devices link up to the HAPS, which passes the traffic between them, so communication does not need line of sight across the mountain.

| Direct link | Via HAPS |
| --- | --- |
| Blocked by terrain | Each device only needs a clear path to the sky |
| Range limited by the horizon | Wide coverage area from one platform |

Compared with satellites, a HAPS sits much closer to the ground, which generally means lower delay and less power needed for the link, though it covers a smaller area.

## Key features and technical approach

Every feature maps to one technique, and the techniques are chosen to be low-power, mostly passive, and verifiable.

| Key feature | Technical approach | Where it lives |
| --- | --- | --- |
| Silent bit flips are corrected automatically | SEC-DED Hamming code (13,8) in the RAM, corrected on every read | FPGA design, later ASIC |
| Errors do not accumulate in storage | Scrubbing: corrected data re-encoded and written back | FPGA design (on-demand scrub), later ASIC |
| Controller survives upsets | Triple modular redundancy with a majority voter, plus a watchdog | RTL control FSMs |
| Battery protected from cold damage | Heat pipe delivers waste heat; BMS charge gate blocks charging below 0 °C | Simulink model, enclosure hardware |
| Reliable cold start | Supplemental heater in cold-start mode; boot delayed until warm | Control unit |
| Altitude-aware cooling | Convection coefficient looked up from pressure; fan and heat sink | Simulink model, enclosure |
| Safety override | Fault mode on overheat, arc risk or moisture: cuts heat path, heater and charging, raises alert | Control unit |
| Weatherproof shell | Closed-cell silicone foam, sealed enclosure, conformal coating, desiccant | Enclosure |
| Ice-free antenna | FTO transparent conductive layers on both sides | Antenna |
| Links across terrain | HAPS relay | Communication |

### Overall technical approach

1. **Model first.** The thermal and control behaviour is modelled and tested in Simulink before hardware.
2. **Prove the hard part in hardware.** The radiation-hardened memory, the most novel part, is built in RTL and demonstrated on an FPGA with visible fault injection.
3. **Harden by construction.** Protection is built into the logic (ECC, TMR, watchdog) instead of relying on physical shielding alone.
4. **Reuse waste heat.** The design treats electronics heat as a resource for the battery, so the heater is only needed for cold start.
5. **Move to silicon.** After FPGA validation, the same RTL goes to ASIC tapeout.

## Impact and benefits

The main benefit is dependable unattended operation of electronics in remote, harsh locations, where a failure means a costly and sometimes dangerous trip to repair or replace equipment.

- **Data integrity:** correcting bit flips means sensor data, commands and stored parameters stay trustworthy instead of failing silently.
- **Longer battery life and better availability:** blocking cold charging and reusing waste heat reduces battery degradation and helps the system start reliably after cold nights.
- **Safety:** a hard-priority fault mode limits damage from overheating, arcing or moisture, and alerts operators.
- **Energy efficiency:** waste heat does most of the warming, so the dedicated heater runs only at cold start, saving battery energy.
- **Fewer site visits:** sealed, insulated, self-managing equipment needs less maintenance.
- **Connectivity in difficult terrain:** a HAPS relay keeps devices connected when mountains block direct links, and de-iced antennas keep that link usable in winter.
- **Reusable technology:** the radiation-hardened RAM and control logic apply beyond this problem, for example in aerospace and other high-radiation or remote-sensing systems.
- **Path to indigenous hardware:** the ASIC plan moves the protected memory and controller into custom silicon.

## Viability and feasibility

The design is feasible because the most novel part (the radiation-hardened memory & control unit) already works on real hardware, validated by the fault-injections through testbenches. Each part uses easily available components which can be scaled further.

| Part | Feasibility | Why | Main risk and mitigation |
| --- | --- | --- | --- |
| ECC RAM with scrubbing | High | &#32;working on FPGA | &#32;storage overhead at 8-bit words; use wider words (32 or 64 bits) in the ASIC to reduce storage overhead |
| Control FSM with TMR and watchdog | High | &#32;FSMs are small, so tripling them is cheap | The voter can itself be upset; keep it minimal and harden it through triplication, and refresh state periodically |
| Thermal and safety control | Medium to high | Heat pipes, heaters, fans and BMS charge gates are off-the-shelf; logic is simple | &#32;size heat pipe and heater against real power budgets and tune thresholds in a cold chamber |
| Silicone foam enclosure | High | Closed-cell silicone foam is commercially available | Too much insulation traps heat, so balance it with the heat sink and fan; account for pressure difference across the seal at altitude |
| FTO antenna coating | Medium | FTO is a known transparent conductor | RF loss and heating power; test coated antenna gain and de-icing power |
| HAPS relay | Medium | Depends on infrastructure the project does not build | Treat HAPS as an external link option; design the device to work with other backhaul as well |
| ASIC tapeout | High | FPGA RTL gives a validated starting point | schedule; use a shared multi-project wafer run and complete verification first |

### Cost and complexity

Most of the hardware are affordable and off-the-shelf (foam, aluminium, heat pipes, sensors, a small heater). The larger costs are the ASIC tapeout and any radiation or environmental testing, which is why the FPGA stage comes first.

### What still needs validation (Needs permissions, cooperation and support to execute these)

- Radiation behaviour of the design under real particle exposure or an accepted test method, since current fault injection is simulated.
- Thermal model against measurements in a cold and low-pressure chamber.
- Arc-risk detection: how the arc\_risk\_flag is generated from sensors.
- RF performance of the FTO-coated antenna.

## Roadmap

1. **Done:** ECC RAM and base RAM on the Nexys A7 with fault injection, on-demand scrubbing and a side-by-side display and LED comparison.
2. **Done:** Simulink thermal and control model with the four operating modes; control FSMs written in RTL with a watchdog and TMR.
3. **D****o****ne****:** demonstrate the hardened control FSM on the FPGA.
4. **D****o****n****e****:** extend scrubbing from on-demand to automatic and periodic, and add a simulated double-error test to the demo.
5. **D****o****ne****:** run the control FSM and the ECC RAM together on the FPGA, driven by the Simulink scenarios.
6. **N****e****x****t****:** ASIC tapeout of the ECC RAM and hardened control logic.
7. **N****e****xt****:** physical enclosure prototype with cold and low-pressure chamber testing, coated-antenna RF tests, and a HAPS link study.

## Team guide: how the parts connect

The subsystems meet at a small number of interfaces, so each member can work on their part if they know what it receives and what it must provide.

| From | To | What passes between them |
| --- | --- | --- |
| Temperature, pressure and humidity sensors | Control unit | T\_electronics, T\_battery, and the arc\_risk\_flag, moisture\_flag and idle\_flag inputs |
| Control unit | Supplemental heater | heater\_on |
| Control unit | Heat path to the battery | heat\_to\_battery |
| Control unit | BMS charge gate | charge\_enable (charging allowed only above 0 °C) |
| Control unit | Operators and telemetry | alert and active\_mode (0 cold-start, 1 normal, 2 storage, 3 fault) |
| Control unit | ECC RAM | Stored parameters and logs, protected against bit flips |
| Telemetry | Antenna and HAPS | Intended path for sending alerts and logs off-site |
| Enclosure | Everything | Insulation, sealing and the heat network that the thermal model assumes |

### Where to read first

| If you work on | Read |
| --- | --- |
| Memory, RTL or the FPGA demo | Subsystem 1 |
| Thermal model or control logic | Subsystem 2, then the interface table above |
| Mechanical design or materials | Subsystem 3 |
| Antenna or communications | Subsystem 4 |
| Presentation, report or video | Executive summary, Key features, Impact, Viability |

### Glossary

| Term | Meaning |
| --- | --- |
| SEU | Single-event upset: one stored bit flipped by a charged particle |
| ECC | Error-correcting code: extra stored bits that let errors be found and fixed |
| Scrubbing | Reading, correcting and rewriting memory so errors do not accumulate |
| TMR | Triple modular redundancy: three copies of logic and a majority vote |
| Watchdog | Timer that resets a controller that stops responding |
| FSM | Finite-state machine |
| RTL | Register-transfer level: hardware described in code (here SystemVerilog) |
| FPGA / ASIC | Reprogrammable chip / custom-fabricated chip |
| BMS | Battery management system |
| FTO | Fluorine-doped tin oxide, a transparent conductive film |
| HAPS | High Altitude Platform Station |
| Paschen's law | Relates the breakdown voltage of a gas gap to pressure and gap size |
