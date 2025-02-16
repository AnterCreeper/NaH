module reset_module(
    input clk, 
    input rst_async,
    output reg sys_rst
);

reg rst_r;

always @(posedge clk or negedge rst_async) begin
    if (!rst_async) begin
        rst_r <= 1'b1;
    end
    else begin
        rst_r <= 1'b0;
    end
end

always @(posedge clk or negedge rst_async) begin
    if (!rst_async) begin
        sys_rst <= 1'b1;
    end
    else begin
        sys_rst <= rst_r;
    end
end
endmodule

`ifdef TARGET_FPGA
module int_clk(
    output clk
);

STARTUPE2   #(
    .PROG_USR("FALSE"),
    .SIM_CCLK_FREQ(0.0)
)
STARTUPE2_inst(
    .CFGCLK(),
    .CFGMCLK(clk),
    .EOS(),
    .PREQ(),
    .CLK(0),
    .GSR(0),
    .GTS(0),
    .KEYCLEARB(1),
    .PACK(1),
    .USRCCLKO(1),
    .USRCCLKTS(1),
    .USRDONEO(1),
    .USRDONETS(1)
);

endmodule
`endif

/*
module button(
    input iclk,
    input rst,
    input btn,
    output test,
    output reg request,
    input finish
);

reg irq, irq_rst;
assign test = irq;

always @(posedge iclk or negedge btn)
begin
    if (!btn)
    begin
        irq <= 1;
    end else
    begin
        if (irq_rst) irq <= 0;
    end
end

//remove button joggle
reg[16:0] irq_cnt;

always @(posedge iclk or posedge rst)
begin
    if (rst) begin
        request <= 0;
        irq_rst <= 0;
        irq_cnt <= 0;
    end else
    begin
        if (irq)
        begin
            if (!irq_rst)
            begin
                irq_rst <= 1;
                irq_cnt <= 0;
            end else
            begin
                if(!irq_cnt[16]) irq_cnt <= irq_cnt + 1;
            end
            if (finish) request <= 0;
        end else
        begin
            if (irq_rst) irq_rst <= 0;
            if (irq_rst && irq_cnt[16]) request <= 1;
            else if (finish) request <= 0;
        end
    end
end
endmodule
*/

