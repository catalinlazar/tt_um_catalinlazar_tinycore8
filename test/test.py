import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, Timer


async def settle():
    await Timer(3, units="ns")


async def reset(dut):
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 8)
    await settle()
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 4)
    await settle()


async def loader_bit(dut, bit):
    ui = int(dut.ui_in.value)
    ui &= ~0x03
    ui |= (bit & 1) << 1

    dut.ui_in.value = ui
    await ClockCycles(dut.clk, 2)

    dut.ui_in.value = ui | 0x01
    await ClockCycles(dut.clk, 2)

    dut.ui_in.value = ui & ~0x01
    await ClockCycles(dut.clk, 2)


async def load_byte(dut, value):
    for bit in range(7, -1, -1):
        await loader_bit(dut, (value >> bit) & 1)


async def load_program_and_run(dut, program):
    dut.ui_in.value = 0x04
    await ClockCycles(dut.clk, 4)

    for byte in program:
        await load_byte(dut, byte)

    dut.ui_in.value = 0x00
    await ClockCycles(dut.clk, 6)

    dut.ui_in.value = 0x08
    await ClockCycles(dut.clk, 4)


async def expect_output(dut, expected):
    await settle()
    value = dut.uo_out.value
    assert value.is_resolvable, f"uo_out has X/Z value: {value}"
    assert int(value) == expected, f"expected 0x{expected:02X}, got 0x{int(value):02X}"


@cocotb.test()
async def smoke_test_a5(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())

    await reset(dut)

    await load_program_and_run(dut, [0x10, 0xA5, 0x80, 0xF0])

    await ClockCycles(dut.clk, 30)
    await expect_output(dut, 0xA5)


@cocotb.test()
async def counter_test(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())

    await reset(dut)

    await load_program_and_run(dut, [0x10, 0x00, 0x80, 0xB0, 0x92])

    await ClockCycles(dut.clk, 12)
    await expect_output(dut, 0x01)

    await ClockCycles(dut.clk, 6)
    await expect_output(dut, 0x02)

    await ClockCycles(dut.clk, 6)
    await expect_output(dut, 0x03)