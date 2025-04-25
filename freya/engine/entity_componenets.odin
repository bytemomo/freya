package engine

import glm "core:math/linalg/glsl"

Name :: string

Transform :: struct {
	position:     glm.vec3,
	rotation:     glm.vec3,
	scale:        glm.vec3,
	model_matrix: glm.mat4,
}
