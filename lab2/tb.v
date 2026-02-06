`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01/29/2026 02:33:10 PM
// Design Name: 
// Module Name: tb
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


module tb;

    // define a bunch of wires, regs, etc.
    reg [11:0] input_2scomp;
    reg [7:0] output_fp;
    
    integer i;
    
    // Defining the wires for module input and output
    wire out_S;
    wire [2:0] out_E;
    wire [3:0] out_F;
    
    initial begin
        for (i = 12'b000000000000; i <= 12'b111111111111; i = i + 1'b1) begin
            input_2scomp <= i;
            
            #1;
            
            output_fp <= {out_S, out_E[2:0], out_F[3:0]};
            #1; // Wait 1 unit of time for combinational logic to propagate
            
            $display("Input (2's Comp): %12b | Output (FP): %08b", input_2scomp, output_fp);
        end
        
    end
        
    // instantiating the overarching module
    FPCVT converter (   // Inputs
                        .D (input_2scomp),
                        
                        // Outputs
                        .S (out_S),
                        .E (out_E),
                        .F (out_F) );
    
endmodule


