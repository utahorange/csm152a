// used as top moduel when flashing to fpga
module basys3 (/*AUTOARG*/
    // Outputs
    output [6:0] seg, output [3:0] an,
    // Inputs
    input [1:0] sw, input clk, input btnS, input btnR
    );

    // need buttons 
    wire clock_1HZ; // normal 
    wire clock_2HZ; // adjustment clock
    wire clock_1_5_HZ; // blinking clock
    wire clock_50MHZ; // display clock

    wire pause_tog;

    clock_generator clock_gen ( .clk(clk), 
                                .clk_1HZ (clock_1HZ), 
                                .clk_2HZ(clock_2HZ), 
                                .clk_50MHZ(clock_50MHZ),
                                .clk_1_5_HZ(clock_1_5_HZ));

    input_proc pause_debounce( .clk(clock_1_5_HZ),
                                .reset(btnR),
                                .button_in(btnS),
                                .button_toggle(pause_tog));

    // Switches are level signals - use directly, no debouncing needed
    lab3_clock main_counter ( .clk_normal(clock_1HZ), 
                              .clk_adjust(clock_2HZ), 
                              .clk_display(clock_50MHZ),
                              .clk_blink(clock_1_5_HZ),
                              .reset(btnR),
                              .pause(pause_tog),
                              .adjust(sw[0]),  // Switch: level signal
                              .select(sw[1]), // Switch: level signal
                              .seg(seg), 
                              .an(an) );

endmodule


