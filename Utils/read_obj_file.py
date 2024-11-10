import numpy as np


def read_obj_file(path: str):
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