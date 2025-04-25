#version 450 core
out vec4 FragColor;

in VS_OUT {
    vec3 FragPos;
    vec3 FragColor;
    vec2 TexCoords;
    mat3 TBN;
} fs_in;

struct Material {
    sampler2D diffuse; // Diffuse (albedo) map
    sampler2D specular; // Specular map
    sampler2D normal; // Normal map
    sampler2D height; // Height map for parallax mapping
    float shininess;
};

struct AmbientLight {
    vec3 position;
    vec3 ambient;
    vec3 diffuse;
    vec3 specular;
};

uniform Material material;
uniform AmbientLight ambientLight;
uniform vec3 viewPos;

uniform float useDiffuse;
uniform float useSpecular;
uniform float useNormal;

uniform float useHeight;
uniform float heightScale;

vec2 ParallaxMapping(vec2 texCoords, vec3 viewDirTangent)
{
    float heightValue = texture(material.height, texCoords).r;
    vec2 p = viewDirTangent.xy / viewDirTangent.z * (heightValue * heightScale);
    return texCoords - p;
}

void main()
{
    vec2 texCoords = fs_in.TexCoords;

    if (useHeight > 0.0) {
        vec3 viewDirTangent = normalize(fs_in.TBN * (viewPos - fs_in.FragPos));
        texCoords = ParallaxMapping(fs_in.TexCoords, viewDirTangent);
    }

    vec3 defaultColor = vec3(1.0);
    vec3 diffuseTex = texture(material.diffuse, texCoords).rgb;
    vec3 specularTex = texture(material.specular, texCoords).rgb;

    vec3 diffuseColor = mix(defaultColor, diffuseTex, useDiffuse);
    vec3 specularColor = mix(defaultColor, specularTex, useSpecular);

    // Normal mapping
    vec3 normTangent;
    if (useNormal > 0.0) {
        normTangent = texture(material.normal, texCoords).rgb;
        normTangent = normalize(normTangent * 2.0 - 1.0);
    } else {
        normTangent = vec3(0.0, 0.0, 1.0);
    }
    vec3 norm = normalize(fs_in.TBN * normTangent);

    // Ambient lighting
    vec3 ambient = ambientLight.ambient * diffuseColor;

    // Diffuse lighting
    vec3 lightDir = normalize(ambientLight.position - fs_in.FragPos);
    float diff = max(dot(norm, lightDir), 0.0);
    vec3 diffuse = ambientLight.diffuse * diff * diffuseColor;

    // Specular lighting
    vec3 viewDir = normalize(viewPos - fs_in.FragPos);
    vec3 reflectDir = reflect(-lightDir, norm);
    float spec = pow(max(dot(viewDir, reflectDir), 0.0), material.shininess);
    vec3 specular = ambientLight.specular * spec * specularColor;

    vec3 result;
    if (useSpecular > 1.0) {
        result = ambient + diffuse + specular;
    } else {
        result = ambient + diffuse;
    }
    FragColor = vec4(result, 1.0);
}
