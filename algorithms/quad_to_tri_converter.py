def convert_obj_quads_to_tris(input_file, output_file):
    with open(input_file, 'r') as infile, open(output_file, 'w') as outfile:
        for line in infile:
            # Check for face (f) lines
            if line.startswith('f '):
                parts = line.split()
                if len(parts) == 5:
                    # It's a quad, convert it to two triangles
                    v1, v2, v3, v4 = parts[1], parts[2], parts[3], parts[4]
                    # Write two triangles to the output
                    outfile.write(f"f {v1} {v2} {v3}\n")
                    outfile.write(f"f {v1} {v3} {v4}\n")
                else:
                    # For non-quads, just write the line as is
                    outfile.write(line)
            else:
                # Write non-face lines as is
                outfile.write(line)

# Usage example
convert_obj_quads_to_tris('tree.obj', 'tree_tri.obj')
