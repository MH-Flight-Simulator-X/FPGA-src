import numpy as np


def read_obj_file(path: str):
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
    scale = max(max_x - min_x, max_y - min_y, max_z - min_z)
    vertices = [(x/scale, y/scale, z/scale) for x, y, z in vertices]

    return np.array(vertices), np.array(faces)
