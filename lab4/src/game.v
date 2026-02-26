// The `timescale directive specifies what the
// simulation time units are (1 ns here) and what
// the simulator time step should be (1 ps here).

`timescale 1 ns / 1 ps

// Declare the module and its ports. This is
// using Verilog-2001 syntax.

module game ( // currently our top module, previously vga_display or vga_example
  input wire clk,
  output reg vs,
  output reg hs,
  output reg [3:0] r,
  output reg [3:0] g,
  output reg [3:0] b,
  output wire pclk_mirror
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
    
    localparam integer TOP_EDGE = 570;
    localparam integer STICK_HEIGHT = 270;
    localparam integer STICK_WIDTH = 64;
    localparam integer STICK_SPACING = 32;
    localparam integer NUM_STICKS = 8;

    reg [7:0] sticks_x = {STICK_SPACING, STICK_SPACING*2 + STICK_WIDTH, STICK_SPACING*3 + STICK_WIDTH*2, 
                    STICK_SPACING*4 + STICK_WIDTH*3, STICK_SPACING*5 + STICK_WIDTH*4, 
                    STICK_SPACING*6 + STICK_WIDTH*5, STICK_SPACING*7 + STICK_WIDTH*6, 
                    STICK_SPACING*8 + STICK_WIDTH*7};
    reg [7:0] sticks_y = {TOP_EDGE - STICK_HEIGHT, TOP_EDGE - STICK_HEIGHT, TOP_EDGE - STICK_HEIGHT, TOP_EDGE - STICK_HEIGHT, TOP_EDGE - STICK_HEIGHT, TOP_EDGE - STICK_HEIGHT, TOP_EDGE - STICK_HEIGHT, TOP_EDGE - STICK_HEIGHT};
    always @(posedge clk)
    begin
        if (within_stick(hcount, vcount, sticks_x, sticks_y, STICK_WIDTH, STICK_HEIGHT) != 0) begin
            {r,g,b} <= 12'hf_0_0;
        end else begin
            {r,g,b} <= 12'ha_a_a;
        end
     end

endmodule

module within_stick(
    input wire [10:0] hcount,
    input wire [10:0] vcount,

    // this is a list of the bottom-left corners of the sticks
    input wire [2:0] [9:0] sticks_x, // list of x coords
    input wire [2:0] [9:0] sticks_y, // list of y coords
    input wire [4:0] NUM_STICKS,
    input wire [10:0] stick_w, // width of the stick
    input wire [10:0] stick_h, // height of the stick
    output reg [3:0] stick_number // "stick 8" is NOT in a stick
                                  // "stick 7" is the last stick
);
    integer i;

    always @(*) begin
        stick_number = 9;
        for (i = 0; i < NUM_STICKS; i = i+1) begin
            if ((hcount >= sticks_x[i]) && (hcount < sticks_x[i] + stick_w) &&
                (vcount >= sticks_y[i]) && (vcount < sticks_y[i] + stick_h)) begin
                stick_number = i; 
            end
        end
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

module game_control_logic();
    // keep track of state here
    // reg in_game = 0;
    
    // inputs passed from game to here to log button press and whatnot
        // do we need to do clock business again? yes 


    // start at start screen
    // wait for user input as a button press, but don't actually acivate unless not in game
    // when button press (sometimes), start game
    // when not in game mode, other buttons are in effect to change difficulty (number on screen)
        // this is acounter that counts up then cycles down again? or 2 btns for up and down? granulairty?
    // smth about timer countdown
    // modify stick state?

endmodule

module start_game_countdown();
    // some clock goofiness here to get our display countdown
    // but lowkey this should be more general bc we also have to display score as well?
endmodule