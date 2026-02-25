# final project notes
- [vga display code](https://github.com/muhammadaldacher/FPGA-Design-of-a-Digital-Analog-Clock-Display-using-Digilent-Basys3-Artix-7/tree/master/LAB4_Display%20on%20VGA)





how would we be able to update only one rectangle at a time

our state changes are only full rectangles


catching early causes stick to be red as well



a stick has states of:
- not dropped (white)
- being dropped (yellow)
- caught (green)
- not caught (red)

// list of bottom left corners of sticks
reg [3:0] [] sticks_x // list of stick x coords
reg [3:0] [] sticks_y // list of stick y coords

// keep track of global stick_states passed to vga 


module game_logic () {

    
}


module vga_example (reg [2:0] [1:0] stick_states){
        stick1
        stick2
        stick3
        stick4
        stick5
        stick6...

    always posedge clk {
        assign stick_index = within_stick(hcount,vcount);
        if (stick_index != 0) {
            switch stick_states[stick_index] 
                case '00 
                    <= rgb 
                ...
        }
        <!-- normal is gray -->
    }
}

module within_stick(input x,y, output reg 0 if not in rectangle, some 0 < n < 9 if is) {
    loop thru stick_x and stick_y to check if x, y in any stick
    return num
}