// used as top moduel when flashing to fpga
module basys3 (/*AUTOARG*/
    // Outputs
    output [6:0] seg, output [3:0] an,
    // Inputs
    input sw_increment, input sw_reset, input clk
    );

    // need buttons 
    wire clock_1HZ;
    wire clock_2HZ;
    wire clock_50MHZ;

    clock_generator clock_gen ( .clk(clk), .clk_1HZ (clock_1HZ), .clk_2HZ(clock_2HZ), .clk_50MHZ(clock_50MHZ) );
    lab3_clock main_counter ( .clk_1HZ(clock_1HZ), .clk_2HZ(clock_2HZ), .clk_50MHZ(clock_50MHZ), .seg(seg), .an(an) );
   
endmodule


