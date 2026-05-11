#!/usr/bin/env python3
"""
TinyCore8 assembler.

Usage:
    python3 tools/tinycore8_asm.py examples/count.asm -o examples/count.hex
    python3 tools/tinycore8_asm.py examples/smoke.asm --bin -o smoke.bin

The assembler emits up to 16 program bytes by default.
Comments start with ';' or '#'.
"""

from __future__ import annotations

import argparse
import re
from pathlib import Path

MAX_PROGRAM_BYTES = 16


def strip_comment(line: str) -> str:
    line = line.split(";", 1)[0]
    line = line.split("#", 1)[0]
    return line.strip()


def parse_int(token: str) -> int:
    token = token.strip()
    if token.lower().startswith("0x"):
        return int(token, 16)
    if token.lower().startswith("0b"):
        return int(token, 2)
    return int(token, 10)


def parse_reg(token: str) -> int:
    token = token.strip().upper()
    if not re.fullmatch(r"R[0-7]", token):
        raise ValueError(f"bad register '{token}', expected R0..R7")
    return int(token[1])


def split_operands(text: str) -> list[str]:
    return [p.strip() for p in text.split(",") if p.strip()]


def instr_size(line: str) -> int:
    op = line.split(None, 1)[0].upper()
    return 2 if op == "LDI" else 1


def parse_source(source: str) -> list[str]:
    lines: list[str] = []
    for raw in source.splitlines():
        line = strip_comment(raw)
        if line:
            lines.append(line)
    return lines


def first_pass(lines: list[str]) -> tuple[list[str], dict[str, int]]:
    pc = 0
    program_lines: list[str] = []
    labels: dict[str, int] = {}

    for line in lines:
        if line.endswith(":"):
            label = line[:-1].strip()
            if not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", label):
                raise ValueError(f"bad label name: {label}")
            if label in labels:
                raise ValueError(f"duplicate label: {label}")
            labels[label] = pc
            continue

        # support "label: instr ..."
        if ":" in line:
            label, rest = line.split(":", 1)
            label = label.strip()
            rest = rest.strip()
            if not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", label):
                raise ValueError(f"bad label name: {label}")
            if label in labels:
                raise ValueError(f"duplicate label: {label}")
            labels[label] = pc
            if rest:
                program_lines.append(rest)
                pc += instr_size(rest)
            continue

        program_lines.append(line)
        pc += instr_size(line)

    return program_lines, labels


def parse_addr4(token: str, labels: dict[str, int]) -> int:
    token = token.strip()
    if token in labels:
        value = labels[token]
    else:
        value = parse_int(token)
    if not 0 <= value <= 15:
        raise ValueError(f"address out of range 0..15: {token}")
    return value


def assemble_line(line: str, labels: dict[str, int]) -> list[int]:
    parts = line.split(None, 1)
    op = parts[0].upper()
    rest = parts[1].strip() if len(parts) > 1 else ""
    ops = split_operands(rest)

    if op == "NOP":
        return [0x00]

    if op == "HALT":
        return [0xF0]

    if op == "LDI":
        if len(ops) != 2:
            raise ValueError("LDI syntax: LDI Rr, imm8")
        r = parse_reg(ops[0])
        imm = parse_int(ops[1])
        if not 0 <= imm <= 255:
            raise ValueError(f"immediate out of range 0..255: {ops[1]}")
        return [0x10 + (r << 1), imm]

    if op == "MOV":
        if len(ops) != 2:
            raise ValueError("MOV syntax: MOV R0, Rr or MOV Rr, R0")
        dst = parse_reg(ops[0])
        src = parse_reg(ops[1])
        if dst == 0:
            return [0x20 + (src << 1)]       # MOV R0, Rr
        if src == 0:
            return [0x21 + (dst << 1)]       # MOV Rr, R0
        raise ValueError("MOV only supports MOV R0,Rr or MOV Rr,R0")

    alu_ops = {
        "ADD": 0x30,
        "SUB": 0x40,
        "XOR": 0x50,
        "AND": 0x60,
    }
    if op in alu_ops:
        if len(ops) != 2:
            raise ValueError(f"{op} syntax: {op} R0, Rr")
        dst = parse_reg(ops[0])
        src = parse_reg(ops[1])
        if dst != 0:
            raise ValueError(f"{op} destination must be R0")
        return [alu_ops[op] + (src << 1)]

    one_reg_ops = {
        "IN": 0x70,
        "OUT": 0x80,
        "INC": 0xB0,
        "DEC": 0xC0,
    }
    if op in one_reg_ops:
        if len(ops) != 1:
            raise ValueError(f"{op} syntax: {op} Rr")
        r = parse_reg(ops[0])
        return [one_reg_ops[op] + (r << 1)]

    if op == "JMP":
        if len(ops) != 1:
            raise ValueError("JMP syntax: JMP addr4")
        return [0x90 + parse_addr4(ops[0], labels)]

    if op == "JZ":
        if len(ops) != 1:
            raise ValueError("JZ syntax: JZ addr4")
        return [0xA0 + parse_addr4(ops[0], labels)]

    raise ValueError(f"unknown instruction: {op}")


def assemble(source: str) -> list[int]:
    raw_lines = parse_source(source)
    program_lines, labels = first_pass(raw_lines)

    out: list[int] = []
    for line in program_lines:
        out.extend(assemble_line(line, labels))

    if len(out) > MAX_PROGRAM_BYTES:
        raise ValueError(f"program is {len(out)} bytes, max is {MAX_PROGRAM_BYTES}")

    return out


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("input", type=Path)
    parser.add_argument("-o", "--output", type=Path, required=True)
    parser.add_argument("--bin", action="store_true", help="write binary instead of hex text")
    parser.add_argument("--pad", action="store_true", help="pad output to 16 bytes")
    args = parser.parse_args()

    code = assemble(args.input.read_text())

    if args.pad:
        code = code + [0x00] * (MAX_PROGRAM_BYTES - len(code))

    if args.bin:
        args.output.write_bytes(bytes(code))
    else:
        args.output.write_text(" ".join(f"{b:02X}" for b in code) + "\n")

    print(f"assembled {len(code)} byte(s): " + " ".join(f"{b:02X}" for b in code))


if __name__ == "__main__":
    main()
