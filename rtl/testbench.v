`timescale 100ps/100ps

`define DELAY 20

module testbench();

reg clk;
reg rst;
reg ready;

wire mp_ip_rd;
wire[9:0] mp_ip_rd_addr;

wire[31:0] mp_ip_rd_data;
reg[31:0] mp_ip_rd_data_ori;

assign mp_ip_rd_data = {mp_ip_rd_data_ori[7:0], mp_ip_rd_data_ori[15:8], mp_ip_rd_data_ori[23:16], mp_ip_rd_data_ori[31:24]};

integer i;
initial
begin
    i = $fopen("test_instructions.bin", "rb");
end

localparam F_START = 0;

always @(posedge clk)
begin
    if(mp_ip_rd)
    begin
        $fseek(i, mp_ip_rd_addr * 4, F_START);
        $fread(mp_ip_rd_data_ori, i);
    end
end

initial clk = 0;
initial rst = 1;
initial ready = 0;

initial #50 rst <= 0;
initial #75 ready <= 1;

reg[7:0] mem[32767:0];

integer m,n;
integer cnt, cnt1;
initial cnt = `DELAY;

integer j;
initial
begin
    for(j = 0; j < 32768; j = j + 1) mem[j] = 0;
    $readmemh("test_data.txt", mem);
    #45000000;
    $writememh("test_data_out.txt", mem, 0);
    $display("mem port %d times.", cnt1);
    $stop;
end

always #25 clk <= !clk;

wire read_request, write_request;
reg finish;
initial finish = 0;

wire[15:0] tcm_addr;
reg[127:0] read_data;
wire[127:0] write_data;

wire irq;
reg[15:0] int_pulse;
integer count;

initial int_pulse = 0;
initial count = 0;

always @(posedge clk)
begin
    if(count == 20000) 
    begin
        int_pulse[0] <= 1;
        count <= 0;
    end else
    begin
        int_pulse[0] <= 0;
        count <= count + 1;
    end
end

wire evb_cmd_request;
wire[15:0] evb_cmd_addr;
wire[3:0] evb_cmd_wr_mask;
wire[31:0] evb_cmd_wr_data;
wire evb_cmd_finish;
wire[31:0] evb_cmd_rd_data;

pic pic(
    .clk(clk),
    .rst(rst),

    .int_pulse(int_pulse),
    .mp_int(irq),

    .evb_cmd_request(evb_cmd_request),
    .evb_cmd_addr(evb_cmd_addr), //15:4 device id, 3:0 sub id
    .evb_cmd_wr_mask(evb_cmd_wr_mask),
    .evb_cmd_wr_data(evb_cmd_wr_data),
    .evb_cmd_finish(evb_cmd_finish),
    .evb_cmd_rd_data(evb_cmd_rd_data)
);

mp mp(
    .clk(clk),
    .rst(rst),
    .ready(ready),

    .mp_ip_rd(mp_ip_rd),
    .mp_ip_rd_addr(mp_ip_rd_addr),
    .mp_ip_rd_data(mp_ip_rd_data),

    .irq(irq),
    
    .evb_cmd_request(evb_cmd_request),
    .evb_cmd_addr(evb_cmd_addr), //15:4 device id, 3:0 sub id
    .evb_cmd_wr_mask(evb_cmd_wr_mask),
    .evb_cmd_wr_data(evb_cmd_wr_data),
    .evb_cmd_finish(evb_cmd_finish),
    .evb_cmd_rd_data(evb_cmd_rd_data),
    
    .tcm_invalid(1'b0),
    .tcm_invalid_addr(16'h0),
    .tcm_read_request(read_request),
    .tcm_write_request(write_request),
    .tcm_request_finish(finish),
    .tcm_addr(tcm_addr),
    .tcm_read_data(read_data),
    .tcm_write_data(write_data)
);

initial cnt1 = 0;
always @(posedge clk)
begin
    if(!finish)
    begin
        if(read_request || write_request)
        begin
            if(cnt == 0)
            begin
                if(write_request)
                    for(m = 0; m < 16; m = m + 1)
                    mem[tcm_addr+m] <= write_data[m*8+:8];
                if(read_request)
                    for(n = 0; n < 16; n = n + 1)
                    read_data[n*8+:8] <= mem[tcm_addr+n];
                finish <= 1;
                cnt1 <= cnt1 + 1;
            end else
            begin
                cnt <= cnt - 1;
            end
        end
    end else
    begin
        finish <= 0;
        cnt <= `DELAY;
    end
end
endmodule
