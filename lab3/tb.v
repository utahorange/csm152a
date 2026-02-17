module tb();
    reg clk;
    wire [6:0] seg;
    wire [3:0] an;

    initial clk = 0;
    always #5 clk = ~clk; // 10ns clock period

    // Set ONE_SECOND to 10 so we can see 10 cycles of counting
    lab3_clock #(.ONE_SECOND(100)) main_counter ( .clk(clk), .seg(seg), .an(an) );

    initial begin
        $display("Starting Simulation...");
    end

    // Use $strobe to catch the values at the end of the current time step
    always @(posedge clk) begin
        $strobe("[%t] Anode=%b, Segments=%b", $time, an, seg);
    end
endmodule

