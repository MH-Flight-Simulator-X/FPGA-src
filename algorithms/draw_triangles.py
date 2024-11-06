import ast
import pygame
import sys
import random

# Define screen dimensions
SCREEN_SCALE = 1.0
SCREEN_WIDTH = int(320 * SCREEN_SCALE)
SCREEN_HEIGHT = int(320 * SCREEN_SCALE)
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

PLANE_COLORS = [
    (54, 69, 79),
    (112, 128, 144),
    (89, 89, 89),
    (178, 190, 181),
]

# Define tree locations
trees = []
for _ in range(20):
    x = random.randint(0, int(SCREEN_WIDTH))
    y = random.randint(int(SCREEN_HEIGHT // 2), int(SCREEN_HEIGHT))
    trees.append([x, y])

# Define cloud locations
clouds = []
for _ in range(10):
    x = random.randint(10, int(SCREEN_WIDTH)-10)
    y = random.randint(0, int(SCREEN_HEIGHT // 2 * 0.75))
    clouds.append([x, y])

# Define mountain locations
mountains = []
for _ in range(10):
    x = random.randint(10, int(SCREEN_WIDTH)-10)
    y = random.randint(int(SCREEN_HEIGHT // 2), int(SCREEN_HEIGHT))
    mountains.append([x, y])

def draw_gradient(screen, color1, color2, start_y=0, end_y=SCREEN_HEIGHT):
    for y in range(int(start_y), int(end_y)):
        color = [0, 0, 0]
        for i in range(3):
            color[i] = int(color1[i] + (color2[i] - color1[i]) * (y / SCREEN_HEIGHT))
        pygame.draw.line(screen, color, (0, y), (SCREEN_WIDTH, y))

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

def draw_tree(screen, x, y):
    pygame.draw.rect(screen, (139, 69, 19), (x, y, 10, 20))
    pygame.draw.polygon(screen, (0, 128, 0), [(x - 10, y), (x + 20, y), (x + 5, y - 20)])
    pygame.draw.polygon(screen, (0, 128, 0), [(x - 10, y - 10), (x + 20, y - 10), (x + 5, y - 30)])
    pygame.draw.polygon(screen, (0, 128, 0), [(x - 10, y - 20), (x + 20, y - 20), (x + 5, y - 40)])

def draw_cloud(screen, x, y):
    # Draw a fluffy cloud
    pygame.draw.ellipse(screen, (255, 255, 255), (x, y, 50, 30))
    pygame.draw.ellipse(screen, (255, 255, 255), (x + 20, y - 10, 50, 30))
    pygame.draw.ellipse(screen, (255, 255, 255), (x + 10, y - 20, 50, 30))

def edge_function(p0, p1, p2):
    return (p2[0] - p0[0]) * (p1[1] - p0[1]) - (p2[1] - p0[1]) * (p1[0] - p0[0])

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

        # Draw grass in lower half from a grass green at the bottom to a washed out green at the horizon 
        draw_gradient(screen, (152, 251, 152), (0, 128, 0), SCREEN_HEIGHT // 2, SCREEN_HEIGHT)

        # Fill upper half of screen with light blue sky color, from horizon to top
        # Use gradient from light blue to white
        draw_gradient(screen, (135, 206, 250), (255, 255, 255), 0, SCREEN_HEIGHT // 2)

        # Draw trees at random locations bellow the horizon
        for i in range(len(trees)):
            draw_tree(screen, trees[i][0], trees[i][1])

        # Draw clouds at random locations above the horizon
        for i in range(len(clouds)):
            draw_cloud(screen, clouds[i][0], clouds[i][1])

        # Draw each triangle with a color from the palette
        min = 100.0
        max = 0.0

        for i, triangle in enumerate(triangles):
            depths = [z for (x, y, z) in triangle]
            depth_val = (depths[0] + depths[1] + depths[2]) / 3
            depth_val = depth_val * 100

            if (depth_val > max):
                max = depth_val
            if (depth_val < min):
                min = depth_val

        total_area = 0
        for i, triangle in enumerate(triangles):
            color = PLANE_COLORS[i % len(PLANE_COLORS)]
            (v0, v1, v2) = triangle
            coords = [(x, y) for (x, y, z) in triangle]

            # Calculate area of triangle
            area = edge_function(coords[0], coords[1], coords[2])
            if (area <= 0):
                continue
            total_area += area

            depths = [z for (x, y, z) in triangle]
            depth_val = (depths[0] + depths[1] + depths[2]) / 3
            depth_val = depth_val * 100
            
            # color_val = map_value(depth_val, max * 1.000001, min * 0.9999, 0.3, 1.0)
            color_val = 1
            final_color = (color[0] * color_val, color[1] * color_val, color[2] * color_val)

            pygame.draw.polygon(screen, final_color, coords)

        print("Total area: ", total_area)
        print("Average area: ", total_area / len(triangles))

        # Update the display
        pygame.display.flip()
        clock.tick(60)

    pygame.quit()
    sys.exit()

main("model.tri")
