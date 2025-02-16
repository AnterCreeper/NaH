read_libs ./lib/slow.lib ./lib/fifo_mem_slow_syn.lib ./lib/buf_mem_slow_syn.lib
set_db init_hdl_search_path ../
read_hdl lpc.v
elaborate
gui_raise
define_clock -name clk -period 8000 clk
report_timing
#syn_generic
#syn_map
#syn_opt
#write_netlist lpc > lpc_netlist.v
