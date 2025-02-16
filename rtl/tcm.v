`include "defines.v"

//address aligned to 16bytes

//8Kbytes Code
//46Kbytes Data

//0x0000 - 0x0fff disk //4Kbytes
//0x1000 - 0x57ff lpc residual0 //18Kbytes
//0x5800 - 0x9fff lpc residual1 //18Kbytes
//0xa000 - 0xafff stack //4Kbytes
//0xb000 - 0xb7ff global //2Kbytes

/*
//for testing
module insn_mem(
    input CLKA,
    input CLKB,
    input CENA,
    input CENB,
    input[11:0] AA,
    output[127:0] QA,
    input[11:0] AB,
    input[127:0] DB
);

reg[127:0] mem[511:0];
integer fd;
initial
begin
    fd = $fopen("test_instructions.bin","rb");
    $fread(mem, fd);
end

reg[11:0] addr;
initial addr = 0;

wire[127:0] QA_BE;
assign QA_BE = mem[addr];
assign QA = {QA_BE[7:0], QA_BE[15:8], QA_BE[23:16], QA_BE[31:24],
             QA_BE[39:32], QA_BE[47:40], QA_BE[55:48], QA_BE[63:56],
             QA_BE[71:64], QA_BE[79:72], QA_BE[87:80], QA_BE[95:88],
             QA_BE[103:96], QA_BE[111:104], QA_BE[119:112], QA_BE[127:120]};
             
always @(posedge CLKA)
begin
    if(!CENA)
    begin
        addr <= AA;
    end
end
always @(posedge CLKB)
begin
    if(!CENB)
    begin
        mem[AB] <= DB;
    end
end
endmodule
`*/

module code_mem( //8kBytes = 128bit wide * 512 words
    input clk,
    input rst,
    input rd,
    input[13:0] rd_addr,
    output reg[31:0] rd_data,
    input wr,
    input[8:0] wr_addr,
    input[127:0] wr_data
);

reg prev_valid;
reg[11:0] prev_addr;
reg[1:0] rd_sel;

always @(posedge clk or posedge rst)
begin
    if(rst) prev_valid <= 0;
    else
    begin
        if(rd) prev_valid <= 1;
        if(rd) prev_addr <= rd_addr[13:2];
        if(rd) rd_sel <= rd_addr[1:0];
    end
end

wire gt_rd;
assign gt_rd = !prev_valid ? rd && !rst : rd && rd_addr[13:2] != prev_addr;

wire[127:0] long_rd_data;
always @(*)
begin
    case(rd_sel)
    0: rd_data <= long_rd_data[31:0];
    1: rd_data <= long_rd_data[63:32];
    2: rd_data <= long_rd_data[95:64];
    3: rd_data <= long_rd_data[127:96];
    endcase
end

`ifdef TARGET_FPGA
insn_mem mem(
    .clka(clk),
    .clkb(clk),
    .ena(wr),
    .enb(gt_rd),
    .wea(wr),
    .addra(wr_addr),
    .dina(wr_data),
    .addrb(rd_addr[13:2]), //expected.
    .doutb(long_rd_data)
);
`else
insn_mem mem(
    .CLKA(clk),
    .CLKB(clk),
    .CENA(~gt_rd),
    .CENB(~wr),
    .AA(rd_addr[13:2]), //expected.
    .QA(long_rd_data),
    .AB(wr_addr),
    .DB(wr_data)
);
`endif

endmodule

module tcm(
    input clk,
    input rst,
    
    input a_rd,
    input[13:0] a_rd_addr,
    output[31:0] a_rd_data,
    
    output reg b_tcm_invalid,
    output reg[15:0] b_tcm_invalid_addr,
    input b_tcm_read_request,
    input b_tcm_write_request,
    output reg b_tcm_request_finish,
    input[15:0] b_tcm_addr,
    output[127:0] b_tcm_read_data,
    input[127:0] b_tcm_write_data,
    
    input c_tcm_read_request,
    output reg c_tcm_request_finish,
    input[15:0] c_tcm_addr,
    output[127:0] c_tcm_read_data,

    input d_tcm_write_request,
    output reg d_tcm_request_finish,
    input[31:0] d_tcm_addr,
    input[127:0] d_tcm_write_data,
    
    input mclk,
    input ready,
    input init_wr,
    input[7:0] init_wr_data,
    
    input tcm_sdhci_test,
    input[31:0] tcm_sdhci_test_addr,
    
    input dump
);

reg code_wr;
reg[15:0] code_addr;
reg[127:0] code_data;
reg disk_wr;
reg[15:0] disk_addr;
reg[127:0] disk_data;

code_mem code(
    .clk(clk),
    .rst(rst),
    .rd(a_rd),
    .rd_addr(a_rd_addr), //13:0
    .rd_data(a_rd_data), //32b
    .wr(code_wr),
    .wr_addr(code_addr[10:2]), //8:0
    .wr_data(code_data) //128b
);

always @(posedge clk or posedge rst)
begin
    if(rst)
    begin
        d_tcm_request_finish <= 0;
        code_wr <= 0;
        code_addr <= 0;
        code_data <= 0;
        disk_wr <= 0;
        disk_addr <= 0;
        disk_data <= 0;
        b_tcm_invalid <= 0;
        b_tcm_invalid_addr <= 0;
    end else
    begin
        if(d_tcm_request_finish)
        begin
            d_tcm_request_finish <= 0;
            code_wr <= 0;
            code_addr <= 0;
            code_data <= 0;
            disk_wr <= 0;
            disk_addr <= 0;
            disk_data <= 0;
            b_tcm_invalid <= 0;
            b_tcm_invalid_addr <= 0;
        end else
        if(d_tcm_write_request)
        begin
            d_tcm_request_finish <= 1;
            if(d_tcm_addr[16])
            begin
                code_wr <= 1;
                code_addr <= d_tcm_addr[15:0];
                code_data <= d_tcm_write_data;
                disk_wr <= 0;
                disk_addr <= 0;
                disk_data <= 0;
                b_tcm_invalid <= 0;
                b_tcm_invalid_addr <= 0;
            end else
            begin
                code_wr <= 0;
                code_addr <= 0;
                code_data <= 0;
                disk_wr <= 1;
                disk_addr <= d_tcm_addr[15:0];
                disk_data <= d_tcm_write_data;
                b_tcm_invalid <= 1;
                b_tcm_invalid_addr <= d_tcm_addr[15:0];
            end
        end
    end
end

`define SEL_DATA 0
`define SEL_DISK 1

reg sel;
reg b_cen, b_wr;
wire[127:0] b_tcm_read_data_disk;
wire[127:0] b_tcm_read_data_data;
assign b_tcm_read_data = sel ==`SEL_DATA ? b_tcm_read_data_data : b_tcm_read_data_disk;

