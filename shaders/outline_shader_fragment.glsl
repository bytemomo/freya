#version 450 core

out vec4 FragColor;

void main()
{
    FragColor = vec4(0.25, 0.94, 0.96, 1.0);
    gl_FragDepth = 0.0;
}
