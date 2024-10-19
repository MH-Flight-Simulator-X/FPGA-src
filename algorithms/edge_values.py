v0 = (12, 4)
v1 = (40, 90)
v2 = (111, 20)

screen_width, screen_height = (160, 120)


def compute_bounding_box(v0, v1, v2, screen_width, screen_height):
    min_x = max(int(min(v0[0], v1[0], v2[0])), 0)
    max_x = min(int(max(v0[0], v1[0], v2[0])), screen_width - 1)
    min_y = max(int(min(v0[1], v1[1], v2[1])), 0)
    max_y = min(int(max(v0[1], v1[1], v2[1])), screen_height - 1)
    return min_x, max_x, min_y, max_y


def edge_function(v0, v1, point):
    return (point[0] - v0[0]) * (v1[1] - v0[1]) - (point[1] - v0[1]) * (v1[0] - v0[0])


def print_edge_values(v0, v1, v2):
    min_x, max_x, min_y, max_y = compute_bounding_box(v0, v1, v2, screen_width, screen_height) 

    e0 = edge_function(v0, v1, (min_x, min_y))
    e1 = edge_function(v1, v2, (min_x, min_y))
    e2 = edge_function(v2, v0, (min_x, min_y))

    e0_dx = v1[1] - v0[1]
    e0_dy = -(v1[0] - v0[0])

    e1_dx = v2[1] - v1[1]
    e1_dy = -(v2[0] - v1[0])

    e2_dx = v0[1] - v2[1]
    e2_dy = -(v0[0] - v2[0])

    print(f"e0 = {e0}")
    print(f"e1 = {e1}")
    print(f"e2 = {e2}")

    print(f"e0_dx = {e0_dx}")
    print(f"e0_dy = {e0_dy}")

    print(f"e1_dx = {e1_dx}")
    print(f"e1_dy = {e1_dy}")

    print(f"e2_dx = {e2_dx}")
    print(f"e2_dy = {e2_dy}")


print_edge_values(v0, v1, v2)

