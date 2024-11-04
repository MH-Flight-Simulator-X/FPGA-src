#include <stdlib.h>
#include <stdio.h>
#include <glm/glm.hpp>
#include <glm/gtc//matrix_transform.hpp>
#include <glm/gtc/type_ptr.hpp>

int main() {
    glm::mat4 model = glm::mat4(1.0f);
    model = glm::translate(model, glm::vec3(0.0, 0.0, -1.0f));

    glm::mat4 view = glm::lookAt(
        glm::vec3(0.0f, 0.0f, 0.0f),  // Camera position
        glm::vec3(0.0f, 0.0f,-1.0f),  // Look at point
        glm::vec3(0.0f, 1.0f, 0.0f)   // Up vector
    );

    float fov = glm::radians(45.0f);
    float aspect = 1;
    float near = 1.0f;
    float far = 100.0f;
    glm::mat4 projection = glm::perspective(fov, aspect, near, far);

    glm::vec4 p(0.0f, 0.0f, 0.0f, 1.0f);
    glm::vec4 p_clip = projection * view * model * p;

    printf("P: %f, %f, %f, %f\n", p.x, p.y, p.z, p.w);
    printf("P_clip: %f, %f, %f, %f\n", p_clip.x, p_clip.y, p_clip.z, p_clip.w);

    glm::vec3 p_ndc = glm::vec3(p_clip.x / p_clip.w, p_clip.y / p_clip.w, p_clip.z / p_clip.w);
    printf("P_ndc: %f, %f, %f\n", p_ndc.x, p_ndc.y, p_ndc.z);

    return 0;
}
