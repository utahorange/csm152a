`timescale 1ns / 1ps

module stopwatch(
    input clk,    // 100 MHz Master Clock
    input pause,  // Pause button
    input adj,    // Adjustment mode toggle button
    input sel,    // Minute/Second selection toggle button
    input rst,    // Reset button
    output [6:0] seg, // Seven-segment cathodes
    output [3:0] an   // Digit anodes
    );

    // --- Internal Clock Signals ---
    wire clk_1Hz, clk_2Hz, clk_disp, clk_blink;

    // --- Debounced/Processed Input Signals ---
    wire pause_tog, adj_tog, sel_tog;
    
    // --- Timer Value Signals ---
    wire [5:0] minutes_bin, seconds_bin;

    // 1. Clock Generation
    clock_gen clk_unit (
        .master_clock(clk),
        .normal_clock(clk_1Hz),
        .adjustment_clock(clk_2Hz),
        .display_clock(clk_disp),
        .blinking_clock(clk_blink)
    );

    // 2. Input Processing (Debouncing and Toggling)
    // Use the 100MHz clock or a divided version for the debouncer
    input_proc pause_debounce (
        .clk(clk_disp), .reset(rst), .button_in(pause), 
        .button_toggle(pause_tog)
    );

    input_proc adj_debounce (
        .clk(clk_disp), .reset(rst), .button_in(adj), 
        .button_toggle(adj_tog)
    );

    input_proc sel_debounce (
        .clk(clk_disp), .reset(rst), .button_in(sel), 
        .button_toggle(sel_tog)
    );

    // 3. Timer Logic
    timer_logic main_timer (
        .clk_normal(clk_1Hz),
        .clk_adjust(clk_2Hz),
        .rst(rst),
        .pause_toggle(pause_tog),
        .adj_mode(adj_tog),
        .sel_mode(sel_tog),
        .minutes(minutes_bin),
        .seconds(seconds_bin)
    );

    // 4. Display Control
    display_control main_display (
        .display_clk(clk_disp),
        .blink_clk(clk_blink),
        .minutes(minutes_bin),
        .seconds(seconds_bin),
        .adj_mode(adj_tog),
        .sel_mode(sel_tog),
        .an(an),
        .seg(seg)
    );

endmodule

module clock_gen(
    input  wire master_clock,       // 100 MHz
    output reg  normal_clock,       // 1 Hz
    output reg  adjustment_clock,   // 2 Hz
    output reg  display_clock,      // 50-700 Hz -> 300
    output reg  blinking_clock      // 4 Hz
);

    // =========================
    // Clock division parameters
    // =========================
    // Toggle every HALF period
    localparam integer NORMAL_DIV     = 50_000_000;  // 1 Hz
    localparam integer ADJUST_DIV     = 25_000_000;  // 2 Hz
    localparam integer DISPLAY_DIV    = 166_667;   // 300 Hz
    localparam integer BLINK_DIV      = 12_500_000;  // 4 Hz

    // =========================
    // Counters
    // =========================
    integer normal_cnt     = 0;
    integer adjust_cnt     = 0;
    integer display_cnt    = 0;
    integer blink_cnt      = 0;

    // =========================
    // Clock generation
    // =========================
    always @(posedge master_clock) begin

        // ---- Normal clock
        if (normal_cnt == NORMAL_DIV - 1) begin
            normal_clock <= ~normal_clock;
            normal_cnt   <= 0;
        end else begin
            normal_cnt <= normal_cnt + 1;
        end

        // ---- Adjustment clock
        if (adjust_cnt == ADJUST_DIV - 1) begin
            adjustment_clock <= ~adjustment_clock;
            adjust_cnt       <= 0;
        end else begin
            adjust_cnt <= adjust_cnt + 1;
        end

        // ---- Display clock
        if (display_cnt == DISPLAY_DIV - 1) begin
            display_clock <= ~display_clock;
            display_cnt   <= 0;
        end else begin
            display_cnt <= display_cnt + 1;
        end

        // ---- Blinking clock
        if (blink_cnt == BLINK_DIV - 1) begin
            blinking_clock <= ~blinking_clock;
            blink_cnt      <= 0;
        end else begin
            blink_cnt <= blink_cnt + 1;
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

module timer_logic(
    input  wire clk_normal,    // 1 Hz clock 
    input  wire clk_adjust,    // 2 Hz clock 
    input  wire rst,           // Reset signal [cite: 23, 28]
    input  wire pause_toggle,  // High = paused, Low = running
    input  wire adj_mode,      // High = adjustment mode, Low = normal mode
    input  wire sel_mode,      // High = adjust minutes, Low = adjust seconds
    
    output reg [5:0] minutes,  // 0-59
    output reg [5:0] seconds   // 0-59
);

    // Determine which clock to use based on mode
    wire active_clk;
    assign active_clk = adj_mode ? clk_adjust : clk_normal;

    always @(posedge active_clk or posedge rst) begin
        if (rst) begin
            minutes <= 6'd0;
            seconds <= 6'd0;
        end else begin
            if (adj_mode) begin
                // --- ADUSTMENT MODE ---
                if (sel_mode) begin
                    // Adjust Minutes
                    if (minutes == 6'd59)
                        minutes <= 6'd0;
                    else
                        minutes <= minutes + 1'b1;
                end else begin
                    // Adjust Seconds
                    if (seconds == 6'd59)
                        seconds <= 6'd0;
                    else
                        seconds <= seconds + 1'b1;
                end
            end else if (!pause_toggle) begin
                // --- NORMAL COUNTING MODE ---
                if (seconds == 6'd59) begin
                    seconds <= 6'd0;
                    if (minutes == 6'd59)
                        minutes <= 6'd0; // Rollover total time
                    else
                        minutes <= minutes + 1'b1;
                end else begin
                    seconds <= seconds + 1'b1;
                end
            end
            // If paused and not in adj_mode, values remain latching
        end
    end

endmodule

module display_control(
    input  wire display_clk,    // Fast clock for multiplexing (e.g., 50-700 Hz)
    input  wire blink_clk,      // Slow clock for adjustment blinking (4 Hz)
    input  wire [5:0] minutes,  // Binary minutes (0-59)
    input  wire [5:0] seconds,  // Binary seconds (0-59)
    input  wire adj_mode,       // High if in adjustment mode
    input  wire sel_mode,       // High = minutes, Low = seconds
    output reg [3:0] an,        // Anode control (active low)
    output reg [6:0] seg        // Seven-segment cathodes (active low)
);

    // Internal signals for BCD conversion
    wire [3:0] min_ten, min_one, sec_ten, sec_one;
    assign min_ten = minutes / 10;
    assign min_one = minutes % 10;
    assign sec_ten = seconds / 10;
    assign sec_one = seconds % 10;

    reg [1:0]  digit_sel = 0;   // Counter to cycle through 4 digits
    reg [3:0]  current_digit;   // The 4-bit value to display
    
    // --- Multiplexing Logic ---
    always @(posedge display_clk) begin
        digit_sel <= digit_sel + 1;
        
        case (digit_sel)
            2'b00: begin // Minutes Tens
                current_digit <= min_ten;
                an <= (adj_mode && sel_mode && blink_clk) ? 4'b1111 : 4'b0111;
            end
            2'b01: begin // Minutes Ones
                current_digit <= min_one;
                an <= (adj_mode && sel_mode && blink_clk) ? 4'b1111 : 4'b1011;
            end
            2'b10: begin // Seconds Tens
                current_digit <= sec_ten;
                an <= (adj_mode && !sel_mode && blink_clk) ? 4'b1111 : 4'b1101;
            end
            2'b11: begin // Seconds Ones
                current_digit <= sec_one;
                an <= (adj_mode && !sel_mode && blink_clk) ? 4'b1111 : 4'b1110;
            end
        endcase
    end

    // --- Seven-Segment Decoder ---
    always @(*) begin
        case (current_digit)
            4'h0: seg = 7'b1000000; // 0
            4'h1: seg = 7'b1111001; //7'b1001111; // 1
            4'h2: seg = 7'b0100100; //7'b0010010; // 2
            4'h3: seg = 7'b0110000; //7'b0000110; // 3
            4'h4: seg = 7'b0011001; //7'b1001100; // 4
            4'h5: seg = 7'b0010010; //7'b0100100; // 5
            4'h6: seg = 7'b0000010; //7'b0100000; // 6
            4'h7: seg = 7'b1111000; //7'b0001111; // 7
            4'h8: seg = 7'b0000000; // 8
            4'h9: seg = 7'b0010000; //7'b0000100; // 9
            default: seg = 7'b1111111;
        endcase
    end

endmodule

