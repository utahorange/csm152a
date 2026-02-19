// used as top moduel when flashing to fpga
module basys3 (/*AUTOARG*/
    // Outputs
    output [6:0] seg, output [3:0] an,
    // Inputs
    input [1:0] sw, input clk, input btnS, input btnR
    );

    // need buttons 
    wire clock_1HZ;
    wire clock_2HZ;
    wire clock_50MHZ;

    clock_generator clock_gen ( .clk(clk), 
                                .clk_1HZ (clock_1HZ), 
                                .clk_2HZ(clock_2HZ), 
                                .clk_50MHZ(clock_50MHZ) );

    lab3_clock main_counter ( .clk(clk),
                              .clk_1HZ(clock_1HZ), 
                              .clk_2HZ(clock_2HZ), 
                              .clk_50MHZ(clock_50MHZ),
                              .btnReset(btnR),
                              .btnPause(btnS),
                              .swAdjust(sw[0]),
                              .swSelect(sw[1]),
                              .seg(seg), 
                              .an(an) );
   
endmodule


