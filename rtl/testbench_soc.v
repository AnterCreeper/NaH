`timescale 100ps/100ps

`define DELAY 20

module testbench_soc();

reg clk;
reg rst;
reg ready;

wire io_i2s_lrclk;
wire io_i2s_bclk;
wire io_i2s_data;

soc soc(
    .clk(clk),
    .rst(rst),
    .ready(ready),
    
    .int_pulse(16'h0),
    
    //output io_spi_cs,
    //output io_spi_clk,
    //output io_spi_mosi,
    .io_spi_miso(1'b0),
    
    .io_i2s_lrclk(io_i2s_lrclk),
    .io_i2s_bclk(io_i2s_bclk),
    .io_i2s_data(io_i2s_data),
    
    .mclk(1'b0),
    .init_wr(1'b0),
    .init_wr_data(8'h0)
);

initial clk = 0;
initial rst = 1;
initial ready = 0;

initial #1050 rst <= 0;
initial #1075 ready <= 1;

always #25 clk <= !clk;

endmodule
