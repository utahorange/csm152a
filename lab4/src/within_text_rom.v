module within_text_rom (
    input wire clk,           // Memory reads usually require a clock
    input wire [10:0] hcount,
    input wire [10:0] vcount,
    output wire is_in_set
);

    // Memory: 600 locations deep, 800 bits wide per location
    reg [799:0] video_ram [0:599];

    initial begin
        // Load the 480,000 bits from the file during synthesis
        $readmemb("start_screen_800x600.mem", video_ram);
    end

    assign is_in_set = video_ram[vcount][799 - hcount];
    

endmodule