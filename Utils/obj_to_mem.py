import math
import numpy as np
from pathlib import Path
from read_obj_file import read_obj_file
from decimal_to_fixed import to_fixed_point_hex, to_fixed_point_bin

model_dir = Path(__file__).parent.parent / "algorithms/models/"
model_files = ["shrek_smol.obj"] # "suzanne.obj"

MAX_TRIANGLE_COUNT = 4096;
MAX_VERTEX_COUNT   = 4096;
MAX_INDEX_COUNT    = 4096;
MAX_MODEL_COUNT    = 16;
VERTEX_INTEGER_WIDTH = 11
VERTEX_DECIMAL_WIDTH = 13

INDEX_ADDR_WIDTH = math.ceil(math.log2(MAX_INDEX_COUNT))
VERTEX_ADDR_WIDTH = math.ceil(math.log2(MAX_VERTEX_COUNT))
FACE_WIDTH = VERTEX_ADDR_WIDTH
VERTEX_WIDTH = VERTEX_INTEGER_WIDTH + VERTEX_DECIMAL_WIDTH

with open("model_headers.mem", "w") as h_file, open("model_faces.mem", "w") as f_file, open("model_vertex.mem", "w") as v_file:
    num_faces = 0
    num_vertices = 0

    for model_file in model_files:
        print(model_dir / model_file)
        vertices, faces = read_obj_file(model_dir / model_file, 1.25, np.array([np.pi/2, 0, 0]))

        print(faces)
        print(vertices)

        # Write where faces from this model start
        h_file.write(to_fixed_point_hex((num_faces << VERTEX_ADDR_WIDTH) + num_vertices, INDEX_ADDR_WIDTH + VERTEX_ADDR_WIDTH, 0))
        h_file.write("\n")

        for face in faces:
            f_file.write(to_fixed_point_hex(((face[2]-1) << (2 * FACE_WIDTH)) + ((face[1]-1) << (FACE_WIDTH)) + face[0]-1, 3 * FACE_WIDTH, 0) + "\n")

        num_faces += len(faces)
        
        for vertex in vertices:
            x, y, z = vertex
            v_file.write(to_fixed_point_bin(z, VERTEX_INTEGER_WIDTH, VERTEX_DECIMAL_WIDTH, True))
            v_file.write(to_fixed_point_bin(y, VERTEX_INTEGER_WIDTH, VERTEX_DECIMAL_WIDTH, True))
            v_file.write(to_fixed_point_bin(x, VERTEX_INTEGER_WIDTH, VERTEX_DECIMAL_WIDTH, True) + "\n")

        num_vertices += len(vertices)
        print(f"Num faces: {num_faces} Num vertices: {num_vertices}")
        
    h_file.write(to_fixed_point_hex((num_faces << VERTEX_ADDR_WIDTH) + num_vertices, INDEX_ADDR_WIDTH + VERTEX_ADDR_WIDTH, 0))
    h_file.write("\n")
