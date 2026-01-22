# workflow
to create project
- search for 236, speed = -1

to compile and run on board
1. run synthessi
2. run implementation
3. generate bitstream
4. open hardware manager
	- auto connect
5. program device (popup should be for a .bit file)

to run simulation code only (not using FPGA)
1. run simulation
2. run all
3. see TCL console

# todo
project at Desktop/student/taiyu_lab1/taiyu_lab1.xpr

what to do next: 
- [x] go figure out the /r check
    - to see the stuff for workshop 2 lab 1, run simulation
    - see TcL console "UART0 Received byte 30 (0)..."
    - need to have tb (tb.v) set as top module (run simulation, then run all)
- [x] figure out why fib bad 
