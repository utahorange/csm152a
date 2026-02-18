`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/10/2026 02:28:23 PM
// Design Name: 
// Module Name: lab3_clock
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module clock_generator(input clk, output reg clk_1HZ, output reg clk_2HZ, reg clk_50MHZ);
    parameter CLOCK_DIV_1_HZ = 100_000_000;
    parameter CLOCK_DIV_2_HZ = 50_000_000;
    parameter CLOCK_DIV_50_MHZ = 2;
    reg [26:0] counter_to_1HZ = 26'b0; // per clock tick
    reg [26:0] counter_to_2HZ = 26'b0; // per clock tick
    reg [26:0] counter_to_50MHZ = 26'b0; // per clock tick

    always @(posedge clk) begin
        if (counter_to_1HZ == CLOCK_DIV_1_HZ - 1) begin // global counter reset 
            clk_1HZ <= ~clk_1HZ;
            counter_to_1HZ <= 0;
        end else
        begin
            counter_to_1HZ <= counter_to_1HZ + 1;
        end
        if (counter_to_2HZ == CLOCK_DIV_2_HZ - 1) begin // global counter reset 
            clk_2HZ <= ~clk_2HZ;
            counter_to_2HZ <= 0;
        end else
        begin
            counter_to_2HZ <= counter_to_2HZ + 1;
        end
        if (counter_to_50MHZ == CLOCK_DIV_50_MHZ - 1) begin // global counter reset 
            clk_50MHZ <= ~clk_50MHZ;
            counter_to_50MHZ <= 0;
        end else
        begin
            counter_to_50MHZ <= counter_to_50MHZ + 1;
        end
    end
endmodule

module lab3_clock (input clk_1HZ, input clk_2HZ, input clk_50MHZ, output reg [7:0] seg, output reg [3:0] an);
    
    reg [3:0] seconds1_counter = 4'b0;
    reg [3:0] seconds2_counter = 4'b0;
    reg [3:0] minutes1_counter = 4'b0;
    reg [3:0] minutes2_counter = 4'b0;
    
    reg [3:0] placeholder_digit = 4'b0000;
    reg [3:0] refresh_counter = 0;
    
    always @(posedge clk_1HZ) begin // this is very fast
        // refresh_counter <= refresh_counter + 1;
        
        seconds1_counter <= seconds1_counter + 1;
        if (seconds1_counter == 10) begin
            seconds2_counter <= seconds2_counter + 1;
            seconds1_counter <= 0;
        end
        
        if (seconds2_counter == 6) begin
            minutes1_counter <= minutes1_counter + 1;
            seconds2_counter <= 0;
        end
        
        if (minutes1_counter == 10) begin
            minutes2_counter <= minutes2_counter + 1;
            minutes1_counter <= 0;
        end
        
        if (minutes2_counter == 10) begin
            minutes2_counter <= 0;
        end
        
        // Display the updated seven_segN digits on the basys3 board.
            // Set all the board's digits to 0
    end
    
    always @(posedge clk_50MHZ) begin
        case(refresh_counter[3:2])
            2'b00: begin
                an  <= 4'b1110; // Digit 0 ON (Active Low for Basys3)
                // seg <= seven_seg0;
                placeholder_digit <= seconds1_counter;
            end
            2'b01: begin
                an  <= 4'b1101; // Digit 1 ON
                // seg <= seven_seg1;
                placeholder_digit <= seconds2_counter;
            end
            2'b10: begin
                an  <= 4'b1011; // Digit 2 ON
                // seg <= seven_seg2;
                placeholder_digit <= minutes1_counter;
            end
            2'b11: begin
                an  <= 4'b0111; // Digit 3 ON
                // seg <= seven_seg3;
                placeholder_digit <= minutes2_counter;
            end
        endcase
    end
    
    always @(*)
    begin
        case(placeholder_digit)
        4'b0000: seg <= 7'b0000001; // "0"     
        4'b0001: seg <= 7'b1001111; // "1" 
        4'b0010: seg <= 7'b0010010; // "2" 
        4'b0011: seg <= 7'b0000110; // "3" 
        4'b0100: seg <= 7'b1001100; // "4" 
        4'b0101: seg <= 7'b0100100; // "5" 
        4'b0110: seg <= 7'b0100000; // "6" 
        4'b0111: seg <= 7'b0001111; // "7" 
        4'b1000: seg <= 7'b0000000; // "8"     
        4'b1001: seg <= 7'b0000100; // "9" 
        default: seg <= 7'b0000001; // "0"
        endcase
    end
    
endmodule



