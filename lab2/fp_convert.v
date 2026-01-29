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
    wire sign;
    converter_twos_to_sign_mag converter_twos (
                                          // Inputs
                                          .D_input(D),
                                          // Outputs
                                          .D_result(intermed_result),
                                          .S(sign));
    
    wire [2:0] intermed_exp;
    wire [3:0] intermed_sig;
    wire intermed_fifth_bit;
    count_leading_zeroes counter (.D(intermed_result), .exponent(intermed_exp));
    extract_leading_bits(.D(intermed_result), .significand(intermed_sig), .fifth_bit(intermed_fifth_bit));
    rounding rounder(.E(intermed_exp), .F(intermed_sig), .fifth_bit(intermed_fifth_bit), .final_E(E), .final_F(F)); 

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
    
    // ALWAYS takes input D with a leading 0
    integer i;
    always @* begin
        for (i = 10; i >= 0; i = i - 1) begin
            if (i <= 3) begin
                significand <= D[3:0];
                // assign the fifth bit to 0 in the case that we use the last 4 bits
                fifth_bit <= 0;
                break;
            end
            
            if (D[i]) begin
                significand <= D[i-:4];
                fifth_bit <= D[i-4];
                break;
            end
        end
    end
endmodule

module count_leading_zeroes (D, exponent);
    input [11:0] D;
    output reg [2:0] exponent;
    integer i;
    always @* begin
        for (i = 11; i >= 0; i = i - 1) begin
            if (D[i]) begin
                exponent <= 11 - i;
                break;
            end
        end
    end
endmodule


module rounding (E, F, fifth_bit, final_E, final_F
);
    // F is significand
    input [2:0] E;
    input [3:0] F;
    input fifth_bit;
    output reg [2:0] final_E;
    output reg [3:0] final_F;
    
    always @* begin
        if (fifth_bit) begin
            if (F == 4'b1111) begin
                final_F <= 4'b1000;
                final_E <= E + 1'b1;
            end
            else begin
                // rounding bit is 1, no overflow issue
                final_F <= F+ 1'b1;
                final_E <= E;
            end
        end
    end
endmodule
