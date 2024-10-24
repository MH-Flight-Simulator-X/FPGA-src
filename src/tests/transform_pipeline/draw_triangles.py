import ast
import pygame
import sys

# Define screen dimensions
SCREEN_SCALE = 2
SCREEN_WIDTH = 320 * SCREEN_SCALE
SCREEN_HEIGHT = 320 * SCREEN_SCALE
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

def load_face_data(file_path):
    faces = []
    with open(file_path, 'r') as file:
        data = file.read()
        faces_section = data.split('\n')

        # Parse faces as arrays (list of integers)
        faces = [list(map(int, f.split(','))) for f in faces_section]

    return faces

def load_vert_data(file_path):
    vertices = []
    with open(file_path, 'r') as file:
        data = file.read()
        verts = data.split('\n')[:-1]

        vertices = [list(map(float, f.split(','))) for f in verts]

    return vertices

faces = load_face_data('model.face')
vertices = load_vert_data('model_transformed.vert')

# Initialize pygame
pygame.init()
screen = pygame.display.set_mode((SCREEN_WIDTH, SCREEN_HEIGHT))
pygame.display.set_caption('Cube Wireframe')

# Function to draw lines between vertices
def draw_faces(screen, vertices, faces):
    for face in faces:
        for i in range(3):
            # Get the vertices of the triangle face
            v1_x, v1_y, _ = vertices[face[i] - 1]
            v2_x, v2_y, _ = vertices[face[(i + 1) % 3] - 1]
            
            v1_x = v1_x * SCREEN_SCALE
            v1_y = v1_y * SCREEN_SCALE
                        
            v2_x = v2_x * SCREEN_SCALE
            v2_y = v2_y * SCREEN_SCALE

            pygame.draw.line(screen, LINE_COLORS[i % len(LINE_COLORS)], (v1_x, v1_y), (v2_x, v2_y), 1)

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
