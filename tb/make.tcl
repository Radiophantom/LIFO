vlib work
vlog -sv {../rtl/lifo.sv}
vlog -sv {./lifo_tb.sv}
vsim lifo_tb
do wave.do
run -all