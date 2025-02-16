`timescale 100ps/100ps
`include "defines.v"

`define DELAY 20
`define DELAY_PHY 50
//approx.
//200000 kHz / 48kHz * 2

module testbench_lpc();

reg clk, rst;

reg evb_cmd_request;
reg[31:0] evb_cmd_addr;
reg[1:0] evb_cmd_wr_mask;
reg[31:0] evb_cmd_wr_data;
wire evb_cmd_finish;
wire[31:0] evb_cmd_rd_data;

wire tcm_read_request;
reg tcm_request_finish;
wire[31:0] tcm_addr;
reg[127:0] tcm_read_data;

reg phy_rd_flip;
wire phy_rd_valid;
reg phy_rd;
wire[1:0] phy_rd_chansgn;
wire[16:0] phy_rd_data_chan0;
wire[16:0] phy_rd_data_chan1;

initial clk = 0;
initial rst = 1;

initial #50 rst <= 0;

always #25 clk <= !clk;

integer times;
initial times = 0;

integer fd_cmd;
integer fd_ram;

initial
begin
    fd_cmd <= $fopen("testbench.bin", "rb");
    fd_ram <= $fopen("ram.bin", "rb");
    evb_cmd_request <= 0;
    #75;
    #110;
    while(!$feof(fd_cmd))
    begin
        evb_cmd_request <= 1;
        $fread(evb_cmd_addr, fd_cmd);
        evb_cmd_addr[31:28] <= `EVB_LPC_ADDRESS;
        evb_cmd_wr_mask <= 3;
        $fread(evb_cmd_wr_data, fd_cmd);
        #35;
        while(!evb_cmd_finish)
        begin
        #50;
        end
        #5
        evb_cmd_request <= 0;
        #60;
    end
    #50;
    $display("mem port %d times.", times);
    $stop();
end

integer cnt;
initial cnt = `DELAY;

initial tcm_request_finish = 0;

always @(posedge clk)
begin
    if(!tcm_request_finish)
    begin
        if(tcm_read_request)
        begin
            if(cnt == 0)
            begin
                if(tcm_read_request)
                    $fseek(fd_ram, tcm_addr, 0);
                    $fread(tcm_read_data, fd_ram);
                tcm_request_finish <= 1;
            end else
            begin
                cnt <= cnt - 1;
            end
        end
    end else
    begin
        times <= times + 1;
        tcm_request_finish <= 0;
        cnt <= `DELAY;
    end
end

lpc flac(
    .clk(clk),
    .rst(rst),
    
    .evb_cmd_request(evb_cmd_request),
    .evb_cmd_addr({evb_cmd_addr[23:16], evb_cmd_addr[31:24]}),
    .evb_cmd_wr_mask(evb_cmd_wr_mask),
    .evb_cmd_wr_data({evb_cmd_wr_data[7:0], evb_cmd_wr_data[15:8], evb_cmd_wr_data[23:16], evb_cmd_wr_data[31:24]}),
    .evb_cmd_finish(evb_cmd_finish),
    .evb_cmd_rd_data(evb_cmd_rd_data),
    
    .tcm_read_request(tcm_read_request),
    .tcm_request_finish(tcm_request_finish),
    .tcm_addr(tcm_addr),
    .tcm_read_data({tcm_read_data[7:0], tcm_read_data[15:8], tcm_read_data[23:16], tcm_read_data[31:24],
                    tcm_read_data[39:32], tcm_read_data[47:40], tcm_read_data[55:48], tcm_read_data[63:56], 
                    tcm_read_data[71:64], tcm_read_data[79:72], tcm_read_data[87:80], tcm_read_data[95:88], 
                    tcm_read_data[103:96], tcm_read_data[111:104], tcm_read_data[119:112], tcm_read_data[127:120]}),
    
    .phy_rd_valid(phy_rd_valid),
    .phy_rd(phy_rd),
    .phy_rd_chansgn(phy_rd_chansgn),
    .phy_rd_data_chan0(phy_rd_data_chan0),
    .phy_rd_data_chan1(phy_rd_data_chan1)
);

integer count;
initial count = 0;

initial phy_rd = 0;
initial phy_rd_flip = 0;

reg phy_result_wr;
reg[31:0] phy_result;
//L, R channel

initial phy_result_wr = 0;

integer send;
initial send = 0;

always @(posedge clk)
begin
        phy_rd <= phy_rd_valid && count == `DELAY_PHY;
        send <= phy_rd_valid ? (count == `DELAY_PHY ? 1 : send) : 0;
        count <= count == `DELAY_PHY ? 0 : count + 1;
        if(phy_rd_valid && phy_rd)
        begin
            phy_result_wr <= 1;
            case(phy_rd_chansgn)
            0:
            begin
                phy_result[31:16] <= phy_rd_data_chan1;
                phy_result[15:0] <= phy_rd_data_chan0;
            end
            1:
            begin
                phy_result[31:16] <= phy_rd_data_chan0 - phy_rd_data_chan1;
                phy_result[15:0] <= phy_rd_data_chan0;
            end
            2:
            begin
                phy_result[31:16] <= phy_rd_data_chan1;
                phy_result[15:0] <= phy_rd_data_chan0 + phy_rd_data_chan1;
            end
            3:
            begin
                phy_result[31:16] <= phy_rd_data_chan0 - phy_rd_data_chan1[16:1];
                phy_result[15:0] <= phy_rd_data_chan0 + phy_rd_data_chan1[16:1] + phy_rd_data_chan1[0];
            end
            endcase
        end else
        begin
            phy_result_wr <= 0;
        end
end

integer fd_result;
initial fd_result = $fopen("output_wave.bin", "wb");

integer pos;
initial pos = 0;

always @(posedge clk)
begin
    if(phy_result_wr)
    begin
        $fwrite(fd_result, "%u", phy_result);
        pos <= pos + 1;
    end
end

endmodule
