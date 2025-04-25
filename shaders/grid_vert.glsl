#version 460 core

layout(location = 0) in vec2 a_position;

uniform mat4 view;
uniform mat4 projection;

out mat4 frag_view;
out mat4 frag_proj;

out vec3 near_point;
out vec3 far_point;

// Reference:
// - https://asliceofrendering.com/scene%20helper/2020/01/05/InfiniteGrid/
// - https://github.com/mnerv/lumagl/blob/trunk/src/grid.cpp

const vec3 gridPlane[4] = vec3[](
        vec3(1, -1, 0), // Bottom-right
        vec3(1, 1, 0), // Top-right
        vec3(-1, -1, 0), // Bottom-left
        vec3(-1, 1, 0) // Top-left
    );

vec3 unproject_point(float x, float y, float z, mat4 view, mat4 projection) {
    mat4 view_inv = inverse(view);
    mat4 proj_inv = inverse(projection);
    vec4 unprojected_point = view_inv * proj_inv * vec4(x, y, z, 1.0);
    return unprojected_point.xyz / unprojected_point.w;
}

void main() {
    vec3 p = gridPlane[gl_VertexID];
    near_point = unproject_point(p.x, p.y, -1.0, view, projection);
    far_point = unproject_point(p.x, p.y, 1.0, view, projection);

    frag_view = view;
    frag_proj = projection;
    gl_Position = vec4(p.x, p.y, 0.0, 1.0);
}
