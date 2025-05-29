onbreak {quit -f}
onerror {quit -f}

vsim -lib xil_defaultlib BR1024FIFO16_opt

set NumericStdNoWarnings 1
set StdArithNoWarnings 1

do {wave.do}

view wave
view structure
view signals

do {BR1024FIFO16.udo}

run -all

quit -force
