#version 450 core
layout(location = 0) in vec3 aPos; // vertex position
layout(location = 1) in vec3 aNormal; // vertex normal (in object space)
layout(location = 2) in vec3 aColor; // vertex color
layout(location = 3) in vec2 aTexCoords; // texture coordinates
layout(location = 4) in vec3 aTangent; // tangent vector
layout(location = 5) in vec3 aBitangent; // bitangent vector
layout(location = 6) in ivec4 aBoneIds; // bone ids
layout(location = 7) in vec4 aWeights; // bone weights

out VS_OUT {
    vec3 FragPos;
    vec3 FragColor;
    vec2 TexCoords;
    mat3 TBN;
} vs_out;

uniform mat4 model;
uniform mat4 view;
uniform mat4 projection;

const float outlineThickness = 0.07;
const int MAX_BONES = 1000;
const int MAX_BONE_INFLUENCE = 4;
uniform mat4 gBonesTransformation[MAX_BONES];

uniform float hasAnimation;

void main()
{
    vec4 worldPos;
    mat3 normalMatrix = mat3(1.0);
    if (hasAnimation == 1.0) {
        mat4 BoneTransform;
        vec4 totalPosition = vec4(0.0f);
        for (int i = 0; i < MAX_BONE_INFLUENCE; i++)
        {
            if (aBoneIds[i] == -1)
                continue;
            if (aBoneIds[i] >= MAX_BONES)
            {
                totalPosition = vec4(aPos, 1.0f);
                break;
            }
            BoneTransform += gBonesTransformation[aBoneIds[i]] * aWeights[i];
            totalPosition += gBonesTransformation[aBoneIds[i]] * aWeights[i] * vec4(aPos, 1.0f);
        }
        normalMatrix = transpose(inverse(mat3(BoneTransform)));
        vec3 transformedNormal = normalize(normalMatrix * aNormal);
        vec3 inflatedPos = totalPosition.xyz + ((transformedNormal * outlineThickness) / 5.0f);

        worldPos = model * vec4(inflatedPos, 1.0);
    } else {
        normalMatrix = mat3(model);

        vec3 transformedNormal = normalize(normalMatrix * aNormal);
        vec3 inflatedPos = aPos + ((transformedNormal * outlineThickness) / 5.0f);

        worldPos = model * vec4(inflatedPos, 1.0);
    }

    vs_out.FragPos = worldPos.xyz;
    vs_out.FragColor = aColor;
    vs_out.TexCoords = aTexCoords;

    vec3 T = normalize(normalMatrix * aTangent);
    vec3 B = normalize(normalMatrix * aBitangent);
    vec3 N = normalize(normalMatrix * aNormal);
    vs_out.TBN = mat3(T, B, N);

    gl_Position = projection * view * worldPos;
}
