//`define USE_INTERNAL_CLK
//`define NO_EEPROM

module i2c_phy(
    input clk,
    input rst,

    output i2c_sclk,
    output reg i2c_sdat_out,
    input i2c_sdat_in,

    input wr, //wr==1 write, wr==0 read
    input go,
    output reg finish,

    input[7:0] addr,
    output ack,
    input[15:0] wr_data,
    output reg[15:0] rd_data
);

reg[5:0] cnt;

reg cg;
assign i2c_sclk = cg || (((cnt >= 4) && (cnt <= 30)) ? !clk : 0);

reg nack1, nack2, nack3;
assign ack = !(nack1 || nack2 || nack3);

//fsm counter
always @(posedge clk or posedge rst)
begin
    if (rst) cnt <= 0; else
	if (!go) cnt <= 0;
	else if (!cnt[5]) cnt <= cnt + 1;
end

always @(posedge clk or posedge rst)
begin
	if (rst)
	begin
		cg <= 1;
        i2c_sdat_out <= 1;
		nack1 <= 0; nack2 <= 0; nack3 <= 0;
		finish <= 0;
	end else
    case (cnt)
	6'd0  : begin cg <= 1; i2c_sdat_out <= 1; nack1 <= 0; nack2 <= 0; nack3 <= 0; finish <= 0; end

	//start
	6'd1  : i2c_sdat_out <= 0;
	6'd2  : cg <= 0;

	//slave addr
	6'd3  : i2c_sdat_out <= addr[7];
	6'd4  : i2c_sdat_out <= addr[6];
	6'd5  : i2c_sdat_out <= addr[5];
	6'd6  : i2c_sdat_out <= addr[4];
	6'd7  : i2c_sdat_out <= addr[3];
	6'd8  : i2c_sdat_out <= addr[2];
	6'd9  : i2c_sdat_out <= addr[1];
	6'd10 : i2c_sdat_out <= addr[0];	
	6'd11 : i2c_sdat_out <= 1; //ACK

	//data byte 1 (sub addr)
	6'd12 : begin i2c_sdat_out <= wr ? wr_data[15] : 1; nack1 <= i2c_sdat_in; end
	6'd13 : begin i2c_sdat_out <= wr ? wr_data[14] : 1; rd_data[15] <= wr ? rd_data[15] : i2c_sdat_in; end
	6'd14 : begin i2c_sdat_out <= wr ? wr_data[13] : 1; rd_data[14] <= wr ? rd_data[14] : i2c_sdat_in; end
	6'd15 : begin i2c_sdat_out <= wr ? wr_data[12] : 1; rd_data[13] <= wr ? rd_data[13] : i2c_sdat_in; end
	6'd16 : begin i2c_sdat_out <= wr ? wr_data[11] : 1; rd_data[12] <= wr ? rd_data[12] : i2c_sdat_in; end
	6'd17 : begin i2c_sdat_out <= wr ? wr_data[10] : 1; rd_data[11] <= wr ? rd_data[11] : i2c_sdat_in; end
	6'd18 : begin i2c_sdat_out <= wr ? wr_data[9]  : 1; rd_data[10] <= wr ? rd_data[10] : i2c_sdat_in; end
	6'd19 : begin i2c_sdat_out <= wr ? wr_data[8]  : 1; rd_data[9]  <= wr ? rd_data[9]  : i2c_sdat_in; end
	6'd20 : begin i2c_sdat_out <= wr ? 1 : 0;           rd_data[8]  <= wr ? rd_data[8]  : i2c_sdat_in; end //ACK

    //data byte 2
	6'd21 : begin i2c_sdat_out <= wr ? wr_data[7] : 1; nack2 <= i2c_sdat_in; end
	6'd22 : begin i2c_sdat_out <= wr ? wr_data[6] : 1; rd_data[7] <= wr ? rd_data[7] : i2c_sdat_in; end
	6'd23 : begin i2c_sdat_out <= wr ? wr_data[5] : 1; rd_data[6] <= wr ? rd_data[6] : i2c_sdat_in; end
	6'd24 : begin i2c_sdat_out <= wr ? wr_data[4] : 1; rd_data[5] <= wr ? rd_data[5] : i2c_sdat_in; end
	6'd25 : begin i2c_sdat_out <= wr ? wr_data[3] : 1; rd_data[4] <= wr ? rd_data[4] : i2c_sdat_in; end
	6'd26 : begin i2c_sdat_out <= wr ? wr_data[2] : 1; rd_data[3] <= wr ? rd_data[3] : i2c_sdat_in; end
	6'd27 : begin i2c_sdat_out <= wr ? wr_data[1] : 1; rd_data[2] <= wr ? rd_data[2] : i2c_sdat_in; end
	6'd28 : begin i2c_sdat_out <= wr ? wr_data[0] : 1; rd_data[1] <= wr ? rd_data[1] : i2c_sdat_in; end
	6'd29 : begin i2c_sdat_out <= 1;                   rd_data[0] <= wr ? rd_data[0] : i2c_sdat_in; end //ACK

	//stop
    6'd30 : begin nack3 <= wr ? i2c_sdat_in : 0; i2c_sdat_out <= 0; end	
    6'd31 : cg <= 1;
    6'd32 : begin i2c_sdat_out <= 1; finish <= 1; end 
    endcase    
