package renderer

import "core:log"

Material :: struct {
	name:             string,
	diffuse_texture:  TextureHandle,
	specular_texture: TextureHandle,
	normal_texture:   TextureHandle,
	height_texture:   TextureHandle,
	shininess:        f64,
}

material_new :: proc(
	name: string,
	diffuse, specular, height, normal: TextureHandle,
	shininess: f64,
) -> ^Material {
	m := new(Material)
	m.name = name
	m.diffuse_texture = diffuse
	m.specular_texture = specular
	m.height_texture = height
	m.normal_texture = normal
	m.shininess = shininess
	return m
}

material_free :: proc(m: ^Material) {
	resource_manager_delete_texture(m.diffuse_texture)
	resource_manager_delete_texture(m.specular_texture)
	resource_manager_delete_texture(m.height_texture)
	resource_manager_delete_texture(m.normal_texture)
	delete_string(m.name)
	free(m)
}
