// The `timescale directive specifies what the
// simulation time units are (1 ns here) and what
// the simulator time step should be (1 ps here).

`timescale 1 ns / 1 ps

// Declare the module and its ports. This is
// using Verilog-2001 syntax.

module vga_display(
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
  input wire btnCenter,
  input wire [7:0] sw,

  output wire [6:0] seg,
  output wire [3:0] an

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

    localparam integer TOP_EDGE = 200;
    localparam integer STICK_HEIGHT = 150;
    localparam integer STICK_WIDTH = 64;
    localparam integer STICK_SPACING = 32;
    localparam integer NUM_STICKS = 8;

    // 8 stick positions: 80 bits = 8 x 10-bit coords. stick 0 = [9:0], stick 1 = [19:10], ... stick 7 = [79:70].
    // X: 32, 128, 224, 320, 416, 512, 608, 704.  Y: 300 for all (TOP_EDGE - STICK_HEIGHT).
    reg [79:0] sticks_x = {10'd704, 10'd608, 10'd512, 10'd416, 10'd320, 10'd224, 10'd128, 10'd32};

    localparam [9:0] STICK_Y_VALUE = 80;
    localparam [9:0] MAX_STICK_Y = 330;   // 480 - STICK_HEIGHT, keep on screen
    localparam [31:0] FALL_DIVIDER = 32'd160_000; // at 40 MHz: larger = slower fall (~4 ms/pixel for longer fall)

    reg [79:0] sticks_y = {
        STICK_Y_VALUE, STICK_Y_VALUE, STICK_Y_VALUE, STICK_Y_VALUE,
        STICK_Y_VALUE, STICK_Y_VALUE, STICK_Y_VALUE, STICK_Y_VALUE
    };
    reg [31:0] fall_counter = 0;

    wire [3:0] stick_number;
    within_stick within_stick_check(.hcount(hcount), 
                                    .vcount(vcount), 
                                    .sticks_x(sticks_x), 
                                    .sticks_y(sticks_y), 
                                    .NUM_STICKS(NUM_STICKS),
                                    .stick_w(STICK_WIDTH), 
                                    .stick_h(STICK_HEIGHT),
                                    .stick_number(stick_number)); 
        // output is stick_number, 0-7 for within a stick, 8 for not within any stick
    
    // Wire game_fsm outputs (stick_states, game_state, etc.) for VGA and display
    wire [23:0] stick_states;
    wire [1:0] game_state;
    wire [3:0] difficulty_level;
    wire game_finished;
    wire within_text;
    
    within_text_rom start_text_rom( .clk(pclk), 
                                            .hcount(hcount), 
                                            .vcount(vcount),
                                            .is_in_set(within_text));

    // RGB: blanking = black; start screen = dim background; sticks = color by state; gaps = black
    reg [3:0] r_next, g_next, b_next;
    always @(*) begin
        if (hblnk || vblnk) begin
            r_next = 4'h0; 
            g_next = 4'h0; 
            b_next = 4'h0;
        end else if (game_state == 2'b00) begin
            
            /* New Pseudocode:
                 - Use the within_text_rom module to check if (hcount, vcount) is within the "START" text area
                 - If within_text_rom outputs 1, output white; else output dark blue
            */
            
            if (within_text) begin
                r_next = 4'hf; g_next = 4'hf; b_next = 4'hf; // white for text
            end else begin
                r_next = 4'h1; g_next = 4'h2; b_next = 4'h4; // dark blue background
            end

        end else if (game_state == 2'b11) begin
            // Game over: dim background
            r_next = 4'h2; g_next = 4'h2; b_next = 4'h2;
        end else if (stick_number != 4'd8) begin
            // Within a stick: color by stick state (000=white, 001=yellow, 010=green, 011=red)
            case (stick_states[stick_number*3 +: 3])
                3'b000: begin r_next = 4'hf; g_next = 4'hf; b_next = 4'hf; end  // white
                3'b001: begin r_next = 4'hf; g_next = 4'hf; b_next = 4'h0; end  // yellow
                3'b010: begin r_next = 4'h0; g_next = 4'hf; b_next = 4'h0; end  // green
                3'b011: begin r_next = 4'hf; g_next = 4'h0; b_next = 4'h0; end  // red
                default: begin r_next = 4'ha; g_next = 4'ha; b_next = 4'ha; end
            endcase
        end else begin
            r_next = 4'h0; g_next = 4'h0; b_next = 4'h0;  // black between sticks
        end
    end
    always @(posedge pclk) {r,g,b} <= {r_next, g_next, b_next};

    // wire the input processor module to the buttons and switches
    wire btnRight_pulse, btnLeft_pulse, btnUp_pulse, btnDown_pulse, btnCenter_pulse;
    wire btnRight_level, btnLeft_level, btnUp_level, btnDown_level, btnCenter_level;
    wire btnRight_toggle, btnLeft_toggle, btnUp_toggle, btnDown_toggle, btnCenter_toggle;

    input_proc btnRight_input(.clk(pclk), .reset(1'b0), .button_in(btnRight), 
        .button_level(btnRight_level), .button_pulse(btnRight_pulse), .button_toggle(btnRight_toggle));

    input_proc btnLeft_input(.clk(pclk), .reset(1'b0), .button_in(btnLeft), 
        .button_level(btnLeft_level), .button_pulse(btnLeft_pulse), .button_toggle(btnLeft_toggle));

    input_proc btnUp_input(.clk(pclk), .reset(1'b0), .button_in(btnUp), 
        .button_level(btnUp_level), .button_pulse(btnUp_pulse), .button_toggle(btnUp_toggle));

    input_proc btnDown_input(.clk(pclk), .reset(1'b0), .button_in(btnDown), 
        .button_level(btnDown_level), .button_pulse(btnDown_pulse), .button_toggle(btnDown_toggle));

    input_proc btnCenter_input(.clk(pclk), .reset(1'b0), .button_in(btnCenter), 
        .button_level(btnCenter_level), .button_pulse(btnCenter_pulse), .button_toggle(btnCenter_toggle));

    // Current stick's Y position (for FSM to know when stick has stopped falling)
    wire [9:0] current_stick_y = (current_stick == 3'd0) ? sticks_y[ 9: 0] :
                                 (current_stick == 3'd1) ? sticks_y[19:10] :
                                 (current_stick == 3'd2) ? sticks_y[29:20] :
                                 (current_stick == 3'd3) ? sticks_y[39:30] :
                                 (current_stick == 3'd4) ? sticks_y[49:40] :
                                 (current_stick == 3'd5) ? sticks_y[59:50] :
                                 (current_stick == 3'd6) ? sticks_y[69:60] :
                                 sticks_y[79:70];
    wire stick_reached_bottom = (current_stick_y >= MAX_STICK_Y);

    game_fsm my_game_fsm(
        .clk(pclk),
        .start_button(btnCenter_level),
        .right_button_pulse(btnRight_pulse),
        .left_button_pulse(btnLeft_pulse),
        .sw(sw),
        .stick_reached_bottom(stick_reached_bottom),
        .stick_states(stick_states),
        .game_state(game_state),
        .current_stick(current_stick),
        .difficulty_level(difficulty_level),
        .game_finished(game_finished),
        .seg(seg),
        .an(an)
    );

    // Fall tick: advance every FALL_DIVIDER cycles, but only during Dropping state (game_state == 2'b10)
    wire in_dropping_state = (game_state == 2'b10);
    wire fall_tick = in_dropping_state && (fall_counter == FALL_DIVIDER - 1);

    // Next Y for each stick: if yellow and not at max, increment; else keep current
    wire [9:0] next_y0 = (stick_states[2:0] == 3'b001 && sticks_y[ 9: 0] < MAX_STICK_Y) ? sticks_y[ 9: 0] + 1 : sticks_y[ 9: 0];
    wire [9:0] next_y1 = (stick_states[5:3] == 3'b001 && sticks_y[19:10] < MAX_STICK_Y) ? sticks_y[19:10] + 1 : sticks_y[19:10];
    wire [9:0] next_y2 = (stick_states[8:6] == 3'b001 && sticks_y[29:20] < MAX_STICK_Y) ? sticks_y[29:20] + 1 : sticks_y[29:20];
    wire [9:0] next_y3 = (stick_states[11:9] == 3'b001 && sticks_y[39:30] < MAX_STICK_Y) ? sticks_y[39:30] + 1 : sticks_y[39:30];
    wire [9:0] next_y4 = (stick_states[14:12] == 3'b001 && sticks_y[49:40] < MAX_STICK_Y) ? sticks_y[49:40] + 1 : sticks_y[49:40];
    wire [9:0] next_y5 = (stick_states[17:15] == 3'b001 && sticks_y[59:50] < MAX_STICK_Y) ? sticks_y[59:50] + 1 : sticks_y[59:50];
    wire [9:0] next_y6 = (stick_states[20:18] == 3'b001 && sticks_y[69:60] < MAX_STICK_Y) ? sticks_y[69:60] + 1 : sticks_y[69:60];
    wire [9:0] next_y7 = (stick_states[23:21] == 3'b001 && sticks_y[79:70] < MAX_STICK_Y) ? sticks_y[79:70] + 1 : sticks_y[79:70];

    always @(posedge pclk) begin
        // In Wait state, reset stick positions and fall counter
        if (game_state == 2'b00) begin
            sticks_y <= {8{STICK_Y_VALUE}};
            fall_counter <= 0;
        end else if (in_dropping_state) begin
            // Only advance falling sticks and fall counter while in Dropping state
            if (fall_tick) begin
                sticks_y <= {next_y7, next_y6, next_y5, next_y4, next_y3, next_y2, next_y1, next_y0};
                fall_counter <= 0;
            end else begin
                fall_counter <= fall_counter + 1;
            end
        end
    end

endmodule