`include "defines.v"

module pe(
    input clk,
    input rst,
    input stall,

    input cfg,
    input[3:0] shift,
    input[15:0] coefs,

    input[31:0] data_in,
    input[46:0] accum,      //32 high and 15 low
    output reg[46:0] data_out
);

reg[3:0] move;
reg[15:0] factor;

wire[46:0] result;
assign result = {{15{data_in[31]}}, data_in} * {{31{factor[15]}}, factor};

always @(posedge clk or posedge rst)
begin
    if(rst)
    begin
        factor <= 0;
        move <= 0;
        data_out <= 0;
    end else
    begin
        if(cfg)
        begin
            factor <= coefs;
            move <= ~shift;
        end
        if(!stall)
        begin
            data_out <= accum + (result << move);
        end
    end
end

endmodule

`define FIFO_WR_IDLE 0
`define FIFO_WR_WRITE 1
`define FIFO_WR_WAIT 2

`define FIFO_RD_IDLE 0
`define FIFO_RD_NEXT 1
`define FIFO_RD_READ 2
`define FIFO_RD_TAIL 3

module fifo(
    input clk,
    input rst,
    
    input cfg,
    input[31:0] cfg_addr,

    input en,

    input rd,
    output reg rd_valid,
    output reg[16:0] rd_data,

    output reg tcm_read_request,
    input tcm_request_finish,
    output reg[31:0] tcm_addr, //low 4 bits support reordering, but should not used right now.
    input[127:0] tcm_read_data
);

reg mem_wr;
reg mem_rd;

reg[127:0] mem_wr_data;
wire[127:0] mem_rd_data;

reg[3:0] mem_wr_addr;
reg[3:0] mem_rd_addr;
reg[2:0] mem_rd_subaddr; //8 samples in one cache line

reg[15:0] mem_commit_set;
reg[15:0] mem_commit_reset;
reg[15:0] mem_commit;

reg[15:0] mem_sample;
always @(*)
begin
    case(mem_rd_subaddr)
    0: mem_sample <= mem_rd_data[15:0];
    1: mem_sample <= mem_rd_data[31:16];
    2: mem_sample <= mem_rd_data[47:32];
    3: mem_sample <= mem_rd_data[63:48];
    4: mem_sample <= mem_rd_data[79:64];
    5: mem_sample <= mem_rd_data[95:80];
    6: mem_sample <= mem_rd_data[111:96];
    7: mem_sample <= mem_rd_data[127:112];
    endcase
end

wire mem_tail;
assign mem_tail = mem_sample == 16'hffff;

integer i;
always @(posedge clk or posedge rst)
begin
    if(rst)
        mem_commit <= 0;
    else
    begin
        if(cfg)
            mem_commit <= 0;
        else
        for(i = 0; i < 16; i = i + 1)
        begin
            case({mem_commit_set[i], mem_commit_reset[i]})
            2'b01:  mem_commit[i] <= 0;
            2'b10:  mem_commit[i] <= 1;
            default:
                    mem_commit[i] <= mem_commit[i];
            endcase
        end
    end
end

//dual port reg file
`ifdef TARGET_FPGA
//1 blocks * 16 words * 128 bits
fifo_mem data(
    .clk(!clk),
    .we(mem_wr),
    .a(mem_wr_addr),
    .d(mem_wr_data),
    .dpra(mem_rd_addr),
    .qdpo_ce(mem_rd),
    .qdpo(mem_rd_data)
);

`else
//4 blocks * 16 words * 32 bits
//seperate for better floorplanning
fifo_mem data0(
    .CLKA(!clk),
    .CLKB(!clk),
    .CENA(~mem_rd),
    .CENB(~mem_wr),
    .AA(mem_rd_addr),
    .QA(mem_rd_data[31:0]),
    .AB(mem_wr_addr),
    .DB(mem_wr_data[31:0])
);

fifo_mem data1(
    .CLKA(!clk),
    .CLKB(!clk),
    .CENA(~mem_rd),
    .CENB(~mem_wr),
    .AA(mem_rd_addr),
    .QA(mem_rd_data[63:32]),
    .AB(mem_wr_addr),
    .DB(mem_wr_data[63:32])
);