end
endmodule

module i2c_hci (
    input clk,
    input rst,
    output reg done,
    output i2c_sclk,
    output i2c_sdat_out,
    input i2c_sdat_in
);

reg i2c_ctrl_clk;
reg[6:0] i2c_ctrl_div;

always @(posedge clk or posedge rst)
begin
    if (rst)
    begin
        i2c_ctrl_clk <=	0;
        i2c_ctrl_div <=	0;
    end else
`ifdef USE_INTERNAL_CLK
    if (i2c_ctrl_div[2]) //4.4MHz / 400kHz / 2
`else
    if (i2c_ctrl_div[6]) //27MHz / 400kHz / 2
`endif
    begin
        i2c_ctrl_clk <= ~i2c_ctrl_clk;
        i2c_ctrl_div <=	0;
    end else
    begin
        i2c_ctrl_div <=	i2c_ctrl_div + 1;
    end
end

wire[15:0] phy_rd_data;
reg[15:0] phy_wr_data;

reg[15:0] phy_ctrl;
wire[7:0] phy_maddr;
wire[7:0] phy_mcnt;
assign phy_maddr = phy_ctrl[15:8];
assign phy_mcnt = phy_ctrl[7:0];

parameter eeprom_maddr = 8'b10100001;

reg i2c_wr, i2c_go;
wire i2c_finish;
wire i2c_ack;
reg[7:0] i2c_addr;

i2c_phy u0 (
    .clk(i2c_ctrl_clk),
    .rst(rst),

    .i2c_sclk(i2c_sclk),
    .i2c_sdat_out(i2c_sdat_out),
    .i2c_sdat_in(i2c_sdat_in),

    .wr(i2c_wr), //wr==1 write, wr==0 read
    .go(i2c_go),
    .finish(i2c_finish),

    .addr(i2c_addr),
    .ack(i2c_ack),
    .wr_data(phy_wr_data),
    .rd_data(phy_rd_data)
);

`ifdef NO_EEPROM
reg[23:0] LUT_DATA;
reg[7:0]  LUT_INDEX;

