onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /lifo_tb/clk_i
add wave -noupdate /lifo_tb/srst_i
add wave -noupdate /lifo_tb/wrreq_i
add wave -noupdate /lifo_tb/data_i
add wave -noupdate /lifo_tb/rdreq_i
add wave -noupdate /lifo_tb/q_o
add wave -noupdate /lifo_tb/empty_o
add wave -noupdate /lifo_tb/full_o
add wave -noupdate -radix unsigned /lifo_tb/usedw_o
add wave -noupdate /lifo_tb/lifo/almost_empty_o
add wave -noupdate /lifo_tb/lifo/almost_full_o
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {1136481 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 150
configure wave -valuecolwidth 100
configure wave -justifyvalue right
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ns
update
WaveRestoreZoom {0 ps} {1328250 ps}
