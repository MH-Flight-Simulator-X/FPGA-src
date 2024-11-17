#pragma once

#include <stdlib.h>

class IntConvert {
public:
    static int32_t sign_extend(int32_t a, int data_width) {
        int32_t sign = (a >> (data_width - 1)) & 1;
        int32_t sign_extended = a;
        if (sign) {
            for (int i = sizeof(int32_t) * 8 - 1; i >= data_width; i--) {
                sign_extended |= (1 << i);
            }
        }
        return sign_extended; 
    }

    // Turn int32_t into lower datawidth
    static int32_t truncate(int32_t a, int data_width) {
        int32_t truncated = a & ((1 << data_width) - 1);
        return truncated;
    }
};
