import pygame
import sys

# Define screen dimensions
SCREEN_WIDTH = 320
SCREEN_HEIGHT = 320
BACKGROUND_COLOR = (0, 0, 0)

# Some nice pastel colors
LINE_COLORS = [
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

# Define your transformed vertices
vertices = [
(148, 160),
(191, 222),
(122, 234),
(80, 160),
(191, 97),
(245, 160),
(177, 160),
(122, 85),
]

# Faces based on the provided indices
faces = [
    (2, 4, 1), (8, 6, 5), (5, 2, 1), (6, 3, 2), 
    (3, 8, 4), (1, 8, 5), (2, 3, 4), (8, 7, 6), 
    (5, 6, 2), (6, 7, 3), (3, 7, 8), (1, 4, 8)
]

# Initialize pygame
pygame.init()
screen = pygame.display.set_mode((SCREEN_WIDTH, SCREEN_HEIGHT))
pygame.display.set_caption('Cube Wireframe')

# Function to draw lines between vertices
def draw_faces(screen, vertices, faces):
    for face in faces:
        for i in range(3):
            # Get the vertices of the triangle face
            v1 = vertices[face[i] - 1]
            v2 = vertices[face[(i + 1) % 3] - 1]
            pygame.draw.line(screen, LINE_COLORS[i % len(LINE_COLORS)], v1, v2, 1)

# Main loop
running = True
while running:
    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            running = False
            pygame.quit()
            sys.exit()

    # Fill the screen with the background color
    screen.fill(BACKGROUND_COLOR)

    # Draw the faces of the cube
    draw_faces(screen, vertices, faces)

    # Update the display
    pygame.display.flip()
