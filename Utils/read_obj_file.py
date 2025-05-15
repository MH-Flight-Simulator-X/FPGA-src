import numpy as np


def read_obj_file(path: str, prescale = 2, rotate = np.array([0, 0, 0])):
    vertices = []
    faces = []

    with open(path, 'r') as file:
        for line in file:
            if line.startswith('v '):  # Vertex coordinates
                parts = line.split()
                x, y, z = float(parts[1]), float(parts[2]), float(parts[3])
                vertices.append((x, y, z))
            elif line.startswith('f '):  # Faces (indices)
                parts = line.split()
                face = [int(p.split('/')[0]) for p in parts[1:4]]  # 1-index to 0-index
                faces.append(face)


    min_x, min_y, min_z = min(v[0] for v in vertices), min(v[1] for v in vertices), min(v[2] for v in vertices)
    max_x, max_y, max_z = max(v[0] for v in vertices), max(v[1] for v in vertices), max(v[2] for v in vertices)

    translate_x = (max_x + min_x) / 2
    translate_y = (max_y + min_y) / 2
    translate_z = (max_z + min_z) / 2

    scale = max(max_x - min_x, max_y - min_y, max_z - min_z) * prescale
    vertices = [((x-translate_x)/scale, (y-translate_y)/scale, (z-translate_z)/scale) for x, y, z in vertices]

    ## Apply rotation
    rotation_matrix = np.array([
        [1, 0, 0],
        [0, np.cos(rotate[0]), -np.sin(rotate[0])],
        [0, np.sin(rotate[0]), np.cos(rotate[0])]
    ]) @ np.array([
        [np.cos(rotate[1]), 0, np.sin(rotate[1])],
        [0, 1, 0],
        [-np.sin(rotate[1]), 0, np.cos(rotate[1])]
    ]) @ np.array([
        [np.cos(rotate[2]), -np.sin(rotate[2]), 0],
        [np.sin(rotate[2]), np.cos(rotate[2]), 0],
        [0, 0, 1]
    ])
    vertices = [rotation_matrix @ np.array(v) for v in vertices]

    return np.array(vertices), np.array(faces)
