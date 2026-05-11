`timescale 1ns/1ps

module tb_tinycore8;

    reg         clk;
    reg         rst_n;
    reg  [7:0] ui_in;
    wire [7:0] uo_out;
    reg  [7:0] uio_in;
    wire [7:0] uio_out;
    wire [7:0] uio_oe;
    reg         ena;

    // Rename this instance if your top-level module name is different.
    tt_um_tinycore8 dut (
        .ui_in(ui_in),
        .uo_out(uo_out),
        .uio_in(uio_in),
        .uio_out(uio_out),
        .uio_oe(uio_oe),
        .ena(ena),
        .clk(clk),
        .rst_n(rst_n)
    );

    localparam integer CLK_PERIOD = 10;

    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    task reset_dut;
        begin
            rst_n  = 1'b0;
            ui_in  = 8'h00;
            uio_in = 8'h00;
            ena    = 1'b1;
            repeat (5) @(posedge clk);
            rst_n = 1'b1;
            repeat (2) @(posedge clk);
        end
    endtask

    // Serial loader pins:
    // ui_in[0] = load_clk
    // ui_in[1] = load_data
    // ui_in[2] = load_enable
    // ui_in[3] = run
    task loader_clock_bit(input bit_value);
        begin
            ui_in[1] = bit_value;
            repeat (2) @(posedge clk);
            ui_in[0] = 1'b1;
            repeat (2) @(posedge clk);
            ui_in[0] = 1'b0;
            repeat (2) @(posedge clk);
        end
    endtask

    task load_byte(input [7:0] value);
        integer i;
        begin
            for (i = 7; i >= 0; i = i - 1) begin
                loader_clock_bit(value[i]);
            end
        end
    endtask

    task begin_load;
        begin
            ui_in[3] = 1'b0; // run low
            ui_in[2] = 1'b1; // load_enable high
            ui_in[0] = 1'b0;
            repeat (2) @(posedge clk);
        end
    endtask

    task end_load_and_run;
        begin
            ui_in[2] = 1'b0; // load_enable low
            repeat (3) @(posedge clk);
            ui_in[3] = 1'b1; // run high
            repeat (2) @(posedge clk);
        end
    endtask

    task check_output(input [7:0] expected);
        begin
            if (uo_out !== expected) begin
                $display("FAIL at time %0t: expected uo_out=%02h, got %02h",
                         $time, expected, uo_out);
                $fatal;
            end
            $display("PASS at time %0t: uo_out=%02h", $time, uo_out);
        end
    endtask

    task wait_cycles(input integer n);
        integer k;
        begin
            for (k = 0; k < n; k = k + 1)
                @(posedge clk);
        end
    endtask

    initial begin
        $dumpfile("tinycore8_tb.vcd");
        $dumpvars(0, tb_tinycore8);

        // Test 1: silicon smoke program
        // LDI R0, 0xA5
        // OUT R0
        // HALT
        reset_dut();
        begin_load();
        load_byte(8'h10);
        load_byte(8'hA5);
        load_byte(8'h80);
        load_byte(8'hF0);
        end_load_and_run();

        wait_cycles(12);
        check_output(8'hA5);

        // HALT should hold the output.
        wait_cycles(20);
        check_output(8'hA5);

        // Test 2: counting program
        // LDI R0, 0x00
        // OUT R0
        // INC R0
        // JMP 2
        reset_dut();
        begin_load();
        load_byte(8'h10);
        load_byte(8'h00);
        load_byte(8'h80);
        load_byte(8'hB0);
        load_byte(8'h92);
        end_load_and_run();

        // With this FSM, each 1-byte instruction takes 2 clocks.
        // Initial LDI takes fetch/exec/imm.
        wait_cycles(8);
        check_output(8'h00);

        wait_cycles(4);
        check_output(8'h01);

        wait_cycles(6);
        check_output(8'h02);

        wait_cycles(6);
        check_output(8'h03);

        $display("All TinyCore8 tests passed.");
        $finish;
    end

endmodule
