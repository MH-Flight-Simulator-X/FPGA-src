v0 = (8, 4, 0.5)
v1 = (20, 30, 0.5)
v2 = (40, 20, 0.1)

screen_width, screen_height = (160, 120)

def compute_bounding_box(v0, v1, v2, screen_width, screen_height):
    min_x = max(int(min(v0[0], v1[0], v2[0])), 0)
    max_x = min(int(max(v0[0], v1[0], v2[0])), screen_width - 1)
    min_y = max(int(min(v0[1], v1[1], v2[1])), 0)
    max_y = min(int(max(v0[1], v1[1], v2[1])), screen_height - 1)
    return min_x, max_x, min_y, max_y


def edge_function(v0, v1, point):
    return (point[0] - v0[0]) * (v1[1] - v0[1]) - (point[1] - v0[1]) * (v1[0] - v0[0])


def print_constants(v0, v1, v2):
    min_x, max_x, min_y, max_y = compute_bounding_box(v0, v1, v2, screen_width, screen_height) 
    print("Bounding box:")
    print(f"Top left: {min_x, min_y}")
    print(f"Bottom right: {max_x, max_y}")
    print("")

    e0 = edge_function(v0, v1, (min_x, min_y))
    e1 = edge_function(v1, v2, (min_x, min_y))
    e2 = edge_function(v2, v0, (min_x, min_y))

    print("Edge Coefficients:")
    print(f"e0 = {e0}")
    print(f"e1 = {e1}")
    print(f"e2 = {e2}")
    print("")

    e0_dx = v1[1] - v0[1]
    e0_dy = -(v1[0] - v0[0])

    e1_dx = v2[1] - v1[1]
    e1_dy = -(v2[0] - v1[0])

    e2_dx = v0[1] - v2[1]
    e2_dy = -(v0[0] - v2[0]) 

    print("Edge deltas")
    print(f"Edge 0: {e0_dx, e0_dy}")
    print(f"Edge 1: {e1_dx, e1_dy}")
    print(f"Edge 2: {e2_dx, e2_dy}")
    print("")

    area = edge_function(v0, v1, v2) 
    area_reciprocal = 1 / area

    print(f"area = {area}")
    print(f"area_reciprocal = {area_reciprocal}")
    print("")

    w0 = e0 / area
    w1 = e1 / area
    w2 = e2 / area

    print(f"w0 = {w0}")
    print(f"w1 = {w1}")
    print(f"w2 = {w2}")

    w0_dx = e0_dx / area
    w0_dy = e0_dy / area

    w1_dx = e1_dx / area
    w1_dy = e1_dy / area

    w2_dx = e2_dx / area
    w2_dy = e2_dy / area

    print(f"w0_dx = {w0_dx}")
    print(f"w0_dy = {w0_dy}")

    print(f"w1_dx = {w1_dx}")
    print(f"w1_dy = {w1_dy}")

    print(f"w2_dx = {w2_dx}")
    print(f"w2_dy = {w2_dy}")

    z = (w0 * v0[2]) + (w1 * v1[2]) + (w2 * v2[2])
    z_dx = (w0_dx * v0[2]) + (w1_dx * v1[2]) + (w2_dx * v2[2])
    z_dy = (w0_dy * v0[2]) + (w1_dy * v1[2]) + (w2_dy * v2[2])

    print(f"z = {z}")
    print(f"z_dx = {z_dx}")
    print(f"z_dy = {z_dy}")


print_constants(v0, v1, v2)

