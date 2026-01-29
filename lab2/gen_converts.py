#!/usr/bin/env python3
"""
12-bit Two's Complement to 8-bit Floating Point Converter
Format: S (1 bit sign), E (3 bit exponent), F (4 bit fraction)
Tests the full range: -2048 to 2047
"""

def twos_to_sign_mag(d_input):
    """
    Convert 12-bit two's complement to sign-magnitude.
    Returns (sign, magnitude) where magnitude is 12 bits.
    """
    sign = (d_input >> 11) & 1
    if sign:
        # Negative: take two's complement
        magnitude = (~d_input + 1) & 0xFFF
    else:
        magnitude = d_input
    return sign, magnitude

def count_leading_zeros(d):
    """
    Count leading zeros in 12-bit number.
    Matches Verilog: exponent = 11 - i where i is position of first 1.
    Returns exponent (3 bits, will be truncated if > 7).
    """
    # Loop from bit 11 down to 0 (matching Verilog)
    for i in range(11, -1, -1):
        if (d >> i) & 1:
            exponent = 11 - i
            # Truncate to 3 bits (matching Verilog behavior)
            return exponent & 0x7
    # All zeros case
    return 0

def extract_leading_bits(d):
    """
    Extract 4-bit significand and 5th bit for rounding.
    Matches Verilog: D[i-:4] extracts bits i down to i-3.
    Returns (significand, fifth_bit).
    """
    # Loop from bit 10 down to 0 (bit 11 should be 0 for magnitude)
    for i in range(10, -1, -1):
        if i <= 3:
            # Use last 4 bits (D[3:0])
            significand = d & 0xF
            fifth_bit = 0
            return significand, fifth_bit
        
        if (d >> i) & 1:
            # Extract 4 bits: D[i-:4] means bits i, i-1, i-2, i-3
            # This is equivalent to (d >> (i-3)) & 0xF
            significand = (d >> (i - 3)) & 0xF
            # Extract 5th bit: D[i-4]
            fifth_bit = (d >> (i - 4)) & 1 if (i >= 4) else 0
            return significand, fifth_bit
    
    # All zeros case
    return 0, 0

def rounding(e, f, fifth_bit):
    """
    Apply rounding based on fifth bit.
    Matches Verilog: only updates if fifth_bit is 1.
    Returns (final_E, final_F).
    """
    if fifth_bit:
        if f == 15:  # 0b1111
            # Round to 0b1000 and increment exponent
            final_f = 8  # 0b1000
            final_e = min((e + 1), 7)  # Cap at 7 (max for 3 bits)
        else:
            final_f = (f + 1) & 0xF  # Increment, keep within 4 bits
            final_e = e
    else:
        # No rounding needed (Verilog doesn't assign, so pass through)
        final_f = f
        final_e = e
    
    return final_e, final_f

def convert_to_fp(d_input):
    """
    Convert 12-bit two's complement number to 8-bit floating point.
    Input: d_input (12-bit two's complement, 0-4095)
    Output: (S, E, F) where S is 1 bit, E is 3 bits, F is 4 bits
    """
    # Step 1: Convert two's complement to sign-magnitude
    sign, magnitude = twos_to_sign_mag(d_input)
    
    # Handle zero case
    if magnitude == 0:
        return (0, 0, 0)
    
    # Step 2: Count leading zeros to get exponent
    exponent = count_leading_zeros(magnitude)
    
    # Step 3: Extract leading bits for significand
    significand, fifth_bit = extract_leading_bits(magnitude)
    
    # Step 4: Apply rounding
    final_e, final_f = rounding(exponent, significand, fifth_bit)
    
    return (sign, final_e, final_f)

def test_full_range():
    """
    Test all 4096 possible 12-bit two's complement values.
    """
    print("Testing full range of 12-bit two's complement numbers...")
    print("=" * 80)
    
    results = []
    for d_input in range(4096):
        # Convert to signed integer
        if d_input >= 2048:
            signed_val = d_input - 4096
        else:
            signed_val = d_input
        
        # Convert to floating point
        S, E, F = convert_to_fp(d_input)
        
        # Format output
        fp_value = (S << 7) | (E << 4) | F
        fp_bin = f"{fp_value:08b}"
        
        results.append((signed_val, d_input, S, E, F, fp_value))
        
        # Format input as 12-bit binary
        input_bin = f"{d_input:012b}"
        
        # Print in requested format
        print(f"Input (2's Comp): {input_bin} | Output (FP): {fp_bin}")
    
    print("=" * 80)
    print(f"\nTotal values tested: {len(results)}")
    print(f"Range: {results[0][0]} to {results[-1][0]}")
    
    # Summary statistics
    unique_fp = len(set(fp for _, _, _, _, _, fp in results))
    print(f"Unique floating point values: {unique_fp}")
    
    return results

def test_specific_values():
    """
    Test some specific edge cases.
    """
    print("\n" + "=" * 80)
    print("Testing specific edge cases:")
    print("=" * 80)
    
    test_cases = [
        0,      # Zero
        1,      # Smallest positive
        -1,     # Smallest negative (two's complement: 4095)
        2047,   # Largest positive
        2048,   # -2048 (smallest negative)
        1024,   # Mid-range positive
        3072,   # -1024 (mid-range negative)
        512,
        3584,   # -512
        256,
        3840,   # -256
    ]
    
    for val in test_cases:
        if val < 0:
            d_input = val + 4096
        else:
            d_input = val
        
        S, E, F = convert_to_fp(d_input)
        fp_value = (S << 7) | (E << 4) | F
        fp_bin = f"{fp_value:08b}"
        
        input_bin = f"{d_input:012b}"
        
        print(f"Input (2's Comp): {input_bin} | Output (FP): {fp_bin}")

if __name__ == "__main__":
    # Test full range
    results = test_full_range()
    
    # Test specific values
    test_specific_values()
    
    # Optionally save results to file
    print("\n" + "=" * 80)
    print("Saving results to 'conversion_results.txt'...")
    with open('conversion_results.txt', 'w') as f:
        for signed_val, d_input, S, E, F, fp_value in results:
            input_bin = f"{d_input:012b}"
            fp_bin = f"{fp_value:08b}"
            f.write(f"Input (2's Comp): {input_bin} | Output (FP): {fp_bin}\n")
    print("Results saved!")

