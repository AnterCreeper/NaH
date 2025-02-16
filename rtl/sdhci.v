`include "defines.v"

module spi_phy(
    input clk,
    input rst,
    input[7:0] div,

    input wr,
    input[7:0] wr_data,
    
    output reg rd,
    output reg[7:0] rd_data,

    output spi_clk,
    output reg spi_mosi,
    input spi_miso
);

reg en;
reg cke;
reg rs;
reg[7:0] tx;
reg[7:0] rx;

reg pclk;
reg[7:0] pclk_cnt;

always @(posedge clk or negedge en)
begin
    if (!en)
    begin
        pclk_cnt <= 0;
        pclk <= 0;
    end else
    begin
        if (pclk_cnt != div)
            pclk_cnt <= pclk_cnt + 1;
        else
        begin
            pclk_cnt <= 0;
            pclk <= ~pclk;
        end
    end
end

always @(posedge clk or posedge rst)
begin
    if (rst) begin
        en <= 0;
        tx <= 0;
    end else
    if (rs) begin
        en <= 0;
        rd <= 1;
        rd_data <= {rx[0], rx[1], rx[2], rx[3],
                rx[4], rx[5], rx[6], rx[7]};
        tx <= 0;
    end else 
    begin
        rd <= 0;
        rd_data <= 0;
        if (wr) 
        begin
            en <= 1;
            tx <= {wr_data[0], wr_data[1], wr_data[2], wr_data[3],
                wr_data[4], wr_data[5], wr_data[6], wr_data[7]};
        end
    end
end

reg[3:0] counter;

assign spi_clk = cke ? pclk : 0;

always @(negedge pclk or negedge en)
begin
    if (!en)
    begin
        cke <= 0;
        rs <= 0;
        spi_mosi <= 1'b1;
    end else
    begin
        cke <= 1;
        if (counter == 8) begin
            rs <= 1;
        end else
        begin
            spi_mosi <= tx[counter];
        end
    end
end

always @(posedge pclk or negedge en)
begin
    if (!en)
    begin
        rx <= 0;
        counter <= 4'hf;
    end else
    begin
        rx[counter] <= spi_miso;
        counter <= counter + 1;
    end
end
endmodule

module rom(
    input[11:0] addr,
    output reg[15:0] inst
);

//instr:
`define jnz 4'h0 //jnz imm (if A!=0 set PC=imm)
`define js  4'h1 //js imm (if A<0 set PC=imm)
`define add 4'h2 //add imm (A=A+imm)
`define mov 4'h3 //mov imm (A=imm)
`define tx  4'h4 //tx (transfer imm)
`define ta  4'h5 //ta (transfer A)
`define lt  4'h6 //lt (load from %A and transfer)
`define ra  4'h7 //ra (receive to A)
`define rs  4'h8 //rs (receive and store to %A)
`define cs  4'h9 //cs (flip CS)
`define stb 4'ha //stb imm (A <= A | imm)
`define rsb 4'hb //rsb imm (A <= A & (~imm))
`define wsr 4'hc //wsr imm (reg[imm] <= A)
`define rsr 4'hd //rsr imm (A <= reg[imm])
`define ccd 4'he //ccd (change clock div)
`define hlt 4'hf //hlt (set busy = 0 and wait for request)

always @(*)
begin
    case(addr)

//clock sync
    12'h00: inst <= {12'h00a, `mov};
    12'h01: inst <= {12'h0ff, `tx};  //L0
    12'h02: inst <= {12'hfff, `add};
    12'h03: inst <= {12'h001, `jnz}; //jnz L0

//cmd0
    12'h04: inst <= {12'h000, `cs};
    12'h05: inst <= {12'h040, `tx};
    12'h06: inst <= {12'h000, `tx};
    12'h07: inst <= {12'h000, `tx};
    12'h08: inst <= {12'h000, `tx};
    12'h09: inst <= {12'h000, `tx};
    12'h0a: inst <= {12'h095, `tx};
    12'h0b: inst <= {12'h000, `ra};  //L1
    12'h0c: inst <= {12'hfff, `add};
    12'h0d: inst <= {12'h00b, `jnz}; //jnz L1
    12'h0e: inst <= {12'h000, `cs};
    12'h0f: inst <= {12'h0ff, `tx};

//cmd8
    12'h10: inst <= {12'h000, `cs};
    12'h11: inst <= {12'h048, `tx};
    12'h12: inst <= {12'h000, `tx};
    12'h13: inst <= {12'h000, `tx};
    12'h14: inst <= {12'h001, `tx};
    12'h15: inst <= {12'h0aa, `tx};
    12'h16: inst <= {12'h087, `tx};
    12'h17: inst <= {12'h000, `ra};  //L2
    12'h18: inst <= {12'hfff, `add};
    12'h19: inst <= {12'h017, `jnz}; //jnz L2
    12'h1a: inst <= {12'h0ff, `tx};
    12'h1b: inst <= {12'h0ff, `tx};
    12'h1c: inst <= {12'h0ff, `tx};
    12'h1d: inst <= {12'h0ff, `tx};  //ignore them.
    12'h1e: inst <= {12'h000, `cs};
    12'h1f: inst <= {12'h0ff, `tx};

//cmd55
    12'h20: inst <= {12'h000, `cs};  //L3
    12'h21: inst <= {12'h077, `tx};
    12'h22: inst <= {12'h000, `tx};
    12'h23: inst <= {12'h000, `tx};
    12'h24: inst <= {12'h000, `tx};
    12'h25: inst <= {12'h000, `tx};
    12'h26: inst <= {12'h065, `tx};
    12'h27: inst <= {12'h000, `ra};  //L4
    12'h28: inst <= {12'hfff, `add};
    12'h29: inst <= {12'h027, `jnz}; //jnz L4
    12'h2a: inst <= {12'h000, `cs};
    12'h2b: inst <= {12'h0ff, `tx};
//acmd41
    12'h2c: inst <= {12'h000, `cs};
    12'h2d: inst <= {12'h069, `tx};
    12'h2e: inst <= {12'h040, `tx};
    12'h2f: inst <= {12'h000, `tx};
    12'h30: inst <= {12'h000, `tx};
    12'h31: inst <= {12'h000, `tx};
    12'h32: inst <= {12'h077, `tx};
    12'h33: inst <= {12'h000, `ra};  //L5
    12'h34: inst <= {12'h033, `js};  //js L5
    12'h35: inst <= {12'h0ff, `tx};
    12'h36: inst <= {12'h0ff, `tx};
    12'h37: inst <= {12'h0ff, `tx};
    12'h38: inst <= {12'h0ff, `tx};  //ignore them.
    12'h39: inst <= {12'h000, `cs};
    12'h3a: inst <= {12'h0ff, `tx};
    12'h3b: inst <= {12'h020, `jnz}; //jnz L3

//set clock divider and halt.
    12'h3c: inst <= {12'h000, `ccd};
    12'h3d: inst <= {12'h000 ,`hlt};  //L6

//read, send cmd17
    12'h3e: inst <= {12'h000 ,`cs};
    12'h3f: inst <= {12'h051 ,`tx};
    12'h40: inst <= {12'h000 ,`rsr};
    12'h41: inst <= {12'h000 ,`ta};
    12'h42: inst <= {12'h001 ,`rsr};
    12'h43: inst <= {12'h000 ,`ta};
    12'h44: inst <= {12'h002 ,`rsr};
    12'h45: inst <= {12'h000 ,`ta};
    12'h46: inst <= {12'h003 ,`rsr};
    12'h47: inst <= {12'h000 ,`ta};
    12'h48: inst <= {12'h0ff ,`tx};
    12'h49: inst <= {12'h000 ,`ra};  //L7
    12'h4a: inst <= {12'h049 ,`jnz}; //jnz L7
    12'h4b: inst <= {12'h000 ,`ra};  //L8
    12'h4c: inst <= {12'h002 ,`add};
    12'h4d: inst <= {12'h04b ,`jnz}; //jnz L8
    12'h4e: inst <= {12'h200 ,`mov};
    12'h4f: inst <= {12'hfff ,`add}; //L9
    12'h50: inst <= {12'h000 ,`rs};
    12'h51: inst <= {12'h04f ,`jnz}; //jnz L9
    12'h52: inst <= {12'h0ff ,`tx};
    12'h53: inst <= {12'h0ff ,`tx};
    12'h54: inst <= {12'h000 ,`cs};
    12'h55: inst <= {12'h0ff ,`tx};

//loop and halt
    12'h56: inst <= {12'hfff ,`mov};
    12'h57: inst <= {12'h03d ,`jnz}; //jnz L6

    default: 
            inst <= {12'h000 ,`add};
            
    endcase
