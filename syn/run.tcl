read_libs ./lib/slow.lib ./lib/clrf_slow_syn.lib ./lib/buf_mem_slow_syn.lib ./lib/data_mem_slow_syn.lib ./lib/disk_mem_slow_syn.lib ./lib/fifo_mem_slow_syn.lib ./lib/insn_mem_slow_syn.lib
set_db init_hdl_search_path ../
read_hdl alu.v
read_hdl branch.v
read_hdl bus.v
read_hdl dbg.v
read_hdl dcache.v
read_hdl ev.v
read_hdl i2s.v
read_hdl lpc.v
read_hdl mp.v
read_hdl pic.v
read_hdl sdhci.v
read_hdl soc.v
read_hdl tcm.v
read_hdl i2c.v
elaborate
gui_raise
define_clock -name clk -period 8000 clk
report_timing