fifo_mem data2(
    .CLKA(!clk),
    .CLKB(!clk),
    .CENA(~mem_rd),
    .CENB(~mem_wr),
    .AA(mem_rd_addr),
    .QA(mem_rd_data[95:64]),
    .AB(mem_wr_addr),
    .DB(mem_wr_data[95:64])
);

fifo_mem data3(
    .CLKA(!clk),
    .CLKB(!clk),
    .CENA(~mem_rd),
    .CENB(~mem_wr),
    .AA(mem_rd_addr),
    .QA(mem_rd_data[127:96]),
    .AB(mem_wr_addr),
    .DB(mem_wr_data[127:96])
);
`endif

reg[1:0] wr_fsm;
reg[1:0] rd_fsm;

always @(posedge clk or posedge rst)
begin
    if(rst)
    begin
        wr_fsm <= `FIFO_WR_IDLE;
        mem_wr <= 0;
        mem_wr_addr <= 0;
        mem_wr_data <= 0;
        mem_commit_set <= 0;
        tcm_read_request <= 0;
        tcm_addr <= 0;
    end else
    begin
        if(cfg)
        begin
            wr_fsm <= `FIFO_WR_IDLE;
            mem_wr <= 0;
            mem_wr_addr <= 0;
            mem_wr_data <= 0;
            mem_commit_set <= 0;
            tcm_read_request <= 0;
            tcm_addr <= cfg_addr;
        end else
        begin
            case(wr_fsm)
            `FIFO_WR_IDLE:
            begin
                if(mem_commit[mem_wr_addr] == 0 && en)
                begin
                    tcm_read_request <= 1;
                    wr_fsm <= `FIFO_WR_WRITE;
                end
            end
            `FIFO_WR_WRITE:
            if(tcm_request_finish)
            begin
                tcm_read_request <= 0;
                tcm_addr <= tcm_addr + 16;
                wr_fsm <= `FIFO_WR_WAIT;
                mem_wr <= 1;
                mem_wr_data <= tcm_read_data;
                mem_commit_set[mem_wr_addr] <= 1;
            end
            `FIFO_WR_WAIT:
            begin
                wr_fsm <= `FIFO_WR_IDLE;
                mem_wr <= 0;
                mem_wr_addr <= mem_wr_addr + 1;
                mem_commit_set <= 0;
            end
            endcase
        end
    end
end

always @(posedge clk or posedge rst)
begin
    if(rst)
    begin
        rd_fsm <= `FIFO_RD_IDLE;
        mem_rd <= 0;
        mem_rd_addr <= 0;
        mem_rd_subaddr <= 0;
        mem_commit_reset <= 0;
        rd_valid <= 0;
        rd_data <= 0;
    end else
    begin
        if(cfg)
        begin
            rd_fsm <= `FIFO_RD_IDLE;
            mem_rd <= 0;
            mem_rd_addr <= 0;
            mem_rd_subaddr <= 0;
            mem_commit_reset <= 0;
            rd_valid <= 0;
            rd_data <= 0;
        end else
        begin
            case(rd_fsm)
            `FIFO_RD_IDLE:
            begin
                rd_valid <= 0;
                mem_commit_reset <= 0;
                if(mem_commit[mem_rd_addr] != 0)
                begin
                    mem_rd <= 1;
                    rd_fsm <= `FIFO_RD_READ;
                end
            end
            `FIFO_RD_NEXT:
            begin
                rd_valid <= 0;
                mem_commit_reset <= 0;
                if(mem_commit[mem_rd_addr] != 0)
                begin
                    mem_rd <= 1;
                    rd_fsm <= `FIFO_RD_TAIL;
                end
            end
            `FIFO_RD_READ:
            begin
                mem_rd <= 0;
                rd_valid <= !mem_tail;
                rd_data <= {mem_sample[15], mem_sample};
                if(rd)
                begin
                    mem_rd_subaddr <= mem_rd_subaddr + 1;
                    if(mem_rd_subaddr == 7)
                    begin
                        mem_commit_reset[mem_rd_addr] <= 1;
                        mem_rd_addr <= mem_rd_addr + 1;
                        rd_fsm <= mem_tail ? `FIFO_RD_NEXT : `FIFO_RD_IDLE;
                    end else
                    begin
                        rd_fsm <= mem_tail ? `FIFO_RD_TAIL : `FIFO_RD_READ;
                    end
                end
            end
            `FIFO_RD_TAIL:
            begin
                mem_rd <= 0;
                rd_valid <= 1;
                rd_data <= {mem_tail ? 1'b1 : ~mem_sample[15], mem_sample};
                if(rd)
                begin
                    mem_rd_subaddr <= mem_rd_subaddr + 1;
                    if(mem_rd_subaddr == 7)
                    begin
                        mem_commit_reset[mem_rd_addr] <= 1;
                        mem_rd_addr <= mem_rd_addr + 1;
                        rd_fsm <= `FIFO_RD_IDLE;
                    end else
                    begin
                        rd_fsm <= `FIFO_RD_READ;
                    end
                end
            end
            endcase
        end
    end
end

endmodule

module buffer(
    input clk,
    input rst,

    input chan,
    input[1:0] chansgn,
    input[15:0] blocksize,

    input chan_flip,
    input wr_flip,
    output wr_valid,
    input wr,
    input[16:0] buf_wr_data,
    
    input rd,
    output rd_valid,
    output[1:0] rd_chansgn,
    output[16:0] rd_data_chan0,
    output[16:0] rd_data_chan1
);

reg rd_sel, wr_sel;
reg[1:0] buf_commit;
reg[1:0] buf_chansgn[1:0];
reg[15:0] buf_size[1:0];
assign rd_valid = buf_commit[rd_sel];
assign wr_valid = !buf_commit[wr_sel];

wire rd0, rd1, wr0, wr1;
assign rd0 = rd ? !rd_sel : 0;
assign rd1 = rd ? rd_sel : 0;
assign wr0 = wr ? !wr_sel : 0;
assign wr1 = wr ? wr_sel : 0;

reg[12:0] rd_addr, wr_addr;
wire[12:0] addr0, addr1;
assign addr0 = rd0 ? rd_addr : wr_addr;
assign addr1 = rd1 ? rd_addr : wr_addr;

wire rd_flip;
assign rd_flip = rd && (rd_addr == buf_size[rd_sel]);

always @(posedge clk or posedge rst)
begin
    if(rst)
    begin
        rd_sel <= 0;
        wr_sel <= 0;
        buf_commit <= 0;
    end else
    begin
        if(rd_flip)
        begin
            rd_sel <= ~rd_sel;
            buf_commit[rd_sel] <= 0;
        end
        if(wr_flip)
        begin
            wr_sel <= ~wr_sel;
            buf_commit[wr_sel] <= 1;
        end
    end
end

wire[1:0] wr_mask;
wire[33:0] wr_data, rd_data;
assign wr_mask = {!chan, chan};
assign wr_data = {buf_wr_data, buf_wr_data};

wire[1:0] wen0, wen1;
wire cen0, cen1;
assign wen0 = !wr ? 0 : (wr_sel ? 0 : wr_mask);
assign wen1 = !wr ? 0 : (wr_sel ? wr_mask : 0);
assign cen0 = rd0 || wr0;
assign cen1 = rd1 || wr1;

always @(posedge clk or posedge rst)
begin
    if(rst)
    begin
        rd_addr <= 0;
        wr_addr <= 0;
    end else
    begin
        if(rd_flip) rd_addr <= 0; else
        if(rd) rd_addr <= rd_addr + 1;
        if(wr_flip || chan_flip) wr_addr <= 0; else
        if(wr) wr_addr <= wr_addr + 1;
    end
end

always @(posedge clk or posedge rst)
begin
    if(rst)
    begin
        buf_chansgn[0] <= 0; buf_chansgn[1] <= 0;
        buf_size[0] <= 0; buf_size[1] <= 0;
    end else
    if(wr)
    begin
        buf_size[wr_sel] <= blocksize - 1;
        buf_chansgn[wr_sel] <= chansgn;
    end
end

wire[33:0] rd_data0, rd_data1;
assign rd_data = rd_sel ? rd_data1 : rd_data0;
assign rd_chansgn = buf_chansgn[rd_sel];
assign rd_data_chan0 = rd_data[33:17];
assign rd_data_chan1 = rd_data[16:0];

//single port sram
//38.25kBytes
`ifdef TARGET_FPGA
//4 blocks * 4608 words * 17bits
buf_mem mem0_0(
    .clka(!clk),
    .ena(cen0),
    .wea(wen0[0]),
    .addra(addr0),
    .dina(wr_data[16:0]),
    .douta(rd_data0[16:0])
);

