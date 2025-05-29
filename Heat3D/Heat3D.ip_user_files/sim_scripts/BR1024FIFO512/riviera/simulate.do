onbreak {quit -force}
onerror {quit -force}

asim +access +r +m+BR1024FIFO512 -L xpm -L fifo_generator_v13_2_7 -L xil_defaultlib -L unisims_ver -L unimacro_ver -L secureip -O5 xil_defaultlib.BR1024FIFO512 xil_defaultlib.glbl

set NumericStdNoWarnings 1
set StdArithNoWarnings 1

do {wave.do}

view wave
view structure

do {BR1024FIFO512.udo}

run -all

endsim

quit -force
