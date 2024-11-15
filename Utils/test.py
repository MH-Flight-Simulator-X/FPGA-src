from decimal_to_fixed import from_fixed_point_hex

vertex_width = 24
vertex_integer_width = 11
vertex_decimal_width = vertex_width - vertex_integer_width

a = from_fixed_point_hex("FFF000", vertex_integer_width, vertex_decimal_width, True)

print(a)
