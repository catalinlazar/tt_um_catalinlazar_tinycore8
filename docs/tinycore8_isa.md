# TinyCore8 ISA Reference

TinyCore8 is a minimal 8-bit accumulator CPU intended for a single Tiny Tapeout SKY130 tile.

## Programmer-visible state

- `R0..R7`: eight 8-bit registers
- `R0`: accumulator for ALU operations
- `PC`: 4-bit program counter
- `OUT`: 8-bit output port
- `Z`: zero flag

## Memory model

- Program memory: 16 bytes
- Data memory: registers only
- Instructions are mostly 1 byte
- `LDI` is 2 bytes

## Instruction format

Most instructions:

```text
[7:4] opcode
[3:1] register index
[0]   mode bit
```

Jump instructions:

```text
[7:4] opcode
[3:0] absolute address
```

## Instruction table

| Mnemonic | Encoding | Bytes | Description |
|---|---:|---:|---|
| `NOP` | `0x00` | 1 | No operation |
| `LDI Rr, imm8` | `0x10 + (r << 1)`, `imm8` | 2 | Load immediate into register |
| `MOV R0, Rr` | `0x20 + (r << 1)` | 1 | Copy register to accumulator |
| `MOV Rr, R0` | `0x21 + (r << 1)` | 1 | Copy accumulator to register |
| `ADD R0, Rr` | `0x30 + (r << 1)` | 1 | `R0 = R0 + Rr` |
| `SUB R0, Rr` | `0x40 + (r << 1)` | 1 | `R0 = R0 - Rr` |
| `XOR R0, Rr` | `0x50 + (r << 1)` | 1 | `R0 = R0 ^ Rr` |
| `AND R0, Rr` | `0x60 + (r << 1)` | 1 | `R0 = R0 & Rr` |
| `IN Rr` | `0x70 + (r << 1)` | 1 | Load `{4'b0000, ui_in[7:4]}` into register |
| `OUT Rr` | `0x80 + (r << 1)` | 1 | Output register to `uo_out[7:0]` |
| `JMP addr4` | `0x90 + addr` | 1 | Absolute jump |
| `JZ addr4` | `0xA0 + addr` | 1 | Jump if zero flag is set |
| `INC Rr` | `0xB0 + (r << 1)` | 1 | Increment register |
| `DEC Rr` | `0xC0 + (r << 1)` | 1 | Decrement register |
| `HALT` | `0xF0` | 1 | Stop execution |

## Example: count forever

```asm
LDI R0, 0x00
OUT R0
INC R0
JMP 2
```

Machine code:

```text
10 00 80 B0 92
```

## Example: silicon smoke test

```asm
LDI R0, 0xA5
OUT R0
HALT
```

Machine code:

```text
10 A5 80 F0
```
