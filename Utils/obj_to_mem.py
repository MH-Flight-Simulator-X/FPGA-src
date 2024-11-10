from pathlib import Path
from read_obj_file import read_obj_file
from decimal_to_fixed import to_fixed_point_hex


model_dir = Path(__file__).parent.parent / "algorithms/models/"
model_files = ["tetrahedron.obj", "cube.obj"]

model_data_width = 16
header_face_index_width = 12
face_width = 12


with open("headers.mem", "w") as h_file, open("faces.mem", "w") as f_file, open("vertices.mem", "w") as v_file:
    num_faces = 0
    num_vertices = 0

    for model_file in model_files:
        print(model_dir / model_file)
        vertices, faces = read_obj_file(model_dir / model_file)

        print(vertices)
        print(faces)

        # Write where faces from this model start
        h_file.write(to_fixed_point_hex(num_faces, header_face_index_width, 0) + "\n")
        num_faces += len(faces)

        for face in faces:
            f_file.write(to_fixed_point_hex(face[0] + num_vertices, face_width, 0))
            f_file.write(to_fixed_point_hex(face[1] + num_vertices, face_width, 0))
            f_file.write(to_fixed_point_hex(face[2] + num_vertices, face_width, 0) + "\n")
        
        for vertex in vertices:
            x, y, z = vertex
            v_file.write(to_fixed_point_hex(x, model_data_width, 0, True))
            v_file.write(to_fixed_point_hex(y, model_data_width, 0, True))
            v_file.write(to_fixed_point_hex(z, model_data_width, 0, True) + "\n")
        
        num_vertices += len(vertices)
        
    h_file.write(to_fixed_point_hex(num_faces, header_face_index_width, 0) + "\n")