module soc(
    input clk,
    input io_rst,
        
    //SPI
    output io_spi_cs,
    output io_spi_clk,
    output io_spi_mosi,
    input io_spi_miso,
    
    //I2S
    output io_i2s_lrclk,
    output io_i2s_bclk,
    output io_i2s_data,
    
    //I2C
    output io_i2c_scl,
`ifdef TARGET_FPGA
    inout io_i2c_sda,
`else
    output sdat_out,
    input io_i2c_sda,
`endif
    //GPIO
    input amp_sel,
    input bst_sel,
    output amp_en,
    output bst_en,
    output amp_led,
    output bst_led,
    
    output done,
    output mp_busy,
    output sdhci_busy,
    output lpc_busy,
    
    output sdhci_en,
    
    output led_a,
    output led_b,
    output led_c,
    output led_d,
    output led_e,
    output led_f,
    output led_g,
    output led_d1,
    output led_d2,
    output led_dp,
    
`ifndef TARGET_FPGA
    input iclk,
`endif
    output test_spi_cs,
    output test_spi_mosi,
    output test_spi_miso,
    output test_spi_clk
    
    //not used.
    /*
    input mclk,
    input init_wr,
    input[7:0] init_wr_data,
    input[15:0] int_pulse*/
);

assign amp_en = amp_sel;
assign amp_led = amp_sel;
assign bst_en = bst_sel;
assign bst_led = bst_sel;

assign test_spi_cs = io_spi_cs;
assign test_spi_mosi = mp_busy;
assign test_spi_miso = lpc_busy;
assign test_spi_clk = sdhci_busy;
    
wire mclk, init_wr;
assign mclk = 0;
assign init_wr = 0;
wire[7:0] init_wr_data;
wire[15:0] int_pulse;
assign init_wr_data = 0;
assign int_pulse = 0;
    
wire pic_mp_irq;

wire[15:0] evb_cmd_addr;
wire[1:0] evb_cmd_wr_mask;
wire[31:0] evb_cmd_wr_data;

wire mp_evb_cmd_request;
wire mp_evb_cmd_finish;
wire[31:0] mp_evb_cmd_rd_data;

wire pic_evb_cmd_request;
wire pic_evb_cmd_finish;
wire[31:0] pic_evb_cmd_rd_data;

wire lpc_evb_cmd_request;
wire lpc_evb_cmd_finish;
wire[31:0] lpc_evb_cmd_rd_data;

wire phy_evb_cmd_request;
wire phy_evb_cmd_finish;
wire[31:0] phy_evb_cmd_rd_data;

wire sdhci_evb_cmd_request;
wire sdhci_evb_cmd_finish;
wire[31:0] sdhci_evb_cmd_rd_data;

wire dbg_cmd_request;
wire dbg_evb_cmd_finish;
wire[31:0] dbg_evb_cmd_rd_data;

wire mp_tcm_invalid;
wire[15:0] mp_tcm_invalid_addr;
wire mp_tcm_read_request, mp_tcm_write_request;
wire mp_tcm_request_finish;
wire[15:0] mp_tcm_addr;
wire[127:0] mp_tcm_read_data;
wire[127:0] mp_tcm_write_data;

wire sdhci_tcm_write_request;
wire sdhci_tcm_request_finish;
wire[31:0] sdhci_tcm_addr;
wire[127:0] sdhci_tcm_write_data;

wire lpc_tcm_read_request;
wire lpc_tcm_request_finish;
wire[31:0] lpc_tcm_addr;
wire[127:0] lpc_tcm_read_data;

wire lpc_phy_rd_valid;
wire lpc_phy_rd;
wire[1:0] lpc_phy_rd_chansgn;
wire[16:0] lpc_phy_rd_data_chan0;
wire[16:0] lpc_phy_rd_data_chan1;

wire rst;

reset_module reset(
    .clk(clk),
    .rst_async(io_rst), //rst_n
    .sys_rst(rst) //rst
);

wire ready_n;
assign ready = !ready_n;
reset_module rst_done(
    .clk(clk),
    .rst_async(done), 
    .sys_rst(ready_n)
);

(*mark_debug="true"*)reg[31:0] total_cnt;
(*mark_debug="true"*)reg[31:0] mp_busy_cnt;
(*mark_debug="true"*)reg[31:0] lpc_busy_cnt;
(*mark_debug="true"*)reg[31:0] sdhci_busy_cnt;

always @(posedge clk or posedge rst)
begin
    if(rst)
    begin
        total_cnt <= 0;
        mp_busy_cnt <= 0;
        lpc_busy_cnt <= 0;
        sdhci_busy_cnt <= 0;
    end else
    if(ready)
    begin
        total_cnt <= total_cnt + 1;
        if(mp_busy) mp_busy_cnt <= mp_busy_cnt + 1;
        if(lpc_busy) lpc_busy_cnt <= lpc_busy_cnt + 1;
        if(sdhci_busy) sdhci_busy_cnt <= sdhci_busy_cnt + 1;
    end else
    begin
        total_cnt <= 0;
        mp_busy_cnt <= 0;
        lpc_busy_cnt <= 0;
        sdhci_busy_cnt <= 0;
    end
end

wire iclk;
`ifdef TARGET_FPGA
int_clk clk(
    .clk(iclk)
);
`endif

//open drain
wire io_i2c_sda, sdat_out;
`ifdef TARGET_FPGA
assign io_i2c_sda = sdat_out ? 1'bz : 0;
`endif
i2c_hci i2c0(
    .clk(iclk),
    .rst(!io_rst),
    .done(done),
    .i2c_sclk(io_i2c_scl),
    .i2c_sdat_out(sdat_out),
    .i2c_sdat_in(io_i2c_sda)
);

pic pic(
    .clk(clk),
    .rst(rst),

    .int_pulse(int_pulse),
    .mp_int(pic_mp_irq),

    .evb_cmd_request(pic_evb_cmd_request),
    .evb_cmd_addr(pic_evb_cmd_request ? evb_cmd_addr[3:0] : 4'h0),
    .evb_cmd_wr_mask(evb_cmd_wr_mask),
    .evb_cmd_wr_data(evb_cmd_wr_data),
    .evb_cmd_finish(pic_evb_cmd_finish),
    .evb_cmd_rd_data(pic_evb_cmd_rd_data)
);

wire tcm_sdhci_test;
wire[31:0] tcm_sdhci_test_addr;
    
sdhci sdhci(
    .clk(clk),
    .rst(rst),

    .evb_cmd_request(sdhci_evb_cmd_request),
    .evb_cmd_addr(sdhci_evb_cmd_request ? evb_cmd_addr[3:0] : 4'h0),
    .evb_cmd_wr_mask(evb_cmd_wr_mask),
    .evb_cmd_wr_data(evb_cmd_wr_data),
    .evb_cmd_finish(sdhci_evb_cmd_finish),
    .evb_cmd_rd_data(sdhci_evb_cmd_rd_data),
    
    .tcm_write_request(sdhci_tcm_write_request),
    .tcm_request_finish(sdhci_tcm_request_finish),
    .tcm_addr(sdhci_tcm_addr),
    .tcm_write_data(sdhci_tcm_write_data),
    
    .spi_cs(io_spi_cs),
    .spi_clk(io_spi_clk),
    .spi_mosi(io_spi_mosi),
    .spi_miso(io_spi_miso),
    
    .busy(sdhci_busy),
    .en(sdhci_en)
    //.test(tcm_sdhci_test),
    //.test_addr(tcm_sdhci_test_addr)
);

lpc hydrogen(
    .clk(clk),
    .rst(rst),
    
    .evb_cmd_request(lpc_evb_cmd_request),
    .evb_cmd_addr(lpc_evb_cmd_request ? evb_cmd_addr[3:0] : 4'h0),
    .evb_cmd_wr_mask(evb_cmd_wr_mask),
    .evb_cmd_wr_data(evb_cmd_wr_data),
    .evb_cmd_finish(lpc_evb_cmd_finish),
    .evb_cmd_rd_data(lpc_evb_cmd_rd_data),
    
    .tcm_read_request(lpc_tcm_read_request),
    .tcm_request_finish(lpc_tcm_request_finish),
    .tcm_addr(lpc_tcm_addr),
    .tcm_read_data(lpc_tcm_read_data),
    
    .phy_rd_valid(lpc_phy_rd_valid),
    .phy_rd(lpc_phy_rd),
    .phy_rd_chansgn(lpc_phy_rd_chansgn),
    .phy_rd_data_chan0(lpc_phy_rd_data_chan0),
    .phy_rd_data_chan1(lpc_phy_rd_data_chan1),
    
    .busy(lpc_busy)
);

i2s i2s(
    .clk(clk),
    .rst(rst),

    .phy_rd_valid(lpc_phy_rd_valid),
    .phy_rd(lpc_phy_rd),
    .phy_rd_chansgn(lpc_phy_rd_chansgn),
    .phy_rd_data_chan0(lpc_phy_rd_data_chan0),
    .phy_rd_data_chan1(lpc_phy_rd_data_chan1),

    .evb_cmd_request(phy_evb_cmd_request),
    .evb_cmd_addr(phy_evb_cmd_request ? evb_cmd_addr[3:0] : 4'h0),
    .evb_cmd_wr_mask(evb_cmd_wr_mask),
    .evb_cmd_wr_data(evb_cmd_wr_data),
    .evb_cmd_finish(phy_evb_cmd_finish),
    .evb_cmd_rd_data(phy_evb_cmd_rd_data),

    .io_i2s_lrclk(io_i2s_lrclk),
    .io_i2s_bclk(io_i2s_bclk),
    .io_i2s_data(io_i2s_data)
);

wire mp_ip_rd;
wire[13:0] mp_ip_rd_addr;
wire[31:0] mp_ip_rd_data;

wire dump;

mp sodium(
    .clk(clk),
    .rst(rst),
    .ready(ready),

    .mp_ip_rd(mp_ip_rd),
    .mp_ip_rd_addr(mp_ip_rd_addr),
    .mp_ip_rd_data(mp_ip_rd_data),

    .irq(pic_mp_irq),
    
    .evb_cmd_request(mp_evb_cmd_request),
    .evb_cmd_addr(evb_cmd_addr), //15:4 device id, 3:0 sub id
    .evb_cmd_wr_mask(evb_cmd_wr_mask),
    .evb_cmd_wr_data(evb_cmd_wr_data),
    .evb_cmd_finish(mp_evb_cmd_finish),
    .evb_cmd_rd_data(mp_evb_cmd_rd_data),
    
    .tcm_invalid(mp_tcm_invalid),
    .tcm_invalid_addr(mp_tcm_invalid_addr),
    .tcm_read_request(mp_tcm_read_request),
    .tcm_write_request(mp_tcm_write_request),
    .tcm_request_finish(mp_tcm_request_finish),
    .tcm_addr(mp_tcm_addr),
    .tcm_read_data(mp_tcm_read_data),
    .tcm_write_data(mp_tcm_write_data),
    
    .busy(mp_busy)
);

tcm tcm(
    .clk(clk),
    .rst(rst),
    
    .a_rd(mp_ip_rd),
    .a_rd_addr(mp_ip_rd_addr),
    .a_rd_data(mp_ip_rd_data),
    
    .b_tcm_invalid(mp_tcm_invalid),
    .b_tcm_invalid_addr(mp_tcm_invalid_addr),
    .b_tcm_read_request(mp_tcm_read_request),
    .b_tcm_write_request(mp_tcm_write_request),
    .b_tcm_request_finish(mp_tcm_request_finish),
    .b_tcm_addr(mp_tcm_addr),
    .b_tcm_read_data(mp_tcm_read_data),
    .b_tcm_write_data(mp_tcm_write_data),
    
    .c_tcm_read_request(lpc_tcm_read_request),
    .c_tcm_request_finish(lpc_tcm_request_finish),
    .c_tcm_addr(lpc_tcm_addr[15:0]),
    .c_tcm_read_data(lpc_tcm_read_data),

    .d_tcm_write_request(sdhci_tcm_write_request),
    .d_tcm_request_finish(sdhci_tcm_request_finish),
    .d_tcm_addr(sdhci_tcm_addr),
    .d_tcm_write_data(sdhci_tcm_write_data),
    
    .mclk(mclk),
    .ready(ready),
    .init_wr(init_wr),
    .init_wr_data(init_wr_data),
    
    //.tcm_sdhci_test(tcm_sdhci_test),
    //.tcm_sdhci_test_addr(tcm_sdhci_test_addr),
    
    .dump(dump)
);

dbg dbg(
    .clk(clk),
    .rst(rst),

    .evb_cmd_request(dbg_evb_cmd_request),
    .evb_cmd_addr(dbg_evb_cmd_request ? evb_cmd_addr[3:0] : 4'h0),
    .evb_cmd_wr_mask(evb_cmd_wr_mask),
    .evb_cmd_wr_data(evb_cmd_wr_data),
    .evb_cmd_finish(dbg_evb_cmd_finish),
    .evb_cmd_rd_data(dbg_evb_cmd_rd_data),
    
    .led_a(led_a),
    .led_b(led_b),
    .led_c(led_c),
    .led_d(led_d),
    .led_e(led_e),
    .led_f(led_f),
    .led_g(led_g),
    .led_d1(led_d1),
    .led_d2(led_d2),
    .led_dp(led_dp)
);

bus evb(
    .clk(clk),

    .mp_evb_cmd_request(mp_evb_cmd_request),
    .mp_evb_cmd_addr(evb_cmd_addr),
    .mp_evb_cmd_finish(mp_evb_cmd_finish),
    .mp_evb_cmd_rd_data(mp_evb_cmd_rd_data),

    .pic_evb_cmd_request(pic_evb_cmd_request),
    .pic_evb_cmd_finish(pic_evb_cmd_finish),
    .pic_evb_cmd_rd_data(pic_evb_cmd_rd_data),
    
    .lpc_evb_cmd_request(lpc_evb_cmd_request),
    .lpc_evb_cmd_finish(lpc_evb_cmd_finish),
    .lpc_evb_cmd_rd_data(lpc_evb_cmd_rd_data),
    
    .phy_evb_cmd_request(phy_evb_cmd_request),
    .phy_evb_cmd_finish(phy_evb_cmd_finish),
    .phy_evb_cmd_rd_data(phy_evb_cmd_rd_data),
    
    .sdhci_evb_cmd_request(sdhci_evb_cmd_request),
    .sdhci_evb_cmd_finish(sdhci_evb_cmd_finish),
    .sdhci_evb_cmd_rd_data(sdhci_evb_cmd_rd_data),
    
    .dbg_evb_cmd_request(dbg_evb_cmd_request),
    .dbg_evb_cmd_finish(dbg_evb_cmd_finish),
    .dbg_evb_cmd_rd_data(dbg_evb_cmd_rd_data)
);

endmodule
