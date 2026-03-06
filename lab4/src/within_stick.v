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
