def parse_obj(file_path, output_path_face, output_path_vert):
    vertices = []
    faces = []

    with open(file_path, 'r') as file:
        for line in file:
            if line.startswith('v '):  # Vertex coordinates
                parts = line.split()
                x, y, z = float(parts[1]), float(parts[2]), float(parts[3])
                vertices.append((x, y, z))
            elif line.startswith('f '):  # Faces (indices)
                parts = line.split()
                face = [int(p.split('/')[0]) for p in parts[1:4]]  # 1-index to 0-index
                faces.append(face)

    # Write to file
    with open(output_path_face, 'w') as out_file:
        faces_str = '\n'.join(f"{i0}, {i1}, {i2}" for i0, i1, i2 in faces)
        out_file.write(faces_str)

    with open(output_path_vert, 'w') as out_file:
        vertices_str = ',\n '.join(f"{x}, {y}, {z}" for x, y, z in vertices)
        out_file.write(vertices_str)

    print(f"Data written to face: {output_path_face}    vert: {output_path_vert}")

# Usage example:
parse_obj('../../../algorithms/amongus.obj', 'model.face', 'model.vert')
