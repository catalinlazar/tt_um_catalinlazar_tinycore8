`default_nettype none

module tt_um_catalinlazar_tinycore8 (
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);

    assign uio_out = 8'b0000_0000;
    assign uio_oe  = 8'b0000_0000;

    reg [7:0] regs [0:7];
    reg [7:0] pmem [0:15];

    reg [3:0] pc;
    reg [7:0] instr;
    reg [7:0] out_reg;
    reg       halted;
    reg       zero;

    assign uo_out = out_reg;

    localparam S_FETCH = 2'd0;
    localparam S_EXEC  = 2'd1;
    localparam S_IMM   = 2'd2;

    reg [1:0] state;
    reg [2:0] imm_dst;

    wire load_clk = ui_in[0];
    wire load_dat = ui_in[1];
    wire load_en  = ui_in[2];
    wire run      = ui_in[3];

    reg [2:0] load_sync;
    wire load_rise = (load_sync[2:1] == 2'b01);

    reg [7:0] shift;
    reg [2:0] bitcnt;
    reg [3:0] load_addr;

    integer i;

    wire [3:0] opcode = instr[7:4];
    wire [2:0] rsel   = instr[3:1];
    wire       mode   = instr[0];
    wire [3:0] addr4  = instr[3:0];

    // Keep Verilator/lint happy for intentionally unused signals/bits.
    wire _unused = &{1'b0, uio_in, shift[7], load_dat, 1'b0};

    always @(posedge clk) begin
        if (!rst_n) begin
            pc        <= 4'd0;
            instr     <= 8'd0;
            out_reg   <= 8'd0;
            halted    <= 1'b0;
            zero      <= 1'b0;
            state     <= S_FETCH;
            imm_dst   <= 3'd0;
            load_sync <= 3'd0;
            shift     <= 8'd0;
            bitcnt    <= 3'd0;
            load_addr <= 4'd0;

            for (i = 0; i < 8; i = i + 1) begin
                regs[i] <= 8'd0;
            end

            for (i = 0; i < 16; i = i + 1) begin
                pmem[i] <= 8'd0;
            end
        end else begin
            load_sync <= {load_sync[1:0], load_clk};

            if (load_en) begin
                halted <= 1'b0;
                pc     <= 4'd0;
                state  <= S_FETCH;

                if (load_rise) begin
                    shift  <= {shift[6:0], load_dat};
                    bitcnt <= bitcnt + 3'd1;

                    if (bitcnt == 3'd7) begin
                        pmem[load_addr] <= {shift[6:0], load_dat};
                        load_addr       <= load_addr + 4'd1;
                    end
                end
            end else if (run && ena && !halted) begin
                case (state)

                    S_FETCH: begin
                        instr <= pmem[pc];
                        pc    <= pc + 4'd1;
                        state <= S_EXEC;
                    end

                    S_EXEC: begin
                        case (opcode)

                            4'h0: begin
                                state <= S_FETCH;
                            end

                            4'h1: begin
                                imm_dst <= rsel;
                                state   <= S_IMM;
                            end

                            4'h2: begin
                                if (mode) begin
                                    regs[rsel] <= regs[0];
                                end else begin
                                    regs[0] <= regs[rsel];
                                end
                                state <= S_FETCH;
                            end

                            4'h3: begin
                                regs[0] <= regs[0] + regs[rsel];
                                zero    <= ((regs[0] + regs[rsel]) == 8'd0);
                                state   <= S_FETCH;
                            end

                            4'h4: begin
                                regs[0] <= regs[0] - regs[rsel];
                                zero    <= ((regs[0] - regs[rsel]) == 8'd0);
                                state   <= S_FETCH;
                            end

                            4'h5: begin
                                regs[0] <= regs[0] ^ regs[rsel];
                                zero    <= ((regs[0] ^ regs[rsel]) == 8'd0);
                                state   <= S_FETCH;
                            end

                            4'h6: begin
                                regs[0] <= regs[0] & regs[rsel];
                                zero    <= ((regs[0] & regs[rsel]) == 8'd0);
                                state   <= S_FETCH;
                            end

                            4'h7: begin
                                regs[rsel] <= {4'b0000, ui_in[7:4]};
                                zero       <= ({4'b0000, ui_in[7:4]} == 8'd0);
                                state      <= S_FETCH;
                            end

                            4'h8: begin
                                out_reg <= regs[rsel];
                                state   <= S_FETCH;
                            end

                            4'h9: begin
                                pc    <= addr4;
                                state <= S_FETCH;
                            end

                            4'hA: begin
                                if (zero) begin
                                    pc <= addr4;
                                end
                                state <= S_FETCH;
                            end

                            4'hB: begin
                                regs[rsel] <= regs[rsel] + 8'd1;
                                zero       <= ((regs[rsel] + 8'd1) == 8'd0);
                                state      <= S_FETCH;
                            end

                            4'hC: begin
                                regs[rsel] <= regs[rsel] - 8'd1;
                                zero       <= ((regs[rsel] - 8'd1) == 8'd0);
                                state      <= S_FETCH;
                            end

                            4'hF: begin
                                halted <= 1'b1;
                                state  <= S_FETCH;
                            end

                            default: begin
                                state <= S_FETCH;
                            end

                        endcase
                    end

                    S_IMM: begin
                        regs[imm_dst] <= pmem[pc];
                        zero          <= (pmem[pc] == 8'd0);
                        pc            <= pc + 4'd1;
                        state         <= S_FETCH;
                    end

                    default: begin
                        state <= S_FETCH;
                    end

                endcase
            end
        end
    end

endmodule

`default_nettype wire