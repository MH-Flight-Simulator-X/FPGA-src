import numpy as np
import pygame

pygame.init()
screen_width, screen_height = 800, 600
screen = pygame.display.set_mode((screen_width, screen_height))

clock = pygame.time.Clock()

fov = 90
z_near = 0.1
z_far = 100
aspect_ratio = screen_width / screen_height

black = (0, 0, 0)
white = (255, 255, 255)
red = (255, 0, 0)
green = (0, 255, 0)
blue = (0, 0, 255)

colors = [white, red, green, blue]


def read_obj_file(path):
    with open(path, "r") as f:
        vertices = []
        faces = []

        for line in f.readlines():
            if line.startswith("v "):
                x, y, z = line[2:].strip().split()
                vertices.append([float(x), float(y), float(z)])
            
            elif line.startswith("f "):
                face_indices = line[2:].strip().split()
                face = []
                for vertex in face_indices:
                    v_index = vertex.split("/")[0]
                    face.append(int(v_index) - 1)
                faces.append(face)

    return np.array(vertices), np.array(faces)


def translate(point, translation_vector):
    translation_matrix = np.array([translation_vector[0], translation_vector[1], translation_vector[2]])
    return point + translation_matrix


def rotate_x(point, angle):
    rotate_x_matrix = np.array([[1, 0, 0],
                                [0, np.cos(angle), -np.sin(angle)],
                                [0, np.sin(angle), np.cos(angle)]])
    return rotate_x_matrix @ point


def rotate_y(point, angle):
    rotate_y_matrix = np.array([[np.cos(angle), 0, np.sin(angle)],
                                [0, 1, 0],
                                [-np.sin(angle), 0, np.cos(angle)]])
    return rotate_y_matrix @ point


def rotate_z(point, angle):
    rotate_z_matrix = np.array([[np.cos(angle), -np.sin(angle), 0],
                                [np.sin(angle), np.cos(angle), 0],
                                [0, 0, 1]])
    return rotate_z_matrix @ point


def perspective_project(point, fov, aspect_ratio, z_near, z_far):
    f = 1.0 / np.tan(np.radians(fov) / 2)
    
    projection_matrix = np.array([[f / aspect_ratio, 0, 0, 0],
                                  [0, f, 0, 0],
                                  [0, 0, (z_far + z_near) / (z_near - z_far), (2 * z_far * z_near) / (z_near - z_far)],
                                  [0, 0, -1, 0]])

    # Convert the point to homogeneous coordinates (add w = 1)
    point_h = np.array([point[0], point[1], point[2], 1.0])

    projected_point = projection_matrix @ point_h

    # Perform homogeneous division (divide by w to get 3D point in clip space)
    if projected_point[3] != 0:
        projected_point /= projected_point[3]

    return projected_point


def homogeneous_to_ndc(point):
    return np.array([point[0] / point[3], point[1] / point[3], point[2], point[3]])


def ndc_to_screen(ndc_point, screen_width, screen_height):
    screen_x = int((ndc_point[0] + 1) * 0.5 * screen_width)
    screen_y = int((1 - ndc_point[1]) * 0.5 * screen_height)
    return np.array([screen_x, screen_y, ndc_point[2]])


def edge_function(v1, v2, point):
    return (point[0] - v1[0]) * (v2[1] - v1[1]) - (point[1] - v1[1]) * (v2[0] - v1[0])


def compute_bounding_box(v1, v2, v3, screen_width, screen_height):
    min_x = max(int(min(v1[0], v2[0], v3[0])), 0)
    max_x = min(int(max(v1[0], v2[0], v3[0])), screen_width - 1)
    min_y = max(int(min(v1[1], v2[1], v3[1])), 0)
    max_y = min(int(max(v1[1], v2[1], v3[1])), screen_height - 1)
    return min_x, max_x, min_y, max_y


def update_screen_and_depth_buffer(x, y, z, color, depth_buffer, screen):
    if z < depth_buffer[x, y]:
        depth_buffer[x, y] = z 
        pygame.draw.rect(screen, color, (x, y, 1, 1))
     

def rasterize_triangle(v1, v2, v3, color, depth_buffer, screen):
    min_x, max_x, min_y, max_y = compute_bounding_box(v1, v2, v3, screen_width, screen_height)

    # Compute the edge functions at the top-left corner of the bounding box (min_x, min_y)
    e1 = edge_function(v1, v2, (min_x, min_y))
    e2 = edge_function(v2, v3, (min_x, min_y))
    e3 = edge_function(v3, v1, (min_x, min_y))

    # Precompute the edge function increments
    e1_dx = v2[1] - v1[1]
    e1_dy = -(v2[0] - v1[0])

    e2_dx = v3[1] - v2[1]
    e2_dy = -(v3[0] - v2[0])

    e3_dx = v1[1] - v3[1]
    e3_dy = -(v1[0] - v3[0])

    area = edge_function(v1, v2, v3)

    if (area == 0):
        return

    for y in range(min_y, max_y + 1):
        # Store the initial edge values at the start of each row
        e1_row = e1
        e2_row = e2
        e3_row = e3

        for x in range(min_x, max_x + 1):
            # Check if the point (x, y) is inside the triangle
            if e1_row >= 0 and e2_row >= 0 and e3_row >= 0:

                # Barycentric weights
                w1 = e1_row / area
                w2 = e2_row / area
                w3 = e3_row / area

                z = w1 * v1[2] + w2 * v2[2] + w3 * v3[2]

                update_screen_and_depth_buffer(x, y, z, color, depth_buffer, screen)

            # Increment edge function values for the next pixel in the row
            e1_row += e1_dx
            e2_row += e2_dx
            e3_row += e3_dx

        # At the end of each row, increment the edge values vertically
        e1 += e1_dy
        e2 += e2_dy
        e3 += e3_dy


def draw_model(model, pos, rotation, depth_buffer, screen):
    vertices, faces = model
    
    projected_vertices = []
    
    for vertex in vertices:
        vertex = rotate_x(vertex, rotation[0])
        vertex = rotate_y(vertex, rotation[1])
        vertex = rotate_z(vertex, rotation[2])

        vertex = translate(vertex, pos)

        vertex = perspective_project(vertex, fov, aspect_ratio, z_near, z_far)

        vertex = homogeneous_to_ndc(vertex)

        vertex = ndc_to_screen(vertex, screen_width, screen_height)

        projected_vertices.append(vertex)

    for i, face in enumerate(faces):
        rasterize_triangle(projected_vertices[face[0]], projected_vertices[face[1]], projected_vertices[face[2]], colors[i%4], depth_buffer, screen)

        
tetrahedron = read_obj_file("tetrahedron.obj")
monkey = read_obj_file("suzanne.obj")

angle = 0

depth_buffer = np.full((screen_width, screen_height), np.inf)

running = True
while running:
    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            running = False

    dt = clock.tick(60) / 1000.0
    angle += dt

    screen.fill(black)
    depth_buffer.fill(np.inf)

    tet_pos = [2*np.cos(angle), 0, -5 + 2*np.sin(angle)]
    draw_model(tetrahedron, tet_pos, (angle, angle, angle), depth_buffer, screen)
    
    monkey_pos = [-2*np.cos(angle), 0, -5 - 2*np.sin(angle)]
    draw_model(monkey, monkey_pos, (angle, angle, angle), depth_buffer, screen)
    
    pygame.display.flip()


pygame.quit()