parameter LUT_SIZE = 54;
always @(*)
begin
	case(LUT_INDEX)
	//	Config Data
	0	: LUT_DATA <= 24'h200216;
	1	: LUT_DATA <= 24'h2003e8;
	2	: LUT_DATA <= 24'h200410;
	3	: LUT_DATA <= 24'h200749;
	4	: LUT_DATA <= 24'h200880;
	5	: LUT_DATA <= 24'h200910;
	6	: LUT_DATA <= 24'h200a08;
	7	: LUT_DATA <= 24'hc00307;
	8	: LUT_DATA <= 24'hc0100c;
	9	: LUT_DATA <= 24'hc0110c;
	10	: LUT_DATA <= 24'hc0120c;
	11	: LUT_DATA <= 24'hc01a00;
	12	: LUT_DATA <= 24'hc01b01;
	13	: LUT_DATA <= 24'hc01c00;
	14	: LUT_DATA <= 24'hc01d0e;
	15	: LUT_DATA <= 24'hc01e00;
	16	: LUT_DATA <= 24'hc01f00;
	17	: LUT_DATA <= 24'hc02000;
	18	: LUT_DATA <= 24'hc02100;
	19	: LUT_DATA <= 24'hc02200;
	20	: LUT_DATA <= 24'hc02301;
	21	: LUT_DATA <= 24'hc02400;
	22	: LUT_DATA <= 24'hc02500;
	23	: LUT_DATA <= 24'hc02600;
	24	: LUT_DATA <= 24'hc02700;
	25	: LUT_DATA <= 24'hc02800;
	26	: LUT_DATA <= 24'hc02900;
	27	: LUT_DATA <= 24'hc02a0c;
	28	: LUT_DATA <= 24'hc02b35;
	29	: LUT_DATA <= 24'hc02c00;
	30	: LUT_DATA <= 24'hc02d06;
	31	: LUT_DATA <= 24'hc02e00;
	32	: LUT_DATA <= 24'hc02f00;
	33	: LUT_DATA <= 24'hc03000;
	34	: LUT_DATA <= 24'hc031e0;
	35	: LUT_DATA <= 24'hc0320c;
	36	: LUT_DATA <= 24'hc03335;
	37	: LUT_DATA <= 24'hc03400;
	38	: LUT_DATA <= 24'hc0351e;
	39	: LUT_DATA <= 24'hc03600;
	40	: LUT_DATA <= 24'hc03700;
	41	: LUT_DATA <= 24'hc03803;
	42	: LUT_DATA <= 24'hc03980;
	43	: LUT_DATA <= 24'hc03a0c;
	44	: LUT_DATA <= 24'hc03b35;
	45	: LUT_DATA <= 24'hc03c00;
	46	: LUT_DATA <= 24'hc03d3e;
	47	: LUT_DATA <= 24'hc03e00;
	48	: LUT_DATA <= 24'hc03f00;
	49	: LUT_DATA <= 24'hc04007;
	50	: LUT_DATA <= 24'hc04100;
	51	: LUT_DATA <= 24'hc0b1a0;
	52	: LUT_DATA <= 24'hc0b7d2;
	53	: LUT_DATA <= 24'hc00300;
	54	: LUT_DATA <= 24'h2005fd;
	default:
          LUT_DATA <= 24'hx;
	endcase
end
`endif

reg[3:0] fsm;
reg[7:0] wr_cnt;

always @(posedge i2c_ctrl_clk or posedge rst)
begin
    if (rst)
    begin
        done <= 0;
`ifdef NO_EEPROM
        fsm <= 6;
        LUT_INDEX <= 0;
`else
        fsm <= 0;
`endif
    end else
    begin
        if (!done)
        case(fsm)
`ifndef NO_EEPROM
        0: fsm <= 1;
        1:
        begin
            i2c_wr <= 0;
            i2c_go <= 1;
            i2c_addr <= eeprom_maddr;
            fsm <= 2;
        end
        2: //get ctrl
        begin
            if (i2c_finish)
            begin
                i2c_go <= 0;
                fsm	<= i2c_ack ? 3 : 0;
                wr_cnt <= 0;
                phy_ctrl <= phy_rd_data;
                done <= phy_rd_data == 16'hFFFF;
            end
        end
        3: fsm <= 4;
        4:
        begin
            i2c_wr <= 0;
            i2c_go <= 1;
            i2c_addr <= eeprom_maddr;
            fsm <= 5;
        end
        5: //get data
        begin
            if (i2c_finish)
            begin
                i2c_go <= 0;
                fsm	<= i2c_ack ? 6 : 3;
                wr_cnt <= i2c_ack ? wr_cnt + 1 : wr_cnt;
            end
        end
`endif
        6:
        begin
            fsm <= 7;
        end
        7:
        begin
            i2c_wr <= 1;
            i2c_go <= 1;
`ifdef NO_EEPROM
            i2c_addr <= LUT_DATA[23:16];
            phy_wr_data <= LUT_DATA[15:0];
`else
            i2c_addr <= phy_maddr;
            phy_wr_data <= phy_rd_data;
`endif
            fsm <= 8;
        end
        8: //send data
        begin
            if (i2c_finish)
            begin
                i2c_go <= 0;
`ifdef NO_EEPROM
                LUT_INDEX <= i2c_ack ? LUT_INDEX + 1 : LUT_INDEX;
                fsm	<= 6;
                done <= LUT_INDEX == LUT_SIZE;
`else
                fsm	<= i2c_ack ? (wr_cnt == phy_mcnt ? 0 : 3) : 6;
`endif
            end
        end
        endcase
    end
end

endmodule 