buf_mem mem0_1(
    .clka(!clk),
    .ena(cen0),
    .wea(wen0[1]),
    .addra(addr0),
    .dina(wr_data[33:17]),
    .douta(rd_data0[33:17])
);

buf_mem mem1_0(
    .clka(!clk),
    .ena(cen1),
    .wea(wen1[0]),
    .addra(addr1),
    .dina(wr_data[16:0]),
    .douta(rd_data1[16:0])
);

buf_mem mem1_1(
    .clka(!clk),
    .ena(cen1),
    .wea(wen1[1]),
    .addra(addr1),
    .dina(wr_data[33:17]),
    .douta(rd_data1[33:17])
);

`else
//2 blocks * 4608 words * 34bits
buf_mem mem0(
    .CLK(!clk),
    .CEN(!cen0),
    .WEN(~wen0),
    .A(addr0),
    .D(wr_data),
    .Q(rd_data0),
    .OEN(rd_sel)
);

buf_mem mem1(
    .CLK(!clk),
    .CEN(!cen1),
    .WEN(~wen1),
    .A(addr1),
    .D(wr_data),
    .Q(rd_data1),
    .OEN(!rd_sel)
);
`endif

endmodule

module warm_mem(
    input CLK,
    input CEN,
    input WEN,
    input[3:0] A,
    input[16:0] D,
    output reg[16:0] Q
);

