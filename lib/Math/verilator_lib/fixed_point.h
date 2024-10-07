#pragma once
#include <cmath>
#include <iostream>
#include <cstdint>
#include <limits>

template <typename T>
class FixedPoint {
public:
    int fracBits;
    int totalBits;
    T data;

public:
    FixedPoint(T value, int fracBits, int totalBits) : fracBits(fracBits), totalBits(totalBits) {
        data = value; 
    }

    float toFloat() const {
        return static_cast<float>(data) / (1 << fracBits);
    }

    bool operator==(const float& f) const {
        float uncertainty = (float)1 / (1 << fracBits);
        return std::fabs(this->toFloat - f) <= uncertainty;
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
