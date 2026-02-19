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

module clock_generator(
    input clk, 
    output reg clk_1HZ, 
    output reg clk_2HZ, 
    output reg clk_1_5_HZ,
    output reg clk_50MHZ);

    parameter CLOCK_DIV_1_HZ = 100_000_000; // normal
    parameter CLOCK_DIV_2_HZ = 50_000_000; // adjust
    parameter CLOCK_DIV_1_5_HZ = 80_000_000; // display
    parameter CLOCK_DIV_50_MHZ = 50_000; // blinking

    reg [26:0] counter_to_1HZ = 26'b0; // per second
    reg [26:0] counter_to_2HZ = 26'b0; // adjustment
    reg [26:0] counter_to_1_5_HZ = 26'b0; // blinking
    reg [26:0] counter_to_50MHZ = 26'b0; // display

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
        if (counter_to_1_5_HZ == CLOCK_DIV_1_5_HZ - 1) begin // global counter reset 
            clk_1_5_HZ <= ~clk_1_5_HZ;
            counter_to_1_5_HZ <= 0;
        end else
        begin
            counter_to_1_5_HZ <= counter_to_1_5_HZ + 1;
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

module lab3_clock (
    input wire clk_normal, // normal
    input wire clk_adjust, // adjust
    input wire clk_display, // display
    input wire clk_blink, // blinking
    input wire reset, 
    input wire pause, 
    input wire adjust, 
    input wire select,
    output reg [7:0] seg, 
    output reg [3:0] an
);

    reg [3:0] seconds1_counter = 4'b0;
    reg [3:0] seconds2_counter = 4'b0;
    reg [3:0] minutes1_counter = 4'b0;
    reg [3:0] minutes2_counter = 4'b0;
    
    reg [3:0] placeholder_digit = 4'b0000; // the digit that is currentl being displayed by all the anodes
    reg [1:0] digit_to_display = 0; // which anode to turn on 
   
    wire active_clk;
    assign active_clk = adjust ? clk_adjust : clk_normal;

    always @(posedge active_clk or posedge reset) begin
        if (reset) begin
            seconds1_counter <= 4'b0;
            seconds2_counter <= 4'b0;
            minutes1_counter <= 4'b0;
            minutes2_counter <= 4'b0;
        end else begin
            if (adjust) begin
                if (select) begin // adjust minutes
                    if (minutes1_counter == 9 && seconds2_counter == 5 && seconds1_counter == 9) begin
                        minutes2_counter <= minutes2_counter + 1;
                        minutes1_counter <= 0;
                    end
                    if (minutes2_counter == 9 && minutes1_counter == 9) begin
                        minutes2_counter <= 0;
                    end
                end else begin //  adjust seconds
                    if (seconds1_counter == 9) begin
                        seconds2_counter <= seconds2_counter + 1;
                        seconds1_counter <= 0;
                    end else begin
                        seconds1_counter <= seconds1_counter + 1;
                    end
                    if (seconds2_counter == 5 && seconds1_counter == 9) begin
                        seconds2_counter <= 0;
                    end
                end
            end else if (!pause) begin
                if (seconds1_counter == 9) begin
                    seconds2_counter <= seconds2_counter + 1;
                    seconds1_counter <= 0;
                end else begin
                    seconds1_counter <= seconds1_counter + 1;
                end

                if (seconds2_counter == 5 && seconds1_counter == 9) begin
                    minutes1_counter <= minutes1_counter + 1;
                    seconds2_counter <= 0;
                end
                
                if (minutes1_counter == 9 && seconds2_counter == 5 && seconds1_counter == 9) begin
                    minutes2_counter <= minutes2_counter + 1;
                    minutes1_counter <= 0;
                end
                
                if (minutes2_counter == 9 && minutes1_counter == 9) begin
                    minutes2_counter <= 0;
                end
            end
            // if paused and not in adjusting mode
        end
    end
    
    
    // --- Display Logic ---
    always @(posedge clk_display) begin
        digit_to_display <= digit_to_display + 1;
        case(digit_to_display)
            2'b00: begin
                placeholder_digit <= seconds1_counter;
                an <= (adjust && select && clk_blink) ? 4'b1111 : 4'b1110;
            end
            2'b01: begin
                placeholder_digit <= seconds2_counter;
                an <= (adjust && select && clk_blink) ? 4'b1111 : 4'b1101;
            end
            2'b10: begin
                placeholder_digit <= minutes1_counter;
                an <= (adjust && !select && clk_blink) ? 4'b1111 : 4'b1011;
            end
            2'b11: begin
                placeholder_digit <= minutes2_counter;
                an <= (adjust && !select && clk_blink) ? 4'b1111 : 4'b0111;
            end
        endcase
    end

    always @(*)
    begin
        case(placeholder_digit)
            4'b0000: seg <= 7'b1000000; // "0"     
            4'b0001: seg <= 7'b1111001; // "1" 
            4'b0010: seg <= 7'b0100100; // "2" 
            4'b0011: seg <= 7'b0110000; // "3" 
            4'b0100: seg <= 7'b0011001; // "4" 
            4'b0101: seg <= 7'b0010010; // "5" 
            4'b0110: seg <= 7'b0000010; // "6" 
            4'b0111: seg <= 7'b1111000; // "7" 
            4'b1000: seg <= 7'b0000000; // "8"     
            4'b1001: seg <= 7'b0010000; // "9"
            default: seg <= 7'b1111111; // default 
        endcase
    end
    
endmodule