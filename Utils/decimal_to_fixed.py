def generate_fixed_point_hex_string(num, integer_bits, decimal_bits, signed):
    bit_string = ""
    val = 0
    
    if signed:
        if (num < 0):
            bit_string += "1"
            val = -2**(integer_bits-1)
        else:
            bit_string += "0"

        integer_bits -= 1

    while integer_bits:
        integer_bits -= 1
        if (val + 2**(integer_bits) <= num):
            bit_string += "1"
            val += 2**(integer_bits)
        else:
            bit_string += "0"

    bit_string += "."

    decimal_counter = 0

    while decimal_counter < decimal_bits:
        decimal_counter += 1
        if (val + 2**(-decimal_counter) <= num):
            bit_string += "1"
            val += 2**(-decimal_counter)
        else:
            bit_string += "0"

    bit_string = bit_string.replace(".", "", 1)
    return hex(int(bit_string, 2))


with open("reciprocal.mem", "w") as f:
    for i in range(1, 1000):
        f.write(generate_fixed_point_hex_string(1/i, 0, 12, False)[2:].zfill(3) + "\n")

