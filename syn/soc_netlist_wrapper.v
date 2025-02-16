module soc_wrapper(
);

wire clk;
wire iclk;
wire io_rst;
PISUW CLK_IN(.C(clk));
PISUW ICLK_IN(.C(iclk));
PISUW RST_IN(.C(io_rst));

wire io_spi_cs;
wire io_spi_clk;
wire io_spi_mosi;
wire io_spi_miso;

POL8W SPI_CS(.I(io_spi_cs));
POL8W SPI_CLK(.I(io_spi_clk));
POL8W SPI_MOSI(.I(io_spi_mosi));
PISUW SPI_MISO(.C(io_spi_miso));

wire io_i2s_lrclk;
wire io_i2s_bclk;
wire io_i2s_data;
POL8W I2S_LRCLK(.I(io_i2s_lrclk));
POL8W I2S_BCLK(.I(io_i2s_bclk));
POL8W I2S_DATA(.I(io_i2s_data));

wire io_i2c_scl;
wire sdat_out;
wire io_i2c_sda;
PBU12W I2C_SDA(.C(io_i2c_sda), .I(0), .OEN(sdat_out));
POL12W I2C_SCL(.I(io_i2c_scl));

soc soc(
    .iclk(iclk),
    .io_rst(io_rst),
    
    .clk(clk),
    
    .io_spi_cs(io_spi_cs),
    .io_spi_clk(io_spi_clk),
    .io_spi_mosi(io_spi_mosi),
    .io_spi_miso(io_spi_miso),
    
    .io_i2s_lrclk(io_i2s_lrclk),
    .io_i2s_bclk(io_i2s_bclk),
    .io_i2s_data(io_i2s_data),
    
    .io_i2c_scl(io_i2c_scl),
    .sdat_out(sdat_out),
    .io_i2c_sda(io_i2c_sda)
);
     
endmodule
