# lab 3

making a stopwatch using 7 segment display (minutes, seconds)

4 control signals:
- reset button
- pause button: toggle
- ADJ switches: if on, go in to adjust mode -> freeze one section, cycle thru other section at 2hz with blinking
	- normally, you increment the section at 1 hz
- SEL switches: select btwn adjusting minutes 



need to divide down the clock
- second counting speed (1 Hz)
- adjusting speed (2 Hz)
- blinking speed (greater than 1 Hz, but cannot be 2 Hz)
- display multiplexing speed (50-700 Hz)

have a stopwatch module

use always@(posedge) clk



main clock module

<!-- instantiate digit 1 module
instantiate digit 2 module
instantiate digit 1 module
instantiate digit 2 module -->


<!-- seconds digit 1
seconds digit 2
minutes digit 1
minutes digit 2 -->

mian loop is run at 100 MHz

	always at posedge clk detect, inc counter

	<!-- give counter to "produce 4 seg 7 codes from binary number" module -->

	from seconds digit 1 counter, update clock0 (0-9 but we are waiting for 1) pass counter
	from seconds digit 2, update clock1 (0-5 but we are waiting for 10) pass counter 
	from minutes digit 1, update clock2 (0-9 but we are waiting for 60) pass counter
	from minutes digit 2, update clock3 (0-9 but we are waiting for 600) pass counter

	display digits and do digit cycle


"produce 4 seg 7 codes from binary number" module (counter, minutes 1, minutes 2, seconds 1, seconds 2) {
	if seconds is 10, inc seconds

}


while true
	integer i
	for i in 0, 3:
		set seg value to the digit -> look at minute1, minute2....
		turn off all anodes (or just the prev anode that was on)
		turn on just the anode we want

:/opt/Xilinx/2025.2/data/xicom/cable_drivers/lin64/install_script/install_drivers$