#pragma once

#include <iostream>
#include <fstream>
#include <sstream>
#include <vector>
#include <string>
#include <glm/glm.hpp>

typedef struct {
    glm::ivec2 v0;
    float v0_z;
    glm::ivec2 v1;
    float v1_z;
    glm::ivec2 v2;
    float v2_z;
} Triangle_t;

class SimDataFileHandler {
public:
    static std::vector<glm::vec3> read_vertex_data(const std::string& filename) {
        std::ifstream infile(filename);
        std::vector<glm::vec3> vertices;
        std::string line;

        if (!infile.is_open()) {
            std::cerr << "Error opening file: " << filename << std::endl;
            return vertices;
        }

        while (std::getline(infile, line)) {
            std::stringstream ss(line);
            float x, y, z;
            char comma1, comma2;

            // Parsing the "x, y, z" format
            ss >> x >> comma1 >> y >> comma2 >> z;
            if (ss.fail() || comma1 != ',' || comma2 != ',') {
                std::cerr << "Error parsing line: " << line << std::endl;
                continue;
            }

            vertices.emplace_back(x, y, z);  // Store as glm::vec3
        }

        infile.close();
        return vertices;
    }

    static std::vector<glm::ivec3> read_index_data(const std::string& filename) {
        std::ifstream infile(filename);
        std::vector<glm::ivec3> indices;
        std::string line;

        if (!infile.is_open()) {
            std::cerr << "Error opening file: " << filename << std::endl;
            return indices;
        }

        while (std::getline(infile, line)) {
            std::stringstream ss(line);
            int x, y, z;
            char comma1, comma2;

            // Parsing the "x, y, z" format
            ss >> x >> comma1 >> y >> comma2 >> z;
            if (ss.fail() || comma1 != ',' || comma2 != ',') {
                std::cerr << "Error parsing line: " << line << std::endl;
                continue;
            }

            x--; y--; z--;  // Convert to 0-based indexing
            indices.emplace_back(x, y, z);  // Store as glm::ivec3
        }

        infile.close();
        return indices;
    }

    static void write_triangle_data(const std::string& filename, std::vector<Triangle_t>& triangles) {
        std::ofstream outfile(filename);
        if (!outfile.is_open()) {
            std::cerr << "Error opening file: " << filename << std::endl;
            return;
        }

        for (const auto& tri : triangles) {
            outfile << tri.v0.x << ", " << tri.v0.y << ", " << tri.v0_z << ", " << tri.v1.x << ", " << tri.v1.y  << ", " <<  tri.v1_z << ", " << tri.v2.x << ", " << tri.v2.y  << ", " <<  tri.v2_z << std::endl;
        }

        outfile.close();
    }
};