reg[16:0] mem[15:0];
always @(posedge CLK)
begin
    if(!CEN)
    begin
        if(!WEN) mem[A] = D;
        Q = mem[A];
    end else
    begin
        //Q = 0;
    end
end
endmodule

`define CONST_ISSUE 0
`define VERBA_ISSUE 1
`define LPC_ISSUE   2
`define BLOCKSIZE   3
`define CHANSGN     4
`define LPC_SFT     5
`define LPC_ORD     6
`define LPC_COE     7
`define LPC_WARM    8
`define WASTED      9
`define PHY_STATUS  10

`define TYPE_NONE   0
`define TYPE_CONST  1
`define TYPE_VBT    2
`define TYPE_LPC    3

`define FSM_IDLE    0
`define FSM_CONST   1
`define FSM_FIN     2
`define FSM_CFG     3
`define FSM_VBT     4
`define FSM_WARM    5
`define FSM_LPC     6

module lpc(
    input clk,
    input rst,
    
    input evb_cmd_request,
    input[3:0] evb_cmd_addr,
    input[1:0] evb_cmd_wr_mask,
    input[31:0] evb_cmd_wr_data,
    output reg evb_cmd_finish,
    output reg[31:0] evb_cmd_rd_data,
    
    output tcm_read_request,
    input tcm_request_finish,
    output[31:0] tcm_addr,
    input[127:0] tcm_read_data,
    
    output phy_rd_valid,
    input phy_rd,
    output[1:0] phy_rd_chansgn,
    output[16:0] phy_rd_data_chan0,
    output[16:0] phy_rd_data_chan1,
    
    output busy
);

//global args
reg chan; //channel number
reg[15:0] blocksize;
reg[1:0] chansgn;
reg[3:0] wasted;
reg[4:0] orders_minus1;
reg[31:0] res_addr;
reg[16:0] const_data; //const data

reg[11:0] orders_onehot;
reg[11:0] orders_reverse;
always @(*)
begin
    case(orders_minus1)
     0: begin orders_onehot <= 12'h001; orders_reverse <= 12'h000; end
     1: begin orders_onehot <= 12'h002; orders_reverse <= 12'h001; end
     2: begin orders_onehot <= 12'h004; orders_reverse <= 12'h003; end
     3: begin orders_onehot <= 12'h008; orders_reverse <= 12'h007; end
     4: begin orders_onehot <= 12'h010; orders_reverse <= 12'h00f; end
     5: begin orders_onehot <= 12'h020; orders_reverse <= 12'h01f; end
     6: begin orders_onehot <= 12'h040; orders_reverse <= 12'h07f; end
     7: begin orders_onehot <= 12'h080; orders_reverse <= 12'h0ff; end
     8: begin orders_onehot <= 12'h100; orders_reverse <= 12'h1ff; end
     9: begin orders_onehot <= 12'h200; orders_reverse <= 12'h3ff; end
    10: begin orders_onehot <= 12'h400; orders_reverse <= 12'h7ff; end
    11: begin orders_onehot <= 12'h800; orders_reverse <= 12'hfff; end
    default:
        begin orders_onehot <= 12'hx; orders_reverse <= 12'hx; end
    endcase
