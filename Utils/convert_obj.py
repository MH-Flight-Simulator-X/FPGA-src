def parse_obj(file_path, output_path_face, output_path_vert, normalize = False):
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

    if (normalize):
        # Normalize vertices
        min_x, min_y, min_z = min(v[0] for v in vertices), min(v[1] for v in vertices), min(v[2] for v in vertices)
        max_x, max_y, max_z = max(v[0] for v in vertices), max(v[1] for v in vertices), max(v[2] for v in vertices)
        scale = max(max_x - min_x, max_y - min_y, max_z - min_z)
        vertices = [(x/scale, y/scale, z/scale) for x, y, z in vertices]

    # Write to file
    with open(output_path_face, 'w') as out_file:
        faces_str = '\n'.join(f"{i0}, {i1}, {i2}" for i0, i1, i2 in faces)
        out_file.write(faces_str)

    with open(output_path_vert, 'w') as out_file:
        vertices_str = ',\n '.join(f"{x}, {y}, {z}" for x, y, z in vertices)
        out_file.write(vertices_str)

    print(f"Data written to face: {output_path_face}    vert: {output_path_vert}")

# Add parameters when run as script
if __name__ == '__main__':
    import sys
    if len(sys.argv) < 4:
        print("Usage: python convert_obj.py input.obj output_face.txt output_vert.txt")
    elif len(sys.argv) == 4:
        parse_obj(sys.argv[1], sys.argv[2], sys.argv[3])
    elif len(sys.argv) == 5:
        parse_obj(sys.argv[1], sys.argv[2], sys.argv[3], True)
    else:
        print("Too many arguments")
