#pragma once
#include <cmath>
#include <iostream>
#include <cstdint>
#include <limits>
#include <bitset>

template <typename T>
class FixedPoint {
public:
    int fracBits;
    int totalBits;
    T data;

    bool sign = true;

public:
    FixedPoint(T value, int fracBits, int totalBits, bool sign = true) : fracBits(fracBits), totalBits(totalBits), sign(sign) {
        data = value; 
    }

    float toFloat() const {
        if (sign) {
            // Sign extend
            int sign = (data >> (totalBits - 1)) & 1;
            T sign_extended = data;
            if (sign) {
                for (int i = sizeof(T) * 8 - 1; i >= totalBits; i--) {
                    sign_extended |= (1 << i);
                }
            }

            float f = static_cast<float>(sign_extended) / (1 << fracBits);
            return f;
        }

        float f = static_cast<float>(data) / (1 << fracBits);
        return f;
    }

    bool operator==(const float& f) const {
        float uncertainty = (float)1 / (1 << fracBits);
        return std::fabs(this->toFloat() - f) <= uncertainty;
    }

    static FixedPoint fromFloat(float f, int fracBits, int totalBits) {
        T value = static_cast<T>(std::round(f * (1 << fracBits)));
        return FixedPoint(value, fracBits, totalBits);
    }

    T get() const {
        return data;
    }

    std::pair<int, int> getFormat() {
        return std::make_pair(totalBits - fracBits, fracBits);
    }
};