wire b_disk_cen, b_disk_wr;
assign b_disk_cen = sel == `SEL_DISK ? b_cen : 0;
assign b_disk_wr = sel == `SEL_DISK ? b_wr : 0;

wire b_data_cen, b_data_wr;
assign b_data_cen = sel == `SEL_DATA ? b_cen : 0;
assign b_data_wr = sel == `SEL_DATA ? b_wr : 0;

reg[15:0] b_disk_addr;
reg[15:0] b_data_addr;

wire lpc_rd;
assign lpc_rd = c_tcm_read_request && !c_tcm_request_finish;

wire[15:0] lpc_addr;
assign lpc_addr = {c_tcm_addr[15:12] - 1, c_tcm_addr[11:0]};

`ifdef TARGET_FPGA
disk_mem disk( //4Kbytes = 128b * 256
    .clka(clk),
    .ena(b_disk_cen),
    .wea(b_disk_wr),
    .addra(b_disk_addr[15:4]),
    .dina(b_tcm_write_data),
    .douta(b_tcm_read_data_disk),
    .clkb(clk),
    .enb(disk_wr),
    .web(disk_wr),
    .addrb(disk_addr[15:4]),
    .dinb(disk_data)
    //.doutb()
);

data_mem data( //42Kbytes
    .clka(clk),
    .ena(b_data_cen),
    .wea(b_data_wr),
    .addra(b_data_addr[15:4]),
    .dina(b_tcm_write_data),
    .douta(b_tcm_read_data_data),
    .clkb(clk),
    .enb(lpc_rd),
    .web(1'b0),
    .addrb(lpc_addr[15:4]),
    .dinb(128'h0),
    .doutb(c_tcm_read_data)
);
`else
disk_mem disk(
   .CLKA(clk),
   .CLKB(clk),
   .CENA(~b_disk_cen),
   .WENA(~b_disk_wr),
   .AA(b_disk_addr[15:4]),
   .DA(b_tcm_write_data),
   .QA(b_tcm_read_data_disk),
   .OENA(1'b0),
   .CENB(~disk_wr),
   .WENB(~disk_wr),
   .AB(disk_addr[15:4]),
   .DB(disk_data),
   .OENB(1'b1)
);

data_mem data( //42Kbytes
   .CLKA(clk),
   .CLKB(clk),
   .CENA(~b_data_cen),
   .WENA(~b_data_wr),
   .AA(b_data_addr[15:4]),
   .DA(b_tcm_write_data),
   .QA(b_tcm_read_data_data),
   .OENA(1'b0),
   .CENB(~lpc_rd),
   .WENB(1'b1),
   .AB(lpc_addr[15:4]),
   .DB(128'h0),
   .QB(c_tcm_read_data),
   .OENB(1'b0)   
);
`endif

`define FSM_IDLE    0
`define FSM_ACT     1
`define FSM_FIN     2
reg[1:0] fsm;

always @(posedge clk or posedge rst)
begin
    if(rst)
    begin
        fsm <= 0;
        b_tcm_request_finish <= 0;
        sel <= 0;
        b_cen <= 0;
        b_wr <= 0;
    end else
    begin
        case(fsm)
        `FSM_IDLE:
        begin
            if(b_tcm_read_request || b_tcm_write_request)
            begin
                if(b_tcm_addr[15:12] == 0) begin b_disk_addr <= b_tcm_addr; sel <= `SEL_DISK; end
                else begin b_data_addr <= {b_tcm_addr[15:12] - 1, b_tcm_addr[11:0]}; sel <= `SEL_DATA; end
                fsm <= `FSM_ACT;
            end
            if(b_tcm_read_request) begin b_cen <= 1; b_wr <= 0; end
            if(b_tcm_write_request) begin b_cen <= 1; b_wr <= d_tcm_addr[15:0] != b_tcm_addr[15:0]; end //avoid collision
        end
        `FSM_ACT:
        begin
            b_cen <= 0;
            b_wr <= 0;
            b_tcm_request_finish <= 1;
            fsm <= `FSM_FIN;
        end
        `FSM_FIN:
        begin
            b_tcm_request_finish <= 0;
            fsm <= `FSM_IDLE;
        end
        endcase
    end
end

always @(posedge clk or posedge rst)
begin
    if(rst) c_tcm_request_finish <= 0;
    else
    begin
        if(c_tcm_request_finish) c_tcm_request_finish <= 0;
        else if(c_tcm_read_request)
        begin
            c_tcm_request_finish <= 1;
        end
    end
end

endmodule
