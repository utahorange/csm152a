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
    localparam [31:0] FALL_DIVIDER = 32'd40_000;  // ~1 ms at 40 MHz -> 1 pixel/ms fall rate

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

    // RGB: blanking = black; start screen = dim background; sticks = color by state; gaps = black
    reg [3:0] r_next, g_next, b_next;
    always @(*) begin
        if (hblnk || vblnk) begin
            r_next = 4'h0; g_next = 4'h0; b_next = 4'h0;
        end else if (game_state == 2'b00) begin
            // Start screen: simple colored background (e.g. dark blue) when in WAIT
            r_next = 4'h1; g_next = 4'h2; b_next = 4'h4;
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

    game_fsm my_game_fsm(
        .clk(pclk),
        .start_button(btnCenter_level),
        .right_button_pulse(btnRight_pulse),
        .left_button_pulse(btnLeft_pulse),
        .sw(sw),
        .stick_states(stick_states),
        .game_state(game_state),
        .difficulty_level(difficulty_level),
        .game_finished(game_finished),
        .seg(seg),
        .an(an)
    );

    // Fall tick: advance every FALL_DIVIDER cycles when not in Wait
    wire fall_tick = (fall_counter == FALL_DIVIDER - 1);

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
        if (game_state == 2'b00) begin
            sticks_y <= {8{STICK_Y_VALUE}};
            fall_counter <= 0;
        end else if (fall_tick) begin
            sticks_y <= {next_y7, next_y6, next_y5, next_y4, next_y3, next_y2, next_y1, next_y0};
            fall_counter <= 0;
        end else begin
            fall_counter <= fall_counter + 1;
        end
    end

endmodule


module game_fsm(
    input wire clk,
    input wire start_button,
    input wire right_button_pulse,
    input wire left_button_pulse,
    input wire [7:0] sw,

    output reg [23:0] stick_states,  // 3 bits per stick: 000=white, 001=yellow, 010=green, 011=red
    output reg [1:0] game_state,     // 00=Wait, 01=Countdown, 10=Dropping, 11=GameOver
    output reg [3:0] difficulty_level,
    output reg game_finished,

    output reg [6:0] seg,
    output reg [3:0] an
);

    // --- Timers: 40 MHz -> 1 sec = 40_000_000 cycles; 1 ms = 40_000 cycles ---
    localparam [31:0] ONE_SEC = 32'd40_000_000;
    localparam [31:0] ONE_MS  = 32'd40_000;
    localparam [31:0] RESULT_WAIT = 32'd80_000_000;  // 2 sec between sticks

    // Catch window: inversely proportional to difficulty. 1-9: 2000 - level*100 ms (min 1100 at level 9)
    wire [31:0] catch_time_ms = 32'd2000 - {28'd0, difficulty_level} * 32'd100;
    wire [31:0] catch_ticks = catch_time_ms * ONE_MS;

    reg [1:0] next_state;
    reg [31:0] timer;
    reg [1:0] countdown_val;   // 3, 2, 1
    reg [2:0] current_stick;   // which stick is yellow (0..7)
    reg sw_was_zero_at_start;  // required: switch was 0 when stick turned yellow
    reg caught;                // 0->1 on correct switch during window
    reg [3:0] score;
    reg [15:0] lfsr;           // for random stick choice
    reg [19:0] difficulty_cooldown;  // ignore extra pulses after one difficulty change (~10 ms at 40 MHz)

    localparam [19:0] DIFF_COOLDOWN_CYCLES = 20'd400_000;

    // Synchronize slide switches to clk to avoid missing transitions (async input).
    reg [7:0] sw_sync_0 = 8'h00;
    reg [7:0] sw_sync_1 = 8'h00;
    reg [7:0] sw_s      = 8'h00;
    reg [7:0] sw_s_d    = 8'h00;  // delayed sample for edge detect

    always @(posedge clk) begin
        sw_sync_0 <= sw;
        sw_sync_1 <= sw_sync_0;
        sw_s      <= sw_sync_1;
        sw_s_d    <= sw_s;
    end

    wire all_done = (stick_states[3*0 +: 3] != 3'b000 && stick_states[3*0 +: 3] != 3'b001) &&
                    (stick_states[3*1 +: 3] != 3'b000 && stick_states[3*1 +: 3] != 3'b001) &&
                    (stick_states[3*2 +: 3] != 3'b000 && stick_states[3*2 +: 3] != 3'b001) &&
                    (stick_states[3*3 +: 3] != 3'b000 && stick_states[3*3 +: 3] != 3'b001) &&
                    (stick_states[3*4 +: 3] != 3'b000 && stick_states[3*4 +: 3] != 3'b001) &&
                    (stick_states[3*5 +: 3] != 3'b000 && stick_states[3*5 +: 3] != 3'b001) &&
                    (stick_states[3*6 +: 3] != 3'b000 && stick_states[3*6 +: 3] != 3'b001) &&
                    (stick_states[3*7 +: 3] != 3'b000 && stick_states[3*7 +: 3] != 3'b001);

    initial begin
        game_state = 2'b00;
        next_state = 2'b00;
        difficulty_level = 4'd1;
        game_finished = 1'b0;
        stick_states = 24'h0;
        countdown_val = 2'd3;
        timer = 0;
        current_stick = 0;
        sw_was_zero_at_start = 1'b0;
        caught = 1'b0;
        score = 4'd0;
        lfsr = 16'habcd;
        difficulty_cooldown = 20'd0;
    end

    always @(posedge clk) begin
        game_state <= next_state;
        game_finished <= all_done;

        // LFSR advance during countdown and dropping for randomness
        if (game_state == 2'b01 || game_state == 2'b10)
            lfsr <= { lfsr[14:0], lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10] };
    end

    always @(posedge clk) begin
        case (game_state)
            2'b00: begin
                if (start_button) begin
                    next_state = 2'b01; // Transition to Start state on button press
                end else begin
                    next_state = 2'b00; // Stay in Wait state
                end

                // Cooldown: after changing difficulty, ignore pulses for ~10 ms (one press = one step)
                if (difficulty_cooldown > 20'd0)
                    difficulty_cooldown <= difficulty_cooldown - 1'b1;
                else if (right_button_pulse && difficulty_level < 4'd9) begin
                    difficulty_level <= difficulty_level + 1;
                    difficulty_cooldown <= DIFF_COOLDOWN_CYCLES;
                end else if (left_button_pulse && difficulty_level > 4'd1) begin
                    difficulty_level <= difficulty_level - 1;
                    difficulty_cooldown <= DIFF_COOLDOWN_CYCLES;
                end
            end
            2'b01: begin
                if (timer >= ONE_SEC) begin
                    timer <= 0;
                    if (countdown_val == 2'd1) begin
                        next_state <= 2'b10;
                        timer <= 0;
                        // pick first random white stick (use LFSR % 8 as start index)
                        current_stick <= lfsr[2:0];
                    end else
                        countdown_val <= countdown_val - 1;
                end else
                    timer <= timer + 1;
            end

            2'b10: begin
                // Sub-phases: we use timer and stick_states to know phase.
                // Phase A: current stick is still white -> set it yellow, require sw==0, start catch timer
                // Phase B: stick is yellow, run catch timer; detect 0->1 on sw[current_stick]; when timer expires set green/red
                // Phase C: stick is green/red, run result wait timer; when done, pick next or go game over

                if (stick_states[current_stick*3 +: 3] == 3'b000) begin
                    // Phase A: turn yellow and require sw was 0
                    stick_states[current_stick*3 +: 3] <= 3'b001;
                    sw_was_zero_at_start <= (sw_s[current_stick] == 1'b0);
                    caught <= 1'b0;
                    timer <= 0;
                end else if (stick_states[current_stick*3 +: 3] == 3'b001) begin
                    // Phase B: catch window — register 0->1 so we don't miss the cycle timer expires
                    if (sw_was_zero_at_start && (sw_s[current_stick] && !sw_s_d[current_stick]))
                        caught <= 1'b1;
                    if (timer >= catch_ticks) begin
                        // Use current switch state when deciding: catch if already registered OR switch on now (and was off at start)
                        if (caught || (sw_was_zero_at_start && (sw_s[current_stick] == 1'b1))) begin
                            stick_states[current_stick*3 +: 3] <= 3'b010;
                            score <= score + 1;
                        end else
                            stick_states[current_stick*3 +: 3] <= 3'b011;
                        timer <= 0;
                    end else
                        timer <= timer + 1;
                end else begin
                    // Phase C: show result, wait RESULT_WAIT then next stick or game over
                    if (timer >= RESULT_WAIT) begin
                        timer <= 0;
                        if (all_done)
                            next_state <= 2'b11;
                        else begin
                            // Pick next white stick using LFSR: first white in order (lfsr, lfsr+1, ..., lfsr+7) mod 8
                            case (1'b1)
                                (stick_states[(lfsr[2:0]     )*3 +: 3] == 3'b000): current_stick <= lfsr[2:0];
                                (stick_states[(lfsr[2:0]+3'd1)*3 +: 3] == 3'b000): current_stick <= lfsr[2:0]+3'd1;
                                (stick_states[(lfsr[2:0]+3'd2)*3 +: 3] == 3'b000): current_stick <= lfsr[2:0]+3'd2;
                                (stick_states[(lfsr[2:0]+3'd3)*3 +: 3] == 3'b000): current_stick <= lfsr[2:0]+3'd3;
                                (stick_states[(lfsr[2:0]+3'd4)*3 +: 3] == 3'b000): current_stick <= lfsr[2:0]+3'd4;
                                (stick_states[(lfsr[2:0]+3'd5)*3 +: 3] == 3'b000): current_stick <= lfsr[2:0]+3'd5;
                                (stick_states[(lfsr[2:0]+3'd6)*3 +: 3] == 3'b000): current_stick <= lfsr[2:0]+3'd6;
                                (stick_states[(lfsr[2:0]+3'd7)*3 +: 3] == 3'b000): current_stick <= lfsr[2:0]+3'd7;
                                default: current_stick <= lfsr[2:0];  // fallback (should not happen if !all_done)
                            endcase
                        end
                    end else
                        timer <= timer + 1;
                end
            end

            2'b11: begin
                if (start_button) begin
                    next_state <= 2'b00;
                    stick_states <= 24'h0;
                end else
                    next_state <= 2'b11;
            end
            default: next_state <= 2'b00;
        endcase
    end

    // BCD display: WAIT -> difficulty; COUNTDOWN -> 3,2,1; DROPPING -> (optional) score; GAME_OVER -> score
    reg [3:0] bcd_val;
    always @(*) begin
        if (game_state == 2'b00)
            bcd_val = difficulty_level;
        else if (game_state == 2'b01)
            bcd_val = {2'd0, countdown_val};
        else if (game_state == 2'b11)
            bcd_val = score;
        else
            bcd_val = score;
    end

    always @(posedge clk) begin
        an <= 4'b1110;  // rightmost digit only for simplicity
    end

    // Segment decoder (active low)
    always @(*) begin
        case(difficulty_level)
            4'd0: seg <= 7'b1000000; // Display 0
            4'd1: seg <= 7'b1111001; // Display 1
            4'd2: seg <= 7'b0100100; // Display 2
            4'd3: seg <= 7'b0110000; // Display 3
            4'd4: seg <= 7'b0011001; // Display 4
            4'd5: seg <= 7'b0010010; // Display 5
            4'd6: seg <= 7'b0000010; // Display 6
            4'd7: seg <= 7'b1111000; // Display 7
            4'd8: seg <= 7'b0000000; // Display 8
            4'd9: seg <= 7'b0010000; // Display 9
            default: seg <= 7'b1111111; // Blank display
        endcase
    end

endmodule

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
    // Debouncer (clock is 40 MHz pclk: 10 ms = 400_000 cycles)
    // =========================
    localparam integer DEBOUNCE_COUNT = 400_000;
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
