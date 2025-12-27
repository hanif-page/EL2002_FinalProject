onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -radix decimal /tb_complex_mult/uut/clk
add wave -noupdate -radix decimal /tb_complex_mult/uut/i_data_re
add wave -noupdate -radix decimal /tb_complex_mult/uut/i_data_im
add wave -noupdate -radix decimal /tb_complex_mult/uut/i_w_re
add wave -noupdate -radix decimal /tb_complex_mult/uut/i_w_im
add wave -noupdate -radix decimal /tb_complex_mult/uut/o_res_re
add wave -noupdate -radix decimal /tb_complex_mult/uut/o_res_im
add wave -noupdate -radix decimal /tb_complex_mult/uut/s_data_re
add wave -noupdate -radix decimal /tb_complex_mult/uut/s_data_im
add wave -noupdate -radix decimal /tb_complex_mult/uut/s_w_re
add wave -noupdate -radix decimal /tb_complex_mult/uut/s_w_im
add wave -noupdate -radix decimal /tb_complex_mult/uut/s_res_re_long
add wave -noupdate -radix decimal /tb_complex_mult/uut/s_res_im_long
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {121427 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 248
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 0
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ps
update
WaveRestoreZoom {0 ps} {188245 ps}
