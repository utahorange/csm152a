// File: vga_example.v
// This is the top level design for EE178 Lab #4.

// The `timescale directive specifies what the
// simulation time units are (1 ns here) and what
// the simulator time step should be (1 ps here).

`timescale 1 ns / 1 ps

// Declare the module and its ports. This is
// using Verilog-2001 syntax.

module vga_example (
  input wire clk,
  output reg vs,
  output reg hs,
  output reg [3:0] r,
  output reg [3:0] g,
  output reg [3:0] b,
  output wire pclk_mirror,

  input wire btnMiddle,
    input wire btnUp,
    input wire btnDown,
    input wire btnLeft,
    input wire btnRight,
    input wire [7:0] sw,

  output reg [7:0] seg,
  output reg [3:0] an

  );

  // Converts 100 MHz clk into 40 MHz pclk.
  // This uses a vendor specific primitive
  // called MMCME2, for frequency synthesis.

  wire clk_in;
  wire locked;
  wire clk_fb;
  wire clk_ss;
  wire clk_out;
  wire pclk;
  (* KEEP = "TRUE" *) 
  (* ASYNC_REG = "TRUE" *)
  reg [7:0] safe_start = 0;

  IBUF clk_ibuf (.I(clk),.O(clk_in));

  MMCME2_BASE #(
    .CLKIN1_PERIOD(10.000),
    .CLKFBOUT_MULT_F(10.000),
    .CLKOUT0_DIVIDE_F(25.000))
  clk_in_mmcme2 (
    .CLKIN1(clk_in),
    .CLKOUT0(clk_out),
    .CLKOUT0B(),
    .CLKOUT1(),
    .CLKOUT1B(),
    .CLKOUT2(),
    .CLKOUT2B(),
    .CLKOUT3(),
    .CLKOUT3B(),
    .CLKOUT4(),
    .CLKOUT5(),
    .CLKOUT6(),
    .CLKFBOUT(clkfb),
    .CLKFBOUTB(),
    .CLKFBIN(clkfb),
    .LOCKED(locked),
    .PWRDWN(1'b0),
    .RST(1'b0)
  );

  BUFH clk_out_bufh (.I(clk_out),.O(clk_ss));
  always @(posedge clk_ss) safe_start<= {safe_start[6:0],locked};

  BUFGCE clk_out_bufgce (.I(clk_out),.CE(safe_start[7]),.O(pclk));

  // Mirrors pclk on a pin for use by the testbench;
  // not functionally required for this design to work.

  ODDR pclk_oddr (
    .Q(pclk_mirror),
    .C(pclk),
    .CE(1'b1),
    .D1(1'b1),
    .D2(1'b0),
    .R(1'b0),
    .S(1'b0)
  );

  // Instantiate the vga_timing module, which is
  // the module you are designing for this lab.

  wire [10:0] vcount, hcount;
  wire vsync, hsync;
  wire vblnk, hblnk;

  vga_timing my_timing (
    .vcount(vcount),
    .vsync(vsync),
    .vblnk(vblnk),
    .hcount(hcount),
    .hsync(hsync),
    .hblnk(hblnk),
    .pclk(pclk)
  );

  // Drive sync outputs to the VGA connector (were never connected!)
  always @(posedge pclk) begin
    vs <= vsync;
    hs <= hsync;
  end

    localparam integer TOP_EDGE = 570;
    localparam integer STICK_HEIGHT = 270;
    localparam integer STICK_WIDTH = 64;
    localparam integer STICK_SPACING = 32;
    localparam integer NUM_STICKS = 8;

    // 8 stick positions: 80 bits = 8 x 10-bit coords. stick 0 = [9:0], stick 1 = [19:10], ... stick 7 = [79:70].
    // X: 32, 128, 224, 320, 416, 512, 608, 704.  Y: 300 for all (TOP_EDGE - STICK_HEIGHT).
    reg [79:0] sticks_x = {10'd704, 10'd608, 10'd512, 10'd416, 10'd320, 10'd224, 10'd128, 10'd32};
    reg [79:0] sticks_y = {10'd300, 10'd300, 10'd300, 10'd300, 10'd300, 10'd300, 10'd300, 10'd300};
    

    wire [3:0] stick_number;
    within_stick within_stick_check(.hcount(hcount), 
                                    .vcount(vcount), 
                                    .sticks_x(sticks_x), 
                                    .sticks_y(sticks_y), 
                                    .NUM_STICKS(NUM_STICKS),
                                    .stick_w(STICK_WIDTH), 
                                    .stick_h(STICK_HEIGHT),
                                    .stick_number(stick_number));
    // RGB must be registered on pclk to match hcount/vcount (same domain as timing)
    always @(posedge pclk)
    begin
        if (hblnk || vblnk)
            {r,g,b} <= 12'h0_0_0;   // black during blanking
        else if (stick_number != 8) // within a stick
            {r,g,b} <= 12'hf_0_0;
        else // NOT within a stick
            {r,g,b} <= 12'ha_a_a;
    end

endmodule


module game_fsm(
    input wire clk,
    input wire start_button, // input signal from U18 button
    input wire right_button, // input signal from T17 button
    input wire left_button, // input signal from W19 button
    input wire [23:0] stick_states, // 3 bits per stick (8 of them)
        // format: first three bits define stick 0's state
        //      next three bits define stick 1's state, and so on
        // each 3 bits are defined as: 000 = white, 001 = yellow, 010 = green, 
        // 011 = red, 100 = gray (disappears into background)
    
    output reg [7:0] seg, // BCD display output
    output reg [3:0] an,   // Anode control for 4-digit 7-segment display
    output reg [1:0] game_state,  // 00 = Wait (haven't started game), 
                            // 01 = Start (countdown), 
                            // 10 = Dropping (in game),
                            // 11 = Game over (game finished)
    output reg [3:0] difficulty_level,
    output reg [1:0] game_finished
);

    reg [1:0] next_state;

    // State transition logic
    always @(posedge clk) begin
        game_state <= next_state;
    end

    // Next state logic
    always @(*) begin
        case (game_state)
            2'b00: begin
                if (start_button) begin
                    next_state = 2'b01; // Transition to Start state on button press
                end else begin
                    next_state = 2'b00; // Stay in Wait state
                end

                // change the difficulty_level based on right and left button presses
                if (right_button && difficulty_level < 4'b1111) begin
                    difficulty_level = difficulty_level + 1; // Increase difficulty level
                end else if (left_button && difficulty_level > 4'b0000) begin
                    difficulty_level = difficulty_level - 1; // Decrease difficulty level
                end

            end
            2'b01: begin
                // Add game logic to determine when to transition to GAME_OVER
                next_state = 2'b10; // Placeholder, replace with actual condition
            end
            2'b10: begin
                // Add game logic to determine when to transition to GAME_OVER
                game_finished = 1; // assume all sticks are red or green
                // if ALL sticks are red OR green, then go to the 2'b11
                    // walk through all the sticks to determine if they're ALL red or green
                // this is a flag called "game_finished"
                    // walk through all the stick states; if any are yellow or white, set it to false
                
                
                if (stick_states[3*0 +: 3] == 3'b000 || stick_states[3*0 +: 3] == 3'b001) begin
                    game_finished = 0;
                end
                if (stick_states[3*1 +: 3] == 3'b000 || stick_states[3*1 +: 3] == 3'b001) begin
                    game_finished = 0;
                end
                if (stick_states[3*2 +: 3] == 3'b000 || stick_states[3*2 +: 3] == 3'b001) begin
                    game_finished = 0;
                end
                if (stick_states[3*3 +: 3] == 3'b000 || stick_states[3*3 +: 3] == 3'b001) begin
                    game_finished = 0;
                end
                if (stick_states[3*4 +: 3] == 3'b000 || stick_states[3*4 +: 3] == 3'b001) begin
                    game_finished = 0;
                end
                if (stick_states[3*5 +: 3] == 3'b000 || stick_states[3*5 +: 3] == 3'b001) begin
                    game_finished = 0;
                end
                if (stick_states[3*6 +: 3] == 3'b000 || stick_states[3*6 +: 3] == 3'b001) begin
                    game_finished = 0;
                end
                if (stick_states[3*7 +: 3] == 3'b000 || stick_states[3*7 +: 3] == 3'b001) begin
                    game_finished = 0;
                end
                


                if (game_finished) begin
                    next_state = 2'b11; // Transition to Game Over state if all sticks are red or green
                end else begin
                    next_state = 2'b10; // Stay in Dropping state
                end

            end
            2'b11: begin
                // Add logic to reset the game or return to START_SCREEN
                
                next_state = 2'b00; // Placeholder, replace with actual condition
            end
            default: next_state = 2'b00; // Default to Wait state
        endcase
    end

    // Output logic based on current state and difficulty level
    always @(posedge clk) begin
        case (game_state)
            2'b00: begin
                // Display start screen and difficulty level on BCD display
                an <= 4'b1110; // Enable first digit for difficulty level display
            end
            default: begin
                seg <= 7'b1111111; // Default display output
                an <= 4'b1111; // Default anode control
            end
        endcase
    end

    // Segment Decoder (Active Low for Basys3)
    always @(*) begin
        case(difficulty_level)
            4'b0000: seg = 7'b1000000; // "0"
            4'b0001: seg = 7'b1111001; // "1"
            4'b0010: seg = 7'b0100100; // "2"
            4'b0011: seg = 7'b0110000; // "3"
            4'b0100: seg = 7'b0011001; // "4"
            4'b0101: seg = 7'b0010010; // "5"
            4'b0110: seg = 7'b0000010; // "6"
            4'b0111: seg = 7'b1111000; // "7"
            4'b1000: seg = 7'b0000000; // "8"
            4'b1001: seg = 7'b0010000; // "9"
            default: seg = 7'b1111111; // Off
        endcase
    end



endmodule


// GPT-Generated code for user controls and difficulty levels. This is a placeholder and should be modified based on actual button inputs and display requirements.

/*
// Parameters for user controls and difficulty levels
  input wire left_button, // Left button signal
  input wire right_button; // Right button signal

  // Registers for difficulty level and Start screen state
  reg [3:0] difficulty = MIN_DIFFICULTY; // Default difficulty level
  reg start_screen = 1'b1; // Start screen active by default

  // Debounced button signals
  reg left_button_debounced;
  reg right_button_debounced;

  // Button press detection
  always @(posedge pclk) begin
    if (start_screen) begin
      // Debounce logic for left button
      left_button_debounced <= left_button;

      // Debounce logic for right button
      right_button_debounced <= right_button;

      // Adjust difficulty level based on button presses
      if (left_button_debounced && difficulty > MIN_DIFFICULTY) begin
        difficulty <= difficulty - 1;
      end else if (right_button_debounced && difficulty < MAX_DIFFICULTY) begin
        difficulty <= difficulty + 1;
      end
    end
  end

  // Display logic for Start screen and difficulty level
  always @(posedge pclk) begin
    if (start_screen) begin
      // Display Start screen and difficulty level on BCD display
      // Placeholder logic for BCD display
      // Add your BCD display module instantiation here
    end
  end
*/

module input_proc (
    input  wire clk,          // slow clock (1kHz-10kHz ideal)
    input  wire reset,
    input  wire button_in,     // asynchronous, noisy input

    output reg  button_level,  // debounced level
    output reg  button_pulse,  // 1-clock pulse on rising edge
    output reg  button_toggle  // toggles on each press
);

    // =========================
    // Synchronizer
    // =========================
    reg sync_0, sync_1;

    always @(posedge clk) begin
        sync_0 <= button_in;
        sync_1 <= sync_0;
    end

    // =========================
    // Debouncer
    // =========================
    localparam integer DEBOUNCE_COUNT = 20; // ~20 ms @ 1 kHz
    integer debounce_cnt = 0;
    reg debounced = 0;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            debounce_cnt <= 0;
            debounced    <= 0;
        end else begin
            if (sync_1 == debounced) begin
                debounce_cnt <= 0;
            end else begin
                if (debounce_cnt == DEBOUNCE_COUNT - 1) begin
                    debounced    <= sync_1;
                    debounce_cnt <= 0;
                end else begin
                    debounce_cnt <= debounce_cnt + 1;
                end
            end
        end
    end

    // =========================
    // Edge detection
    // =========================
    reg debounced_d;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            debounced_d   <= 0;
            button_pulse  <= 0;
            button_toggle <= 0;
            button_level  <= 0;
        end else begin
            debounced_d  <= debounced;
            button_level <= debounced;

            // Rising edge detect
            button_pulse <= debounced & ~debounced_d;

            // Toggle on rising edge
            if (debounced & ~debounced_d)
                button_toggle <= ~button_toggle;
        end
    end
endmodule

module within_stick(
    input wire [10:0] hcount,
    input wire [10:0] vcount,
    // 80 bits = 8 sticks x 10-bit coords. stick i at bits [10*i+9 : 10*i]
    input wire [79:0] sticks_x,
    input wire [79:0] sticks_y,
    input wire [4:0] NUM_STICKS,
    input wire [10:0] stick_w,
    input wire [10:0] stick_h,
    output reg [3:0] stick_number  // 8 = not in any stick
);
    wire [9:0] s0_x = sticks_x[ 9: 0], s0_y = sticks_y[ 9: 0];
    wire [9:0] s1_x = sticks_x[19:10], s1_y = sticks_y[19:10];
    wire [9:0] s2_x = sticks_x[29:20], s2_y = sticks_y[29:20];
    wire [9:0] s3_x = sticks_x[39:30], s3_y = sticks_y[39:30];
    wire [9:0] s4_x = sticks_x[49:40], s4_y = sticks_y[49:40];
    wire [9:0] s5_x = sticks_x[59:50], s5_y = sticks_y[59:50];
    wire [9:0] s6_x = sticks_x[69:60], s6_y = sticks_y[69:60];
    wire [9:0] s7_x = sticks_x[79:70], s7_y = sticks_y[79:70];

    always @(*) begin
        if ((hcount >= s0_x) && (hcount < s0_x + stick_w) && (vcount >= s0_y) && (vcount < s0_y + stick_h))
            stick_number <= 0;
        else if ((hcount >= s1_x) && (hcount < s1_x + stick_w) && (vcount >= s1_y) && (vcount < s1_y + stick_h))
            stick_number <= 1;
        else if ((hcount >= s2_x) && (hcount < s2_x + stick_w) && (vcount >= s2_y) && (vcount < s2_y + stick_h))
            stick_number <= 2;
        else if ((hcount >= s3_x) && (hcount < s3_x + stick_w) && (vcount >= s3_y) && (vcount < s3_y + stick_h))
            stick_number <= 3;
        else if ((hcount >= s4_x) && (hcount < s4_x + stick_w) && (vcount >= s4_y) && (vcount < s4_y + stick_h))
            stick_number <= 4;
        else if ((hcount >= s5_x) && (hcount < s5_x + stick_w) && (vcount >= s5_y) && (vcount < s5_y + stick_h))
            stick_number <= 5;
        else if ((hcount >= s6_x) && (hcount < s6_x + stick_w) && (vcount >= s6_y) && (vcount < s6_y + stick_h))
            stick_number <= 6;
        else if ((hcount >= s7_x) && (hcount < s7_x + stick_w) && (vcount >= s7_y) && (vcount < s7_y + stick_h))
            stick_number <= 7;
        else
            stick_number <= 8;
    end
endmodule