end

endmodule

`define SPI_FAST_DIV 1
`define SPI_SLOW_DIV 255

`define ADDRESS_ISSUE 0
`define SD_STATUS_ISSUE 1
`define READ_ISSUE 2
`define WRITE_ISSUE 3
`define REG_ISSUE 4
`define DIVIDER_ISSUE 5
    
module sdhci(
    input clk,
    input rst,

    input evb_cmd_request,
    input[3:0] evb_cmd_addr,
    input[1:0] evb_cmd_wr_mask,
    input[31:0] evb_cmd_wr_data,
    output reg evb_cmd_finish,
    output reg[31:0] evb_cmd_rd_data,
    
    output reg tcm_write_request,
    input tcm_request_finish,
    output reg[31:0] tcm_addr,
    output reg[127:0] tcm_write_data,
    
    output reg spi_cs,
    output spi_clk,
    output spi_mosi,
    input spi_miso,
    
    output busy,
    output en
);

reg[7:0] div;

reg tx;
reg[7:0] tx_data;
wire rx;
wire[7:0] rx_data;

spi_phy phy(
    .clk(clk),
    .rst(rst),
    .div(div),

    .wr(tx),
    .wr_data(tx_data),
    
    .rd(rx),
    .rd_data(rx_data),

    .spi_clk(spi_clk),
    .spi_mosi(spi_mosi),
    .spi_miso(spi_miso)
);

