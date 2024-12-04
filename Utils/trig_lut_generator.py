import math

ADDR_WIDTH = 12
DATA_WIDTH = 24
N = 2 ** ADDR_WIDTH
SCALE = 2 ** 13  # Q11.13 scaling factor

with open("sine_lut.mem", "w") as sine_file, open("cosine_lut.mem", "w") as cosine_file:
    for i in range(N):
        angle = (2 * math.pi * i) / N
        sine_val = math.sin(angle)
        cosine_val = math.cos(angle)
        print(f"Angle: {angle:.4f} Sine: {sine_val:.4f} Cosine: {cosine_val:.4f}")

        sine_val = int(sine_val * SCALE)
        cosine_val = int(cosine_val * SCALE)
        print(f"Angle: {angle:.4f} Sine: {sine_val} Cosine: {cosine_val}")

        sine_file.write(f"{sine_val & 0xFFFFFF:06X}\n")  # Write as 24-bit hex
        cosine_file.write(f"{cosine_val & 0xFFFFFF:06X}\n")
