`include "defines.v"

/*
module mp_test(
    input clk,
    input stall,
    input[15:0] pc
);

always @(posedge clk)
begin
    if(!stall) begin
    if(pc == 16'h0) $display("call boot");
    if(pc == 16'hbc) $display("call vec");
    if(pc == 16'hdc) $display("call bitstream_readbits.part.0");
    if(pc == 16'h194) $display("call bitstream_init");
    if(pc == 16'h1e8) $display("call bitstream_prepare");
    if(pc == 16'h2fc) $display("call bitstream_readunary");
    if(pc == 16'h3a4) $display("call bitstream_readrice");
    if(pc == 16'h474) $display("call bitstream_align");
    if(pc == 16'h4c8) $display("call bitstream_alignread");
    if(pc == 16'h57c) $display("call write_residuals");
    if(pc == 16'h5dc) $display("call decode_residuals");
    if(pc == 16'h790) $display("call decodesubframe");
    if(pc == 16'hccc) $display("call decodeframe");
    if(pc == 16'hfc0) $display("call main");
    if(pc == 16'h790) $stop;
    end
end

endmodule
*/

module mp_rf(
    input clk,
    input rst,
    input[4:0] rs1,
    input[4:0] rs2,
    output[15:0] rs1_data,
    output[15:0] rs2_data,
    output[31:0] rs1_data_f,
    output[31:0] rs2_data_f,
    input wr,   //write partial 16bit reg
    input wr_f, //write full 32bit reg
    input[4:0] rd,
    input[31:0] rd_data
);

reg[31:0] rf[15:0];
//zero ra sp bp sa da ax bx
//r0 r1 r2 r3 r4 r5 r6 r7
assign rs1_data_f = rs1[4:1] == 0 ? 0 : rf[rs1[4:1]];
assign rs2_data_f = rs2[4:1] == 0 ? 0 : rf[rs2[4:1]];
assign rs1_data = rs1[0] ? rs1_data_f[31:16] : rs1_data_f[15:0];
assign rs2_data = rs2[0] ? rs2_data_f[31:16] : rs2_data_f[15:0];

integer i;

always @(posedge clk or posedge rst)
begin
    if(rst)
    begin
        for(i = 0; i < 16; i = i + 1) rf[i] <= 0;
    end else
    if(wr)
    begin
        if(wr_f)
        begin
            rf[rd[4:1]] <= rd_data;
        end else
        begin
            if(rd[0]) rf[rd[4:1]][31:16] <= rd_data[15:0];
            else rf[rd[4:1]][15:0] <= rd_data[15:0];
        end
    end
end
endmodule

module mp(
    input clk,
    input rst,
    input ready,
    
    //i cache port
    output mp_ip_rd,
    output[13:0] mp_ip_rd_addr,
    input[31:0] mp_ip_rd_data,

    //int port
    input irq,

    //ev bus port
    output evb_cmd_request,
    output[15:0] evb_cmd_addr, //15:4 device id, 3:0 sub id
    output[1:0] evb_cmd_wr_mask,
    output[31:0] evb_cmd_wr_data,
    input evb_cmd_finish,
    input[31:0] evb_cmd_rd_data,

    //tcm port
    input tcm_invalid,
    input[15:0] tcm_invalid_addr,
    output tcm_read_request, tcm_write_request,
    input tcm_request_finish,
    output[15:0] tcm_addr,
    input[127:0] tcm_read_data,
    output[127:0] tcm_write_data,
    
    output busy
);

//reset
reg irst; //internal reset
always @(negedge clk or posedge rst)
begin
    if(rst)
    begin
        irst <= 1;
    end else
    begin
        if(ready)
        begin
            irst <= 0;
        end else 
            irst <= 1;
    end
end

reg rd_init_set;
always @(posedge clk or posedge irst)
begin
    if(irst)
    begin
        rd_init_set <= 1;
    end else
    begin
        rd_init_set <= 0;
    end
end

//status
wire stall;
wire mu_stall, sr_stall; //memory unit, special register
reg wfi_stall; //for wait for interrupt stall
wire branch_stall; //for hazard when frontend branch use data from backend
wire addr_stall; //for hazard when frontend memory and special register addr generator use data from backend
assign stall = mu_stall || sr_stall || wfi_stall || branch_stall || addr_stall || rd_init_set;

wire[15:0] mvec; //interrupt vector
reg[15:0] mepc; //exception pc

assign busy = !stall;

//decoder
//refer to manual
wire[31:0] instru;
assign instru = rd_init_set ? 32'h0 : mp_ip_rd_data;

wire[2:0] opcode3;
wire[3:0] opcode4;
assign opcode3 = instru[2:0];
assign opcode4 = instru[3:0];
wire a, b, c, d;
assign a = opcode4[2];
assign b = opcode4[1];
assign c = opcode4[0];
assign d = opcode4[3];

wire[1:0] tag2;
wire[2:0] tag3;
assign tag2 = instru[31:30];
assign tag3 = {tag2, opcode4 == `FMT_I ? 1'b0 : instru[29]};

