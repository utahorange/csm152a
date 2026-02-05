`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01/27/2026 02:30:05 PM
// Design Name: 
// Module Name: FPCVT
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


module FPCVT(D, S, E, F
    );

    input [11:0] D;
    output S;
    output [2:0] E;
    output [3:0] F;
    
    wire [11:0] intermed_result;
    converter_twos_to_sign_mag converter_twos (
                                          // Inputs
                                          .D_input(D),
                                          // Outputs
                                          .D_result(intermed_result),
                                          .S(S));
    
    wire [2:0] intermed_exp;
    wire [3:0] intermed_sig;
    wire intermed_fifth_bit;
    
    
        count_leading_zeroes counter (.D(intermed_result), .exponent(intermed_exp));
        
        extract_leading_bits elb(.D(intermed_result), .significand(intermed_sig), .fifth_bit(intermed_fifth_bit));
        
        rounding rounder(.E(intermed_exp), .F(intermed_sig), .fifth_bit(intermed_fifth_bit), .final_E(E), .final_F(F)); 
        
        
//    always @(*) begin
//        $display("--------- \n D_result: %12b | Sign: %1b, Final_E: %3b, Final_F: %4b", intermed_result, S, E, F); 
//        $display("intermed_exp: %3b | intermed_sig: %4b | intermed_fifth_bit: %1b", intermed_exp, intermed_sig, intermed_fifth_bit);
//    end
    
endmodule

module converter_twos_to_sign_mag(D_input, D_result, S);
    input [11:0] D_input;
    output [11:0] D_result;
    output S;
    
    assign S = D_input[11];
    assign D_result = (S == 1'b1) ? (~D_input + 1'b1) : D_input;

endmodule

module extract_leading_bits (D, significand, fifth_bit);
    input [11:0] D;
    output reg [3:0] significand;
    output reg fifth_bit;
    
//    always @(*) begin
//        $display("significand: %4b | D: %12b", significand, D); // debugging
//    end
//    // ALWAYS takes input D with a leading 0
    integer i;
    reg found_trans;
    always @* begin
        significand = 4'b0;
        fifth_bit = 1'b0;
        found_trans = 1'b0;
        
        for (i = 11; i >= 0; i = i - 1) begin
            if (i <= 3 && !found_trans) begin
                significand = D[3:0];
                // assign the fifth bit to 0 in the case that we use the last 4 bits
                fifth_bit = 1'b0;
                found_trans = 1'b1;
                
            end
            
            if (D[i] && !found_trans) begin
                significand = D[i-:4];
                fifth_bit = D[i-4];
                found_trans = 1'b1;
            end
        end
    end
endmodule

module count_leading_zeroes (D, exponent);
    input [11:0] D;
    output reg [2:0] exponent;
    integer flag = 0;
    integer leading_zeroes = 0;
    integer i;    
    
    always @* begin    
        flag = 0;
        exponent = 3'b0;
        for (i = 11; i >= 0; i = i - 1) begin
            if (D[i] && !flag) begin
                // number of leading zeroes is 11 - i
                leading_zeroes = 11 - i;
                if (leading_zeroes >= 8) begin
                    exponent = 0;
                end
                else begin
                    exponent = 8 - leading_zeroes;
                end
                flag = 1;
            end
        end
        //$display("Number of leading zeroes: %3b", exponent);
    end
endmodule


module rounding (E, F, fifth_bit, final_E, final_F);
    // F is significand
    input [2:0] E;
    input [3:0] F;
    input fifth_bit;
    output reg [2:0] final_E;
    output reg [3:0] final_F;
    
    always @* begin
        final_E = 3'b000;
        final_F = 4'b0000;
        
        if (fifth_bit) begin
            if (F == 4'b1111) begin
                if (E == 3'b111) begin
                    final_E = E;
                    final_F = 4'b1111;
                end
                else begin
                    final_E = E + 1'b1;
                    final_F = 4'b1000;
                end
                
            end
            else begin
                // rounding bit is 1, no overflow issue
                final_F = F+ 1'b1;
                final_E = E;
            end
        end
        
        else begin
           final_F = F;
           final_E = E; 
        end
    end
endmodule


