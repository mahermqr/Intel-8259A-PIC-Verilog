# Intel 8259A Programmable Interrupt Controller (PIC) - Architecture Documentation

## Overview
The Intel 8259A is a Programmable Interrupt Controller designed for microprocessors (such as the 8086/8088 and 8085). It manages up to 8 vectored priority interrupts per chip and can be cascaded with up to 8 slave controllers to manage up to 64 hardware interrupt request lines.

---

## Block Architecture

The design is modularized into 5 primary synthesizable sub-blocks:

```
                  +-----------------------------------+
                  |            PIC8259A               |
                  |                                   |
    IRBus[7:0] --->|   [IRR]   -> [PriorityResolver]  |
                  |     |               |             |
                  |   [ISR] <-----------+             |
                  |     |                             |
    DBus[7:0] <==>| [RWLogic] <----> [CascadeModule] <===> CAS[2:0]
    INTA_n   ---->|   |                               |
    INT      <----|---+-------------------------------+
```

### 1. Interrupt Request Register (IRR) - `rtl/IRR.v`
- Stores pending interrupt requests from pins `IR7-IR0`.
- Configurable per ICW1 bit 3 (`LTIM`):
  - **Edge-Triggered Mode (`LTIM = 0`)**: Detects low-to-high (0 -> 1) transitions and latches the request until cleared during the INTA sequence.
  - **Level-Triggered Mode (`LTIM = 1`)**: Directly tracks the high logic level of `IRBus`.

### 2. In-Service Register (ISR) - `rtl/ISR.v`
- Stores interrupt levels currently being serviced by the CPU.
- When `INTA_n` Pulse 1 is received, bit `ack_level` is set in `ISR` and cleared in `IRR`.
- Calculates the 8-bit vector address byte: `{ICW2[7:3], ack_level[2:0]}`.
- Cleared upon receiving an End-Of-Interrupt (EOI) command via `OCW2` or automatically if Auto-EOI (`AEOI`) is enabled in `ICW4`.

### 3. Priority Resolver - `rtl/PriorityResolver.v`
- Evaluates active pending requests from `maskedIRR = IRR & ~IMR`.
- **Fully Nested Mode**: Pins are prioritized in fixed order: `IR0` (highest) -> `IR1` -> ... -> `IR7` (lowest).
- **Auto-Rotating Priority Mode**: Lowest priority level dynamically moves to the last acknowledged level after EOI.

### 4. Read/Write Logic & Command Register Interface - `rtl/RWLogic.v`
Handles programming state machine for Initialization Command Words (ICWs) and Operation Control Words (OCWs):

#### Initialization Sequence:
1. **ICW1** (`A0 = 0`, `D4 = 1`): Sets edge/level mode (`LTIM`), single/cascade mode (`SNGL`), and ICW4 requirement (`IC4`).
2. **ICW2** (`A0 = 1`): Sets upper 5 vector address bits `T7-T3`.
3. **ICW3** (`A0 = 1`, if Cascade mode): In Master mode, bitmask of attached Slaves; in Slave mode, 3-bit Slave ID.
4. **ICW4** (`A0 = 1`, if `IC4 = 1`): Sets 8086/MCS-85 mode (`uPM`), Auto-EOI (`AEOI`), and Special Fully Nested mode.

#### Operational Commands:
- **OCW1** (`A0 = 1`): Writes 8-bit Interrupt Mask Register (IMR).
- **OCW2** (`A0 = 0`, `D4=0, D3=0`): EOI commands (Specific / Non-Specific) and priority rotation.
- **OCW3** (`A0 = 0`, `D4=0, D3=1`): Selects status readback (Read IRR or Read ISR) on `RD_n` pulse.

### 5. Cascade Controller & CAS Bus Arbitration - `rtl/CascadeModule.v`
- Controls 3-bit bidirectional `CAS[2:0]` bus.
- **Master PIC**:
  - When an interrupt occurs on pin `i`, if `ICW3[i] == 1` (a Slave is attached), Master outputs `i` on `CAS[2:0]`.
  - If `ICW3[i] == 0` (local device), Master claims `Address_Write_Enable = 1` to drive vector byte.
- **Slave PIC**:
  - Monitors `CAS[2:0]`. When `CAS == ICW3[2:0]`, Slave claims `Address_Write_Enable = 1` and drives vector byte onto shared `DBus`.

---

## Timing Diagrams & Handshake

### 2-Pulse INTA Handshake Sequence (8086 Mode)
```
          __    ______________________________________
INT       __><__/                                     \___
          ____      ____          ____
INTA_n        \____/    \________/    \___________________
               Pulse 1   Pulse 2
          ______________ _________________________________
CAS[2:0]  ______________X________Slave ID_________________
                        __________________________________
DBus[7:0] --------------< Vector Byte (T7-T3 | Level)     >---
```
1. **Pulse 1**: PIC latches priority level (`ack_level`), sets `ISR` bit, clears `IRR` bit. Master drives `CAS[2:0]`.
2. **Pulse 2**: Active controller (Master or selected Slave) drives 8-bit vector address onto `DBus`.
