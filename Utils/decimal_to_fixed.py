def to_fixed_point_hex(n: float, a: int, b: int, signed: bool = False) -> str:
    # Define the scale factor based on the number of fractional bits
    scale_factor = 1 << b
    total_bits = a + b
    
    # Define max and min values based on signed or unsigned format
    if signed:
        max_val = (1 << (total_bits - 1)) - 1
        min_val = -(1 << (total_bits - 1))
    else:
        max_val = (1 << total_bits) - 1
        min_val = 0

    # Scale the number to fixed-point representation and round it
    fixed_point_value = round(n * scale_factor)
 
    # Check if the value fits in the format
    if not (min_val <= fixed_point_value <= max_val):
        print(f"Warning: the number {n} does not fit in the Q{a}.{b} format with signed={signed}.")
    
    # Adjust for signed format if needed
    if signed and fixed_point_value < 0:
        fixed_point_value = (1 << total_bits) + fixed_point_value
    
    # Convert to hexadecimal and format as string
    hex_digits = (total_bits + 3) // 4
    hex_str = f'{fixed_point_value:0{hex_digits}X}'
    
    return hex_str

def to_fixed_point_bin(n: float, a: int, b: int, signed: bool = False) -> str:
    # Define the scale factor based on the number of fractional bits
    scale_factor = 1 << b
    total_bits = a + b
    
    # Define max and min values based on signed or unsigned format
    if signed:
        max_val = (1 << (total_bits - 1)) - 1
        min_val = -(1 << (total_bits - 1))
    else:
        max_val = (1 << total_bits) - 1
        min_val = 0

    # Scale the number to fixed-point representation and round it
    fixed_point_value = round(n * scale_factor)
 
    # Check if the value fits in the format
    if not (min_val <= fixed_point_value <= max_val):
        print(f"Warning: the number {n} does not fit in the Q{a}.{b} format with signed={signed}.")
    
    # Adjust for signed format if needed
    if signed and fixed_point_value < 0:
        fixed_point_value = (1 << total_bits) + fixed_point_value
    
    # Convert to binary and format as string
    bin_str = f"{fixed_point_value:0{total_bits}b}"
    return bin_str

def from_fixed_point_hex(hex_str: str, a: int, b: int, signed: bool = False) -> float:
    # Convert the hex string to an integer
    total_bits = a + b
    int_value = int(hex_str, 16)
    
    # Handle signed values if specified
    if signed and int_value >= (1 << (total_bits - 1)):
        int_value -= (1 << total_bits)
    
    # Convert to floating point by dividing by the scale factor
    scale_factor = 1 << b
    float_value = int_value / scale_factor
    
    return float_value