wire[2:0] func3;
assign func3 = instru[11:9];

wire[4:0] rd, rs1, rs2;
assign rd = instru[8:4];
assign rs1 = instru[16:12];
assign rs2 = instru[21:17];

wire[15:0] imm16; //16-bit immediate
assign imm16 = {a ? {3{instru[28]}} : instru[31:29],//3
            instru[28:22],                          //7
            b ? instru[21:17] : instru[8:4],        //5
            instru[29]};                            //1

wire signext;
assign signext = opcode3 == `FMT_jump ? rs1[4]:
                                    a ? instru[28] : instru[31];

wire[15:0] imm32h; //immediate high extend
assign imm32h = opcode4 == `FMT_LRA ? {12'h0, rs1[3:0]} :
    {opcode4 == `FMT_J ? {6{rs2[4]}} : {6{signext}},    //6
     opcode4 == `FMT_J ? rs2 : {5{signext}},            //5
     opcode3 == `FMT_jump ? rs1 : {5{signext}}};        //5

wire[31:0] imm32; //32-bit immediate
assign imm32 = {imm32h, imm16};

wire[15:0] imm;
assign imm = imm16;

//register file
wire[31:0] rs1_data_f, rs2_data_f;
wire[15:0] rs1_data, rs2_data;

reg rf_wr, rf_wr_f;
reg[4:0] rf_rd;
reg[31:0] rf_rd_data;

mp_rf rf(
    .clk(clk),
    .rst(irst),
    .rs1(rs1),
    .rs2(rs2),
    .rs1_data_f(rs1_data_f),
    .rs2_data_f(rs2_data_f),
    .rs1_data(rs1_data),
    .rs2_data(rs2_data),
    .wr(rf_wr),
    .wr_f(rf_wr_f),
    .rd(rf_rd),
    .rd_data(rf_rd_data)
);

wire wfi_en;
assign wfi_en = opcode4 == `FMT_HT && func3 == `FUNC_USR && tag3 == `TAG_WFI;

reg[15:0] pc;
wire[15:0] pc_plus4;
wire[15:0] pc_nxt;

wire pc_link;
wire[4:0] pc_link_rd;

always @(posedge clk or posedge irst)
begin
    if(irst) pc <= 0; else
    if(!stall && !wfi_en) pc <= pc_nxt;
end

//branch unit
wire branch_en, unconditional;
assign branch_en = opcode3 == `FMT_jump;
assign unconditional = d;

reg irq_mask;
wire irq_clear;

branch bg(
    .en(branch_en),
    .uncon(unconditional),
    .func3(func3),
    
    .pc(pc),
    .imm(imm),
    .rs1(rs1), //Rd
    .rs2_data(rs2_data), //Rs
    
    .int(irq),
    .mvec(mvec),
    .mask(irq_mask),
    .clear(irq_clear),
    
    .link(pc_link),
    .link_rd(pc_link_rd),

    .pc_plus4(pc_plus4),
    .pc_nxt(pc_nxt)
);

reg branch_wr;
reg[4:0] branch_wr_rd;
reg[15:0] branch_wr_data;

always @(posedge clk or posedge irst)
begin
    if(irst) branch_wr <= 0;
    else
    if(!stall)
    begin
        branch_wr <= pc_link;
        branch_wr_rd <= pc_link_rd;
        branch_wr_data <= pc_plus4;
    end
end

//interrupt and reset logic

assign mp_ip_rd = rd_init_set || !stall;
assign mp_ip_rd_addr = stall ? pc[15:2] : pc_nxt[15:2];

always @(posedge clk or posedge irst)
begin
    if(irst)
    begin
        irq_mask <= 1;
        mepc <= 0;
    end else
    if(!stall)
    begin
        if(irq && !irq_mask) mepc <= pc_plus4;
        if(irq_clear) irq_mask <= 0;
        else
        if(irq) irq_mask <= 1;
        else
        if(wfi_en) irq_mask <= 0;
    end
end

//hint
always @(posedge clk or posedge irst)
begin
    if(irst) wfi_stall <= 0;
    else
    if(irq) wfi_stall <= 0; else
    if(wfi_en && !stall) wfi_stall <= 1;
end

//alu
wire alu_en;
wire ari, lgc, sft, bit, cmv, lea;
assign alu_en = opcode3 == `FMT_arith && !stall;
assign ari = func3 == `FUNC_AU;
assign lgc = func3 == `FUNC_LU;
assign sft = func3 == `FUNC_SU;
assign bit = func3 == `FUNC_BIT;
assign cmv = func3 == `FUNC_CMOV;
assign lea = func3 == `FUNC_LEA;

wire[15:0] arith_data_in1, arith_data_in2;
assign arith_data_in1 = rs1_data;
assign arith_data_in2 = opcode4 == `FMT_I ? imm : rs2_data;

wire arith_wr, arith_wr_f;
wire[31:0] arith_data_out;

reg arith_fwd_en1, arith_fwd_en2;
reg[15:0] arith_fwd_data1, arith_fwd_data2;

arith alu(
    .clk(clk),
    .rst(irst),
    .en(alu_en),

    .ari(ari),
    .lgc(lgc),
    .sft(sft),
    .bit(bit),
    .cmv(cmv),
    .lea(lea),

    .tag3(tag3),

    .data_in1(arith_data_in1),
    .data_in2(arith_data_in2),

    .fwd_en1(arith_fwd_en1),
    .fwd_en2(arith_fwd_en2),
    .fwd_data1(arith_fwd_data1),
    .fwd_data2(arith_fwd_data2),

    .data_out_wr(arith_wr),
    .data_out_wr_f(arith_wr_f),
    .data_out(arith_data_out)
);

//load store
wire mem_en;
wire loadstore;
wire flush;
wire zero;
assign mem_en = opcode4 == `FMT_LS;
assign loadstore = func3[0];
assign flush = func3 == `FUNC_FSH;
assign zero = func3 == `FUNC_ZERO;

wire[31:0] mem_data_in;
assign mem_data_in = rs1_data_f;
wire[15:0] mem_addr_in;
assign mem_addr_in = rs2_data + imm;

wire loadstore_wr, loadstore_wr_f;
wire[31:0] loadstore_data_out;

reg[1:0] mem_fwd_en;
reg[31:0] mem_fwd_data;

dcache mu(
    .clk(clk),
    .rst(irst),

    .en(mem_en && !stall),
    .loadstore(loadstore),
    .flush(flush),
    .zero(zero),
    .tag2(tag2),

    .mem_addr_in(mem_addr_in),

    .mem_data_fwd(mem_fwd_en),
    .mem_data_fwd_data(mem_fwd_data),

    .mem_data_in_sel(rs1[0]),
    .mem_data_in(mem_data_in),
    
    .mem_data_wr(loadstore_wr),
    .mem_data_wr_f(loadstore_wr_f),
    .mem_data_out(loadstore_data_out),

    .stall(mu_stall),
    
    .tcm_invalid(tcm_invalid),
    .tcm_invalid_addr(tcm_invalid_addr),
    .tcm_read_request(tcm_read_request), .tcm_write_request(tcm_write_request),
    .tcm_request_finish(tcm_request_finish),
    .tcm_addr(tcm_addr),
    .tcm_read_data(tcm_read_data),
    .tcm_write_data(tcm_write_data)
);

//sr
wire sr_en;
assign sr_en = opcode4 == `FMT_SR;

wire[15:0] ev_addr;
assign ev_addr = rs2_data + imm;

wire ev_data_wr;
wire ev_data_wr_f;
wire[31:0] ev_data_out;

ev ev(
    .clk(clk),
    .rst(irst),

    .en(sr_en && !stall),
    .func3(func3),
    .tag2(tag2),
    
    .ev_addr(ev_addr),
    .ev_data_in_sel(rs1[0]),
    .ev_data(rs1_data_f),

    .ev_data_fwd(mem_fwd_en),
    .ev_data_fwd_data(mem_fwd_data),
    
    .mvec(mvec), //output
    .mepc(mepc), //input
    
    .stall(sr_stall),
    
    .ev_data_wr(ev_data_wr),
    .ev_data_wr_f(ev_data_wr_f),
    .ev_data_out(ev_data_out),

    .evb_cmd_request(evb_cmd_request),
    .evb_cmd_addr(evb_cmd_addr),
    .evb_cmd_wr_mask(evb_cmd_wr_mask),
    .evb_cmd_wr_data(evb_cmd_wr_data),
    .evb_cmd_finish(evb_cmd_finish),
    .evb_cmd_rd_data(evb_cmd_rd_data)
);

//lra
reg lra_wr;
reg[15:0] lra_data_in1, lra_data_in2;

wire lra_en;
assign lra_en = opcode4 == `FMT_LRA && !stall;
always @(posedge clk or posedge irst)
begin
    if(irst) lra_wr <= 0;
    else
        if(lra_en)
        begin
            lra_wr <= 1;
            case(func3)
            `FUNC_LRA_PC: lra_data_in1 <= pc;  
            `FUNC_LRA_ZERO: lra_data_in1 <= 0;
            default: lra_data_in1 <= 16'hx;
            endcase
            lra_data_in2 <= {imm[15:1], 1'b0};
        end else lra_wr <= 0;
end

wire[15:0] lra_data_out;
assign lra_data_out = lra_data_in1 + (lra_data_in2 << 11);

//fabric
reg[4:0] wb_rd;
always @(posedge clk or posedge irst)
begin
    if(irst) wb_rd <= 0;
    else
    if(!stall)
    begin
        if(opcode3 == `FMT_bus) wb_rd <= rs1;
        else wb_rd <= rd;
    end
end

always @(*)
begin
    rf_rd <= branch_wr ? branch_wr_rd : wb_rd;
    case({branch_wr, arith_wr, loadstore_wr, ev_data_wr, lra_wr})
    5'b10000:
    begin
        rf_wr <= 1;
        rf_wr_f <= 0;
        rf_rd_data <= branch_wr_data;
    end
    5'b01000:
    begin
        rf_wr <= 1;
        rf_wr_f <= arith_wr_f;
        rf_rd_data <= arith_data_out;
    end
    5'b00100:
    begin
        rf_wr <= 1;
        rf_wr_f <= loadstore_wr_f;
        rf_rd_data <= loadstore_data_out;
    end
    5'b00010:
    begin
        rf_wr <= 1;
        rf_wr_f <= ev_data_wr_f;
        rf_rd_data <= ev_data_out;
    end
    5'b00001:
    begin
        rf_wr <= 1;
        rf_wr_f <= 0;
        rf_rd_data <= lra_data_out;
    end
    5'b00000:
    begin
        rf_wr <= 0;
        rf_wr_f <= 0;
        rf_rd_data <= 0;
    end
    default:
    begin
        rf_wr <= 1'bx;
        rf_wr_f <= 1'bx;
        rf_rd_data <= 32'bx;
    end
    endcase
end

//data forwarding logic
wire pre_fwd1, pre_fwd2;
assign pre_fwd1 = rs1[4:1] == 0 ? 1'b0 : (rf_rd[4:1] == rs1[4:1] ? rf_wr : 0);
assign pre_fwd2 = rs2[4:1] == 0 ? 1'b0 : (rf_rd[4:1] == rs2[4:1] ? rf_wr : 0);

assign branch_stall = !branch_en ? 0 : pre_fwd2 ? (rf_wr_f ? 1 : rf_rd[0] == rs2[0]) : 0;
assign addr_stall = (!mem_en && !sr_en) ? 0 : pre_fwd2 ? (rf_wr_f ? 1 : rf_rd[0] == rs2[0]) : 0;

always @(posedge clk or posedge irst)
begin
    if(irst)
    begin
        arith_fwd_en1 <= 0;
        arith_fwd_en2 <= 0;
        mem_fwd_en <= 0;
    end else
    if(!stall)
    if(rf_wr_f)
    begin
        arith_fwd_en1 <= pre_fwd1 ? 1 : 0;
        arith_fwd_en2 <= pre_fwd2 && opcode4 != `FMT_I ? 1 : 0;
        arith_fwd_data1 <= rs1[0] ? rf_rd_data[31:16] : rf_rd_data[15:0];
        arith_fwd_data2 <= rs2[0] ? rf_rd_data[31:16] : rf_rd_data[15:0];
        mem_fwd_en <= pre_fwd1 ? 2'b11 : 0;
        mem_fwd_data <= rf_rd_data;
    end else
    begin
        arith_fwd_en1 <= pre_fwd1 ? rf_rd[0] == rs1[0] : 0;
        arith_fwd_en2 <= pre_fwd2 && opcode4 != `FMT_I ? rf_rd[0] == rs2[0] : 0;
        arith_fwd_data1 <= rf_rd_data[15:0];
        arith_fwd_data2 <= rf_rd_data[15:0];
        mem_fwd_en <= pre_fwd1 ? {rf_rd[0], !rf_rd[0]} : 0;
        mem_fwd_data <= {rf_rd_data[15:0], rf_rd_data[15:0]};
    end
end

always @(posedge clk)
begin
    if(arith_wr && !stall)
    begin
        //$display("debug: arith write back %x at %x", arith_data_out, rf_rd);
    end
end

/*
mp_test test(
    .clk(clk),
    .stall(stall),
    .pc(pc)
);*/

endmodule
