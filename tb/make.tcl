vlib work
vlog -sv ../rtl/lifo.sv
vlog -sv ./lifo_tb.sv
vopt +acc -o lifo_tb_opt lifo_tb
vsim lifo_tb_opt
do wave.do
run -all
