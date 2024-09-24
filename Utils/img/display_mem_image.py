import numpy as np
from PIL import Image
import argparse

def read_palette(palette_file, color_width):
    palette = []
    with open(palette_file, 'r') as f_palette:
        for line in f_palette:
            color = int(line.strip(), 16)
            # Extract RGB from the 12-bit color format (assuming 4 bits per channel)
            r = (color >> 8) & 0xF
            g = (color >> 4) & 0xF
            b = color & 0xF
            # Scale 4-bit colors to 8-bit (0-255)
            r = (r << 4) | r
            g = (g << 4) | g
            b = (b << 4) | b
            palette.append((r, g, b))
    return palette

def read_mem_file(mem_file, width, height):
    image_data = np.zeros((height, width), dtype=np.uint8)
    with open(mem_file, 'r') as f_mem:
        for i, line in enumerate(f_mem):
            pixel = int(line.strip(), 16)
            row = i // width
            col = i % width
            image_data[row, col] = pixel
    return image_data

def display_image(image_data, palette, width, height):
    img = Image.new('RGB', (width, height))
    pixels = img.load()
    
    for y in range(height):
        for x in range(width):
            pixels[x, y] = palette[image_data[y, x]]

    img.show()

def main():
    parser = argparse.ArgumentParser(description="Display image from .mem and palette files.")
    
    # Input arguments
    parser.add_argument("mem_file", type=str, help="Input .mem file with image data")
    parser.add_argument("palette_file", type=str, help="Input palette file with color data")
    parser.add_argument("width", type=int, help="Image width")
    parser.add_argument("height", type=int, help="Image height")
    
    args = parser.parse_args()

    # Read palette and image data
    palette = read_palette(args.palette_file, 12)
    image_data = read_mem_file(args.mem_file, args.width, args.height)

    # Display the image
    display_image(image_data, palette, args.width, args.height)

if __name__ == "__main__":
    main()
