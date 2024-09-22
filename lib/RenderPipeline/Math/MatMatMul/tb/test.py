import numpy as np

matrix_data_A = np.array([
    [1.0, 2.0, 3.0, 4.0],
    [2.2, 3.2, 2.6, 1.8],
    [2.9, 4.8, 5.6, 2.4],
    [0.1, 0.8, 8.2, 6.3]
])

matrix_data_B = np.array([
    [8.8, 9.2, 5.2, 1.5],
    [9.3, 6.3, 7.3, 6.1],
    [4.4, 3.2, 2.2, 5.6],
    [7.9, 1.2, 4.5, 6.2]
])

print(matrix_data_A @ matrix_data_B)