end

//state
reg[1:0] type; //cmd type
reg[11:0] res_inj;
reg[11:0] res_mask;

//pe config
reg[3:0] shift;
reg[11:0] cfg;
reg[15:0] coefs;

//internal wires
wire[31:0] data_in;
wire[46:0] data_out[12:0];

//fsm controll
wire stall;
reg busy;

//warmup data
reg warmup_sel; //rd addr increment
reg warmup_reset;
reg[3:0] warmup_addr; //up to 12 warmups
wire[16:0] warmup_data;
reg warmup_wr; //wr
reg[3:0] warmup_wr_addr;
reg[16:0] warmup_wr_data; //wr_data

wire fifo_rd;
reg fifo_en, fifo_cfg;
wire fifo_valid;
wire[16:0] fifo_rd_data;

reg[15:0] count;
reg buf_commit_set;
wire buf_wr_valid;

reg buf_wr;
reg[16:0] buf_wr_data;
reg chan_flip;

reg[16:0] result;
assign data_in = warmup_sel ? {{15{warmup_data[16]}}, warmup_data} : data_out[0][46:15];
always @(*)
begin
    case(type)
    `TYPE_CONST: result <= const_data << wasted;
    `TYPE_VBT:   result <= fifo_rd_data << wasted;
    `TYPE_LPC:   result <= data_in[16:0] << wasted;
    default:     result <= 17'hx;
    endcase
end

//pe array
reg[12:0] pe_en;
wire[11:0] pe_en_in;
generate
genvar i;
    for(i = 0; i < 12; i = i + 1)
    begin : pe_array
        pe pe(
            .clk(clk),
            .rst(rst),
            .stall(stall),

            .cfg(cfg[i]),
            .shift(shift),
            .coefs(coefs),

            .data_in(pe_en_in[i] ? data_in : 32'h0),
            .accum(res_inj[i] ? {{15{fifo_rd_data[16]}}, fifo_rd_data, 15'h0} : (i == 11 ? 47'h0 : data_out[i + 1])), //32 high and 15 low
            .data_out(data_out[i])
        );
        assign pe_en_in[i] = res_mask[i] ^ (i == 11 ? 0 : pe_en[i + 1]);
        always @(posedge clk or posedge rst)
        begin
            if(rst) pe_en[i] <= 0;
            else pe_en[i] <= pe_en_in[i];
        end
    end
endgenerate

fifo fifo(
    .clk(clk),
    .rst(rst),

    .cfg(fifo_cfg),
    .cfg_addr(res_addr),

    .en(fifo_en),

    .rd(fifo_rd),
    .rd_valid(fifo_valid),
    .rd_data(fifo_rd_data),

    .tcm_read_request(tcm_read_request),
    .tcm_request_finish(tcm_request_finish),
    .tcm_addr(tcm_addr), //low 4 bits support reordering, but should not used right now.
    .tcm_read_data(tcm_read_data)
);

warm_mem warm_mem(
   .Q(warmup_data),
   .CLK(clk),
   .CEN(!((warmup_sel && !stall) || warmup_wr)),
   .WEN(!warmup_wr),
   .A(warmup_wr ? warmup_wr_addr : warmup_addr),
   .D(warmup_wr_data)
);

always @(posedge clk or posedge rst)
begin
    if(rst) warmup_addr <= 0;
    else
    if(warmup_reset) warmup_addr <= 0;
    else
    if(warmup_sel && !stall) warmup_addr <= warmup_addr + 1;    
end

reg done;

wire evb_cmd_wr;
assign evb_cmd_wr = evb_cmd_wr_mask[1] || evb_cmd_wr_mask[0];

reg[31:0] reg_data;
always @(*)
begin
    case(evb_cmd_addr)
    `CONST_ISSUE: reg_data <= {15'h0, const_data};
    `VERBA_ISSUE: reg_data <= res_addr;
    `LPC_ISSUE: reg_data <= res_addr;
    `BLOCKSIZE: reg_data <= {16'h0, blocksize};
    `CHANSGN: reg_data <= {30'h0, chan};
    `LPC_SFT: reg_data <= {28'h0, shift};
    `LPC_ORD: reg_data <= {28'h0, orders_minus1};
    `WASTED: reg_data <= {28'h0, wasted};
    `PHY_STATUS: reg_data <= {31'h0, busy};
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

reg reset;

always @(posedge clk or posedge rst)
begin
    if(rst)
    begin
        reset <= 0;
        evb_cmd_finish <= 0;
        busy <= 0;
        type <= `TYPE_NONE;
        
        orders_minus1 <= 0;
        blocksize <= 0;
        res_addr <= 0;
        const_data <= 0;
        chansgn <= 0;
        shift <= 0;
    end else
    if(reset)
    begin
        reset <= 0;
        evb_cmd_finish <= 0;
        busy <= 0;
        type <= `TYPE_NONE;
        
        orders_minus1 <= 0;
        blocksize <= 0;
        res_addr <= 0;
        const_data <= 0;
        chansgn <= 0;
        wasted <= 0;
        shift <= 0;
    end else
    if(evb_cmd_finish) evb_cmd_finish <= 0;
    else
    begin
        if(evb_cmd_request && evb_cmd_addr == `PHY_STATUS)
        begin
            evb_cmd_finish <= 1;
            reset <= cmd[1];
            evb_cmd_rd_data <= {31'h0, busy};
        end else
        begin
            reset <= 0;
        end
        if(busy)
        begin
            if(done) begin busy <= 0; end
        end else
        if(evb_cmd_request)
        begin
            evb_cmd_finish <= 1;
            case(evb_cmd_addr)
            `CONST_ISSUE:
            begin
                if(evb_cmd_wr)
                begin
                    busy <= 1;
                    type <= `TYPE_CONST;
                end
                const_data <= cmd;
                evb_cmd_rd_data <= const_data;
            end
            `VERBA_ISSUE:
            begin
                if(evb_cmd_wr)
                begin
                    busy <= 1;
                    type <= `TYPE_VBT;
                end
                res_addr <= cmd;
                evb_cmd_rd_data <= res_addr;
            end
            `LPC_ISSUE:
            begin
                if(evb_cmd_wr)
                begin
                    busy <= 1;
                    type <= `TYPE_LPC;
                end
                res_addr <= cmd;
                evb_cmd_rd_data <= res_addr;
            end
            `BLOCKSIZE:
            begin
                blocksize <= cmd;
                evb_cmd_rd_data <= blocksize;
            end
            `CHANSGN:
            begin
                chansgn <= cmd;
                evb_cmd_rd_data <= chansgn;
            end
            `LPC_SFT:
            begin
                shift <= cmd;
                evb_cmd_rd_data <= shift;
            end
            `LPC_ORD:
            begin
                orders_minus1 <= cmd;
                evb_cmd_rd_data <= orders_minus1;
            end
            `WASTED:
            begin
                wasted <= cmd;
                evb_cmd_rd_data <= wasted;
            end
            default:
            begin
                if(evb_cmd_addr == `LPC_COE)
                begin
                    cfg <= 1 << cmd[21:17];
                    coefs <= cmd[15:0];
                end else
                begin
                    cfg <= 0;
                    coefs <= 0;
                end
                if(evb_cmd_addr == `LPC_WARM)
                begin
                    warmup_wr <= 1;
                    warmup_wr_addr <= cmd[21:17];
                    warmup_wr_data <= cmd[16:0];
                end else
                begin
                    warmup_wr <= 0;
                    warmup_wr_addr <= 0;
                    warmup_wr_data <= 0;
                end
                evb_cmd_rd_data <= 0;
            end
            endcase
        end
    end
end

buffer phybuf(
    .clk(clk),
    .rst(rst),

    .chan(chan),
    .chansgn(chansgn),
    .blocksize(blocksize),
    
    .chan_flip(chan_flip),
    .wr_flip(buf_commit_set),
    .wr_valid(buf_wr_valid),
    .wr(buf_wr && !stall), //TODO
    .buf_wr_data(buf_wr_data),
    
    .rd(phy_rd),
    .rd_valid(phy_rd_valid),
    .rd_chansgn(phy_rd_chansgn),
    .rd_data_chan0(phy_rd_data_chan0),
    .rd_data_chan1(phy_rd_data_chan1)
);

assign stall = (fifo_en && !fifo_valid) || !buf_wr_valid;
assign fifo_rd = fifo_en && buf_wr_valid;

reg[2:0] fsm;
always @(posedge clk or posedge rst)
begin
    if(rst)
    begin
        fsm <= `FSM_IDLE;
        fifo_en <= 0;
        fifo_cfg <= 0;
        done <= 0;
        count <= 0;
        warmup_sel <= 0;
        warmup_reset <= 0;
        chan <= 0;
        chan_flip <= 0;
        buf_wr <= 0;
        buf_wr_data <= 0;
        res_inj <= 0;
        res_mask <= 0;
        buf_commit_set <= 0;
    end else
    begin
        if(reset || done)
        begin
            if(reset)
            begin
                chan <= 0;
                fsm <= `FSM_IDLE;
                fifo_cfg <= 0;
                count <= 0;
                warmup_sel <= 0;
                buf_wr <= 0;
                buf_wr_data <= 0;
                res_inj <= 0;
                res_mask <= 0;
                buf_commit_set <= 0;
            end
            chan_flip <= 0;
            fifo_en <= 0;
            done <= 0;
            warmup_reset <= 0;
            buf_commit_set <= 0;
        end else
        if(busy && !stall)
        begin
            case(fsm)
            `FSM_IDLE:
            begin
                fifo_en <= 0;
                if(buf_wr_valid)
                begin
                    if(type == `TYPE_CONST) fsm <= `FSM_CONST;
                    else if(type == `TYPE_LPC || type == `TYPE_VBT)
                    begin
                        fsm <= `FSM_CFG;
                        fifo_cfg <= 1;
                    end
                    if(type == `TYPE_LPC) warmup_sel <= 1;
                end
            end
            `FSM_CONST:
            begin
                count <= count + 1;
                buf_wr <= 1;
                buf_wr_data <= result;
                if(count == blocksize) 
                begin
                    chan_flip <= 1;
                    fsm <= `FSM_FIN;
                end
            end
            `FSM_CFG:
            begin
                fifo_cfg <= 0;
                fifo_en <= 1;
                if(type == `TYPE_LPC) fsm <= `FSM_WARM;
                else if(type == `TYPE_VBT) fsm <= `FSM_VBT;
                if(type == `TYPE_LPC)
                begin
                    res_inj <= orders_onehot;
                    res_mask <= orders_onehot;
                end
            end
            `FSM_VBT:
            begin
                count <= count + 1;
                buf_wr <= count != blocksize;
                buf_wr_data <= result;
                if(count == blocksize)
                begin
                    fifo_en <= 0;
                    chan_flip <= 1;
                    fsm <= `FSM_FIN;
                end
            end
            `FSM_WARM:
            begin
                count <= count + 1;
                buf_wr <= 1;
                buf_wr_data <= result;
                if(count == orders_minus1) //warmup down and en[0] up
                begin
                    warmup_sel <= 0;
                    fsm <= `FSM_LPC;
                end
            end
            `FSM_LPC:
            begin
                count <= count + 1;
                buf_wr <= count != blocksize;
                buf_wr_data <= result;
                if(count == blocksize) //warmup down and en[0] up
                begin
                    fifo_en <= 0;
                    res_inj <= 0;
                    res_mask <= orders_reverse;
                    chan_flip <= 1;
                    fsm <= `FSM_FIN;
                end
            end
            `FSM_FIN:
            begin
                count <= 0;
                chan <= !chan;
                chan_flip <= 0;
                buf_wr <= 0;
                buf_wr_data <= 0;
                res_mask <= 0;
                warmup_reset <= 1;
                if(chan)
                begin
                    buf_commit_set <= 1;
                end
                done <= 1;
                fsm <= `FSM_IDLE;
            end
            endcase
        end
    end
end

endmodule
