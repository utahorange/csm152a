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

    // Map physical switches to sticks: reverse order so leftmost stick uses rightmost switch.
    wire [2:0] sw_index_for_stick = 3'd7 - current_stick;
    wire       sw_for_stick       = sw_s[sw_index_for_stick];

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
                    // Start a new countdown phase
                    next_state     <= 2'b01;
                    countdown_val  <= 2'd3;
                    timer          <= 32'd0;
                end else begin
                    next_state <= 2'b00; // Stay in Wait state
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
                    // Phase A: turn yellow and start catch window
                    stick_states[current_stick*3 +: 3] <= 3'b001;
                    // If the switch is already ON when yellow starts, count it as caught.
                    caught <= sw_for_stick;
                    timer <= 0;
                end else if (stick_states[current_stick*3 +: 3] == 3'b001) begin
                    // Phase B: catch window — latch if the switch is ON at any point during the window.
                    if (sw_for_stick == 1'b1)
                        caught <= 1'b1;
                    if (timer >= catch_ticks) begin
                        // Catch if it was ever observed ON during the window.
                        if (caught) begin
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
                // Game over: allow changing difficulty, and restart game on start_button
                if (start_button) begin
                    next_state   <= 2'b00;
                    stick_states <= 24'h0;
                end else begin
                    next_state <= 2'b11;
                end

                // Same difficulty adjustment behavior as in Wait state
                if (difficulty_cooldown > 20'd0)
                    difficulty_cooldown <= difficulty_cooldown - 1'b1;
                else if (right_button_pulse && difficulty_level < 4'd9) begin
                    difficulty_level     <= difficulty_level + 1;
                    difficulty_cooldown  <= DIFF_COOLDOWN_CYCLES;
                end else if (left_button_pulse && difficulty_level > 4'd1) begin
                    difficulty_level     <= difficulty_level - 1;
                    difficulty_cooldown  <= DIFF_COOLDOWN_CYCLES;
                end
            end
            default: next_state <= 2'b00;
        endcase
    end

    // Update BCD display:
    // - In Wait state, show difficulty level
    // - In Countdown state, show 3-2-1 based on countdown_val
    always @(*) begin
        if (game_state == 2'b01) begin
            // Countdown visible during countdown state
            case (countdown_val)
                2'd3: seg <= 7'b0110000; // Display 3
                2'd2: seg <= 7'b0100100; // Display 2
                2'd1: seg <= 7'b1111001; // Display 1
                default: seg <= 7'b1111111; // Blank display
            endcase
        end else begin
            // Otherwise, show difficulty level (including in Wait and during game)
            case (difficulty_level)
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
    end

    always @(posedge clk) begin
        an <= 4'b1110;  // rightmost digit only for simplicity
    end

endmodule