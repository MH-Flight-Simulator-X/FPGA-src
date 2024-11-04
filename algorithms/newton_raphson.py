import math
import numpy as np
import matplotlib.pyplot as plt

def newton_raphson_reciprocal(A, max_iterations=4, x0 = 1.75):
    n = 0
    for i in range(24, -1, -1):
        if (A & (1 << i)):
            n = i+1
            break
    A = A / (1 << n)

    x = x0
    for i in range(max_iterations):
        x = x * (2 - A * x)

    x = x / (1 << n)

    return x

def to_fixed_point(x, n):
    return int(x * (1 << n))

def from_fixed_point(x, n):
    return x / (1 << n)

def newton_raphson_rec_fixed_point(A, x0, N, max_iterations=4):
    """
    Take in a fixed point number A and return the reciprocal of A using Newton-Raphson method.
    """
    n = 0
    for i in range(N, -1, -1):
        if (A & (1 << i)):
            n = i+1
            break
    print("n: ", n)

    A_fp = A << N
    print("A: ", hex(A_fp))
    A_fp = A_fp >> n
    print("A scaled: ", hex(A_fp))

    two_fp = 2 << N
    print("Two fp: ", hex(two_fp))

    x = x0
    print("x0: ", hex(x))

    for i in range(max_iterations):
        print("AX: ", hex(((A_fp * x) >> N)))
        print("Two_AX:", hex((two_fp - ((A_fp * x) >> N))))
        print("Result not shifted: ", hex(x * (two_fp - ((A_fp * x) >> N))))

        x = (x * (two_fp - ((A_fp * x) >> N))) >> N
        print("x", i, ": ", hex(x))

    x = x >> n
    print("Result: ", hex(x))
    return x

N = 24
A = 3
print(1/A)
x0 = to_fixed_point(1, N)

test = newton_raphson_rec_fixed_point(A, x0, N)
print(from_fixed_point(test, N))


# N = 24
#
# x0_1 = 1.25
# x0_2 = 1.5
#
# deltas_1 = []
# deltas_2 = []
#
# start = 1
# end = 320**2
#
# for A in range(start, end):
#     x0 = to_fixed_point(x0_1, N)
#     expecting = 1/A
#     newton = newton_raphson_rec_fixed_point(A, x0, N)
#     delta = abs(expecting - from_fixed_point(newton, N))
#     deltas_1.append(delta)
#
#     x0 = to_fixed_point(x0_2, N)
#     expecting = 1/A
#     newton = newton_raphson_rec_fixed_point(A, x0, N)
#     delta = abs(expecting - from_fixed_point(newton, N))
#     deltas_2.append(delta)
#
# plt.plot(np.arange(start, end), np.array(deltas_1), label=f"{x0_1}")
# plt.plot(np.arange(start, end), np.array(deltas_2), label=f"{x0_2}")
# plt.legend()
# plt.show()
