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
- [ ] code up fib for first 10 nums




fib.code

r0 = 1
r1 = 2
r2 = 0 // old value of R1
r3 = 0 // always 0

r3 + r1 = r2
r0 + r1 = r1
r3 + r2 = r0 // r0 = old r1

print(r1)