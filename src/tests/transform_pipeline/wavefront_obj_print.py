def parse_obj(file_path):
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
                face = tuple(int(p.split('/')[0]) - 1 for p in parts[1:4])  # 1-index to 0-index
                faces.append(face)

    print(len(vertices))

    # Format the vertices and faces as required
    vertices_str = ',\n '.join(f"({x}, {y}, {z})" for x, y, z in vertices)
    faces_str = ',\n'.join(f"({i0}, {i1}, {i2})" for i0, i1, i2 in faces)

    # print("Vertices:\n", vertices_str)
    # print("\nFaces:\n", faces_str)

# Usage example:
parse_obj('../../../algorithms/suzanne.obj')