reg[1:0] fsm;

reg[11:0] pc;
reg[11:0] A;
reg[7:0] B;

wire[15:0] inst;
wire[11:0] imm;
wire[3:0] opcode;
assign imm = inst[15:4];
assign opcode = inst[3:0];

reg[2:0] ls_type;
reg[7:0] sr[7:0];
//sr[3] sr[2] sr[1] sr[0] maddress
//sr[4] mstatus
//sr[5] reversed

rom firmware0(
    .addr(pc),
    .inst(inst)
);

reg en, busy, issue;
reg[31:0] block_address;
reg[15:0] base_address;
reg[15:0] divider;

wire evb_cmd_wr;
assign evb_cmd_wr = evb_cmd_wr_mask[1] || evb_cmd_wr_mask[0];

reg[31:0] reg_data;
always @(*)
begin
    case(evb_cmd_addr)
    `ADDRESS_ISSUE: reg_data <= {sr[0], sr[1], sr[2], sr[3]};
    `READ_ISSUE: reg_data <= {16'h0, base_address};
    `DIVIDER_ISSUE: reg_data <= {16'h0, divider};
    `SD_STATUS_ISSUE: reg_data <= {30'h0, en, busy};
    `REG_ISSUE: reg_data <= {16'h0, sr[5], sr[4]};
    default:
        reg_data <= 0;
    endcase
end
reg[31:0] cmd;
always @(*)
begin
    case(evb_cmd_wr_mask)
    `EVB_MASK_W: cmd <= evb_cmd_wr_data;
    `EVB_MASK_H: cmd <= {evb_cmd_wr_data[15:0], reg_data[15:0]};
    `EVB_MASK_L: cmd <= {reg_data[31:16], evb_cmd_wr_data[15:0]};
    `EVB_MASK_DUMMY: cmd <= reg_data;
    endcase
end

reg[31:0] rd_addr;

always @(posedge clk or posedge rst)
begin
    if(rst)
    begin
        en <= 0;
        issue <= 0;
        block_address <= 0;
        base_address <= 0;
        rd_addr <= 0;
        evb_cmd_finish <= 0;
    end else
    if(evb_cmd_finish)
    begin
        issue <= 0;
        evb_cmd_finish <= 0;
    end else
    if(evb_cmd_request)
    begin
        if(!busy)
        begin
            case(evb_cmd_addr)
            `ADDRESS_ISSUE:
            begin
                evb_cmd_finish <= 1;
                block_address <= evb_cmd_wr ? cmd : block_address;
                evb_cmd_rd_data <= reg_data;
            end
            `DIVIDER_ISSUE:
            begin
                evb_cmd_finish <= 1;
                divider <= cmd;
                evb_cmd_rd_data <= reg_data;
            end
            `READ_ISSUE:
            begin
                evb_cmd_finish <= 1; 
                if(evb_cmd_wr)
                begin
                    issue <= 1;
                    base_address <= cmd;
                    rd_addr <= block_address;
                    block_address <= block_address + 1;
                end
                evb_cmd_rd_data <= reg_data;
            end
            `WRITE_ISSUE:
            begin
            /* not implemented yet */
            end
            endcase
        end
        case(evb_cmd_addr)
        `SD_STATUS_ISSUE:
        begin
            evb_cmd_finish <= 1;
            en <= evb_cmd_wr ? cmd[1] : en;
            if(cmd[1] && !en && evb_cmd_wr) issue <= 1;
            evb_cmd_rd_data <= reg_data;
        end
        `REG_ISSUE:
        begin
            evb_cmd_finish <= 1;
            evb_cmd_rd_data <= reg_data;
        end
        endcase
    end
end

reg wr, wr_valid;
reg[8:0] wr_addr;
reg[7:0] wr_data;

reg[31:0] perf_cnt;
        
always @(posedge clk or posedge rst)
begin
    if(rst)
    begin
        div <= `SPI_SLOW_DIV;
        tx <= 0;
        tx_data <= 0;
        fsm <= 0;
        pc <= 0;
        A <= 0;
        B <= 0;
        ls_type <= 0;
        sr[0] <= 0;
        sr[1] <= 0;
        sr[2] <= 0;
        sr[3] <= 0;
        sr[4] <= 0;
        sr[5] <= 0;
        sr[6] <= 0;
        sr[7] <= 0;
        busy <= 0;
        wr <= 0;
        spi_cs <= 1'b1;
        perf_cnt <= 0;
    end else
    if(!en)
    begin
        div <= `SPI_SLOW_DIV;
        tx <= 0;
        tx_data <= 0;
        fsm <= 0;
        pc <= 0;
        A <= 0;
        B <= 0;
        ls_type <= 0;
        sr[0] <= 0;
        sr[1] <= 0;
        sr[2] <= 0;
        sr[3] <= 0;
        sr[4] <= 0;
        sr[5] <= 0;
        sr[6] <= 0;
        sr[7] <= 0;
        busy <= 0;
        wr <= 0;
        spi_cs <= 1'b1;
    end else
    if(!busy)
    begin
        wr <= 0;
        if(issue) 
        begin
            sr[0] <= rd_addr[31:24];
            sr[1] <= rd_addr[23:16];
            sr[2] <= rd_addr[15:8];
            sr[3] <= rd_addr[7:0];
            busy <= 1;
            perf_cnt <= perf_cnt + 1;
        end
    end else
    begin
        if (fsm == 0)
        begin
            wr <= 0;
            //wr_addr <= 0;
            case(opcode)
            `jnz: if (A != 0) pc <= imm; else pc <= pc + 1;
            `js:  if (A[11])  pc <= imm; else pc <= pc + 1;
            `add: begin A <= A + imm; pc <= pc + 1; end
            `mov: begin A <= imm; pc <= pc + 1; end
            `tx:  begin fsm <= 1; ls_type <= 3'b000; end
            `ta:  begin fsm <= 1; ls_type <= 3'b001; end
            `lt:  begin fsm <= 1; ls_type <= 3'b010; end
            `ra:  begin fsm <= 1; ls_type <= 3'b101; end
            `rs:  begin fsm <= 1; ls_type <= 3'b110; end
            `cs:  begin spi_cs <= ~spi_cs; pc <= pc + 1; end
            `stb: begin A <= A | imm; pc <= pc + 1; end
            `rsb: begin A <= A & (~imm); pc <= pc + 1; end
            `wsr: begin sr[imm] <= A; pc <= pc + 1; end
            `rsr: begin A <= sr[imm]; pc <= pc + 1; end
            `ccd: begin div <= `SPI_FAST_DIV; pc <= pc + 1; end
            `hlt: begin busy <= 0; pc <= pc + 1; end
            endcase
        end else
        begin
            case(fsm)
            1: //load
            begin
                fsm <= 2;
                tx <= 1;
                case(ls_type[2:0])
                3'b000: tx_data <= imm[7:0];
                3'b001: tx_data <= A[7:0];
                default: tx_data <= 8'hFF;
                endcase
            end
            2: //tx & rx
            begin
                tx <= 0;
                tx_data <= 0;
                if (rx)
                begin
                    fsm <= 3;
                    B <= rx_data;
                end
            end
            3: //store
            begin
                case(ls_type[2:0])
                3'b101:
                begin
                    fsm <= 0;
                    pc <= pc + 1; 
                    A <= {{4{B[7]}}, B};
                end
                3'b110:
                begin
                    if(wr_valid)
                    begin
                        fsm <= 0;
                        pc <= pc + 1; 
                        wr <= 1;
                        wr_addr <= ~A;
                        wr_data <= B;
                    end
                end
                default:
                begin
                    fsm <= 0;
                    pc <= pc + 1; 
                end
                endcase
            end
            endcase
        end
    end
end

reg[127:0] cache_data;

always @(posedge clk or posedge rst)
begin
    if(rst)
    begin
        wr_valid <= 1;
        tcm_write_request <= 0;
    end else
    if(!wr_valid)
    begin
        if(tcm_request_finish)
        begin
            tcm_write_request <= 0;
            wr_valid <= 1;
        end else
        begin
            tcm_write_request <= 1;
            tcm_addr <= {wr_addr[8:4] + base_address[15:4], 4'h0};
            tcm_write_data <= cache_data;
        end
    end else
    if(wr)
    begin
        cache_data[wr_addr[3:0]*8+:8] <= wr_data;
        if(wr_addr[3:0] == 4'hf) wr_valid <= 0;
    end
end

endmodule
