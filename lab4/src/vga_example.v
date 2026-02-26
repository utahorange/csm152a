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

    // 8 stick positions, each 10 bits (fits 800x600). [7:0][9:0] = stick 0..7.
    // X: 32, 128, 224, 320, 416, 512, 608, 704.  Y: 300 for all (TOP_EDGE - STICK_HEIGHT).
    reg [7:0][9:0] sticks_x = {10'd704, 10'd608, 10'd512, 10'd416, 10'd320, 10'd224, 10'd128, 10'd32};
    reg [7:0][9:0] sticks_y = {10'd300, 10'd300, 10'd300, 10'd300, 10'd300, 10'd300, 10'd300, 10'd300};

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

module within_stick(
    input wire [10:0] hcount,
    input wire [10:0] vcount,

    // bottom-left corners of the 8 sticks, each coord 10 bits
    input wire [7:0] [9:0] sticks_x,
    input wire [7:0] [9:0] sticks_y,
    input wire [4:0] NUM_STICKS,
    input wire [10:0] stick_w, // width of the stick
    input wire [10:0] stick_h, // height of the stick
    output reg [3:0] stick_number // "stick 8" is NOT in a stick
                                  // "stick 7" is the last stick
);
    integer i;
        
    always @(*) begin
        if ((hcount >= sticks_x[0]) && (hcount < sticks_x[0] + stick_w) &&
            (vcount >= sticks_y[0]) && (vcount < sticks_y[0] + stick_h)) begin
                stick_number <= 0;
        end
        else if ((hcount >= sticks_x[1]) && (hcount < sticks_x[1] + stick_w) &&
            (vcount >= sticks_y[1]) && (vcount < sticks_y[1] + stick_h)) begin
                stick_number <= 1;
        end
        else if ((hcount >= sticks_x[2]) && (hcount < sticks_x[2] + stick_w) &&
            (vcount >= sticks_y[2]) && (vcount < sticks_y[2] + stick_h)) begin
                stick_number <= 2;
        end
        else if ((hcount >= sticks_x[3]) && (hcount < sticks_x[3] + stick_w) &&
            (vcount >= sticks_y[3]) && (vcount < sticks_y[3] + stick_h)) begin
                stick_number <= 3;
        end
        else if ((hcount >= sticks_x[4]) && (hcount < sticks_x[4] + stick_w) &&
            (vcount >= sticks_y[4]) && (vcount < sticks_y[4] + stick_h)) begin
                stick_number <= 4;
        end
        else if ((hcount >= sticks_x[5]) && (hcount < sticks_x[5] + stick_w) &&
            (vcount >= sticks_y[5]) && (vcount < sticks_y[5] + stick_h)) begin
                stick_number <= 5;
        end
        else if ((hcount >= sticks_x[6]) && (hcount < sticks_x[6] + stick_w) &&
            (vcount >= sticks_y[6]) && (vcount < sticks_y[6] + stick_h)) begin
                stick_number <= 6;
        end
        else if ((hcount >= sticks_x[7]) && (hcount < sticks_x[7] + stick_w) &&
            (vcount >= sticks_y[7]) && (vcount < sticks_y[7] + stick_h)) begin
                stick_number <= 7;
        end
        else
            stick_number <= 8;
    end
endmodule