#version 450 core

in vec3 near_point;
in vec3 far_point;

in mat4 frag_view;
in mat4 frag_proj;

float near = 0.01;
float far = 1000.0;

out vec4 FragColor;

// Reference:
// - https://asliceofrendering.com/scene%20helper/2020/01/05/InfiniteGrid
// - https://github.com/mnerv/lumagl/blob/trunk/src/grid.cpp

vec4 grid(vec3 frag_pos_3d, float scale) {
    vec2 coord = frag_pos_3d.xz * scale;
    vec2 derivative = fwidth(coord);

    vec2 grid = abs(fract(coord - 0.5) - 0.5) / derivative;

    float line = min(grid.x, grid.y);
    float minimumz = min(derivative.y, 1);
    float minimumx = min(derivative.x, 1);

    vec4 color = vec4(0.30, 0.30, 0.30, 1.0 - min(line, 1.0));

    if (frag_pos_3d.x > -0.1 * minimumx && frag_pos_3d.x < 0.1 * minimumx)
        color.z = 1.0;
    if (frag_pos_3d.z > -0.1 * minimumz && frag_pos_3d.z < 0.1 * minimumz)
        color.x = 1.0;

    return color;
}

float compute_depth(vec3 pos) {
    vec4 clip_space_pos = frag_proj * frag_view * vec4(pos, 1.0);

    float clip_space_depth = clip_space_pos.z / clip_space_pos.w;
    float far = gl_DepthRange.far;
    float near = gl_DepthRange.near;
    float depth = (((far - near) * clip_space_depth) + far + near) / 2.0;

    // return clip_space_pos.z / clip_space_pos.w;
    return depth;
}

float compute_fade(vec3 point) {
    vec4 clip_space = frag_proj * frag_view * vec4(point, 1.0);
    float clip_space_depth = (clip_space.z / clip_space.w) * 2.0 - 1.0;
    float linear_depth = (2.0 * near * far) / (far + near - clip_space_depth * (far - near));
    return linear_depth / far;
}

void main() {
    float t = -near_point.y / (far_point.y - near_point.y);
    vec3 frag_pos_3d = near_point + t * (far_point - near_point);

    // float fade = smoothstep(0.04, 0.0, compute_fade(frag_pos_3d));
    float fade = max(0, 1.0 - compute_fade(frag_pos_3d));

    // This add multiple resolutions for the grid
    FragColor = (grid(frag_pos_3d, 1) + grid(frag_pos_3d, 5)) * 0.9;
    FragColor *= float(t > 0);
    FragColor *= fade;

    gl_FragDepth = compute_depth(frag_pos_3d);
}
