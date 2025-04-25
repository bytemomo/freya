package renderer

import "core:strings"

import ecs "../../freya/vendor/odin-ecs"
import glm "core:math/linalg/glsl"

import engine "../engine"

AmbientLight :: struct {
	position: glm.vec3,
	ambient:  glm.vec3,
	diffuse:  glm.vec3,
	specular: glm.vec3,
	_model:   ^Model,
}

ambientlight_add_from_entity_world :: proc(
	world: ^ecs.Context,
	name: engine.Name,
	position: glm.vec3,
	ambient: glm.vec3,
	diffuse: glm.vec3,
	specular: glm.vec3,
) -> ^AmbientLight {
	light := new(AmbientLight)
	light.position = position
	light.ambient = ambient
	light.diffuse = diffuse
	light.specular = specular


	model := new(Model)
	model.bone_count = 0
	model.materials = {}
	model.bone_info_map = {}

	append(&model.meshes, new_cube_mesh({}))

	light._model = model

	transform := engine.Transform {
		position = position,
		rotation = glm.vec3{0.0, 0.0, 0.0},
		scale    = glm.vec3{1.0, 1.0, 1.0},
	}

	transform.model_matrix =
		glm.mat4Translate(transform.position) *
		glm.mat4Rotate({1, 0, 0}, transform.rotation.x) *
		glm.mat4Rotate({0, 1, 0}, transform.rotation.y) *
		glm.mat4Rotate({0, 0, 1}, transform.rotation.z) *
		glm.mat4Scale(transform.scale)

	ent := ecs.create_entity(world)
	ecs.add_component(world, ent, light)
	ecs.add_component(world, ent, transform)
	ecs.add_component(world, ent, strings.clone(name))

	return light
}

ambientlight_remove_from_entity_world :: proc(name: engine.Name, world: ^ecs.Context) {
	light: ^AmbientLight
	for ent in ecs.get_entities_with_components(world, {^AmbientLight, engine.Name}) {
		n, _ := ecs.get_component(world, ent, engine.Name)
		if name == n^ {
			delete_string(n^)
			l, _ := ecs.get_component(world, ent, ^AmbientLight)
			light = l^
			break
		}
	}

	model_free(light._model)
	free(light)
}
