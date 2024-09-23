import sys
import math
import argparse
from PIL import Image
import numpy as np
from pathlib import Path

def generate_palette_and_mem(image_path, width, height, palette_size):
    # Open image, resize, and convert to indexed color mode with palette
    img = Image.open(image_path).resize((width, height)).convert('P', palette=Image.ADAPTIVE, colors=palette_size)
    
    base_filename = Path(image_path).stem
    palette_file_name = base_filename + "_pal.mem"
    mem_file_name = base_filename + ".mem"

    # Get the color palette and save it to a file
    palette = img.getpalette()[:palette_size * 3]  # First N colors (R, G, B) values
    with open(palette_file_name, 'w') as f_palette:
        for i in range(0, len(palette), 3):
            r, g, b = palette[i], palette[i+1], palette[i+2]

            # Scale the 8-bit values (0-255) down to 4-bit (0-15)
            r_4bit = r // 16
            g_4bit = g // 16
            b_4bit = b // 16

            # Packing RGB into 12 bits
            color = (r_4bit << 8) | (g_4bit << 4) | b_4bit
            f_palette.write(f'{color:03X}\n')

    # Get the number of bits required to represent the palette size
    hex_digits = math.ceil(math.log2(palette_size) / 4)

    # Convert the image array to a memory file
    img_array = np.array(img)
    with open(base_filename + ".mem", 'w') as f_mem:
        for row in img_array:
            for pixel in row:
                f_mem.write(f'{pixel:0{hex_digits}X}\n')

    print(f'Palette saved to {palette_file_name}')
    print(f'Memory file saved to {mem_file_name}')


def main():
    parser = argparse.ArgumentParser(description="Generate color palette and memory file from an image.")
    
    # Input arguments
    parser.add_argument("filename", type=str, help="Input image filename")
    parser.add_argument("width", type=int, help="Width to resize the image to")
    parser.add_argument("height", type=int, help="Height to resize the image to")
    parser.add_argument("colors", type=int, help="Number of colors in the palette")
    
    args = parser.parse_args()

    # Generate palette and memory file
    generate_palette_and_mem(args.filename, args.width, args.height, args.colors)

if __name__ == "__main__":
    main()
