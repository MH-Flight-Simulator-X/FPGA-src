import ast
import pygame
import sys
import random

# Define screen dimensions
SCREEN_SCALE = 3.5
SCREEN_WIDTH = 320 * SCREEN_SCALE
SCREEN_HEIGHT = 320 * SCREEN_SCALE
BACKGROUND_COLOR = (0, 0, 0)

# Some nice pastel colors
COLOR_PALETTE = [
    (255, 182, 193),  # Light Pink
    (255, 222, 173),  # Navajo White
    (176, 224, 230),  # Powder Blue
    (255, 239, 213),  # Papaya Whip
    (240, 230, 140),  # Khaki
    (221, 160, 221),  # Plum
    (250, 250, 210),  # Light Goldenrod Yellow
    (152, 251, 152),  # Pale Green
    (245, 222, 179),  # Wheat
    (216, 191, 216)   # Thistle
]

def triangle_sort_depth(x):
    v0, v1, v2 = x
    _, _, z0 = v0
    _, _, z1 = v1
    _, _, z2 = v2
    return (z0 + z1 + z2)/3

def read_triangles_from_file(filename):
    """Reads triangles from a file and returns a list of vertices for each triangle."""
    triangles = []
    with open(filename, 'r') as file:
        for line in file:
            try:
                # Parse the line for 6 integers representing the coordinates
                v0x, v0y, v0z, v1x, v1y, v1z, v2x, v2y, v2z = map(float, line.strip().split(','))
                triangles.append((
                    (v0x * SCREEN_SCALE, v0y * SCREEN_SCALE, v0z), 
                    (v1x * SCREEN_SCALE, v1y * SCREEN_SCALE, v1z), 
                    (v2x * SCREEN_SCALE, v2y * SCREEN_SCALE, v2z)))
            except ValueError:
                print(f"Skipping invalid line: {line}")

    # Sort triangles
    triangles = sorted(triangles, key = triangle_sort_depth, reverse=True)

    return triangles

def map_value(value, old_min, old_max, new_min, new_max):
    # if (old_max - old_min <= 0.00001):
    #     return new_max
    return new_min + (value - old_min) * (new_max - new_min) / (old_max - old_min)

def main(filename):
    pygame.init()
    screen = pygame.display.set_mode((SCREEN_WIDTH, SCREEN_HEIGHT))
    pygame.display.set_caption("Render Triangles")

    # Load triangles from the file
    triangles = read_triangles_from_file(filename)

    clock = pygame.time.Clock()
    running = True
    while running:
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False

        # Clear the screen
        screen.fill((0, 0, 0))

        # Draw each triangle with a color from the palette
        min = 100.0
        max = 0.0

        for i, triangle in enumerate(triangles):
            color = COLOR_PALETTE[i % len(COLOR_PALETTE)]
            (v0, v1, v2) = triangle
            coords = [(x, y) for (x, y, z) in triangle]
            # depths = [z for (x, y, z) in triangle]
            # depth_val = (depths[0] + depths[1] + depths[2]) / 3
            # depth_val = depth_val * 100
            #
            # if (depth_val > max):
            #     max = depth_val
            # if (depth_val < min):
            #     min = depth_val
            #
            # color_val = map_value(depth_val, max * 1.000001, min * 0.9999, 20, 255)
            # color = (color_val, color_val, color_val)

            pygame.draw.polygon(screen, color, coords)

        # Write screen to image
        # pygame.image.save(screen, "output.png")
        # pygame.quit()
        # sys.exit()

        # Update the display
        pygame.display.flip()
        clock.tick(60)

    pygame.quit()
    sys.exit()

main("model.tri")
