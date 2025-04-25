package renderer

import "core:log"
import "core:mem"

import glm "core:math/linalg/glsl"
import gl "vendor:OpenGL"

MAX_BONE_INFLUENCES :: 4

Vertex :: struct {
	position:   glm.vec3,
	normal:     glm.vec3,
	color:      glm.vec3,
	tex_coords: glm.vec2,
	tangent:    glm.vec3,
	bitanget:   glm.vec3,

	// Bone stuff
	bones_ids:  [MAX_BONE_INFLUENCES]i32,
	weights:    [MAX_BONE_INFLUENCES]f32,
}

Mesh :: struct {
	vertices:         []Vertex,
	indices:          []u32,
	material:         MaterialHandle,

	// Private fields
	_vao, _vbo, _ebo: u32,
	_binding_index:   u32,
	_allocator:       mem.Allocator,
}

mesh_new :: proc {
	mesh_new_explicit,
}

@(export)
mesh_free :: proc(m: ^Mesh) {
	gl.DeleteVertexArrays(1, &m._vao)
	gl.DeleteBuffers(1, &m._vbo)
	gl.DeleteBuffers(1, &m._ebo)
	delete_string(string(m.material))
	free(m, m._allocator) // Is it ok ?
}


@(export)
mesh_new_explicit :: proc(
	vertices: []Vertex,
	indices: []u32,
	material: MaterialHandle,
	allocator := context.allocator,
) -> ^Mesh {
	m := new(Mesh, allocator)
	m.vertices = vertices
	m.indices = indices
	m.material = material
	m._allocator = allocator
	_mesh_setup_buffers(m)
	return m
}

@(export)
mesh_draw_with_material :: proc(m: ^Mesh, shader: ShaderProgram) {
	if m.material != "" {
		material, err := resource_manager_get(m.material)
		if err == ResourceManagerError.NoError {
			{ 	// Diffuse
				diffuse, err := resource_manager_get_texture(material.diffuse_texture)
				if err == ResourceManagerError.NoError {
					shader_set_uniform(shader, "material.diffuse", 0)
					shader_set_uniform(shader, "useDiffuse", f32(1.0))
					gl.ActiveTexture(gl.TEXTURE0)
					gl.BindTexture(gl.TEXTURE_2D, diffuse.id)
				} else {
					shader_set_uniform(shader, "useDiffuse", f32(0.0))
				}
			}

			{ 	// Specular
				specular, err := resource_manager_get_texture(material.specular_texture)
				if err == ResourceManagerError.NoError {
					shader_set_uniform(shader, "material.specular", 1)
					shader_set_uniform(shader, "useSpecular", f32(1.0))
					gl.ActiveTexture(gl.TEXTURE0 + 1)
					gl.BindTexture(gl.TEXTURE_2D, specular.id)
				} else {
					shader_set_uniform(shader, "useSpecular", f32(0.0))
				}
			}

			{ 	// Height
				height, err := resource_manager_get_texture(material.height_texture)
				if err == ResourceManagerError.NoError {
					shader_set_uniform(shader, "material.height", 2)
					shader_set_uniform(shader, "useHeight", f32(1.0))
					gl.ActiveTexture(gl.TEXTURE0 + 2)
					gl.BindTexture(gl.TEXTURE_2D, height.id)
				} else {
					shader_set_uniform(shader, "useHeight", f32(0.0))
				}
			}

			{ 	// Normals
				height, err := resource_manager_get_texture(material.normal_texture)
				if err == ResourceManagerError.NoError {
					shader_set_uniform(shader, "material.normal", 3)
					shader_set_uniform(shader, "useNormal", f32(1.0))
					gl.ActiveTexture(gl.TEXTURE0 + 3)
					gl.BindTexture(gl.TEXTURE_2D, height.id)
				} else {
					shader_set_uniform(shader, "useNormal", f32(0.0))
				}
			}

			{ 	// Shininess
				shader_set_uniform(shader, "material.shininess", material.shininess)
			}
		}
	}

	gl.BindVertexArray(m._vao)
	gl.DrawElements(gl.TRIANGLES, i32(len(m.indices)), gl.UNSIGNED_INT, rawptr(uintptr(0)))

	gl.BindVertexArray(0)
	gl.ActiveTexture(gl.TEXTURE0)

	if gl.GetError() != gl.NO_ERROR {
		log.fatalf("OpenGL error %d", gl.GetError())
	}
}

// Private mesh procedures
@(private = "file")
_mesh_setup_buffers :: proc(m: ^Mesh) {
	// Create vao
	gl.CreateVertexArrays(1, &m._vao)
	gl.BindVertexArray(m._vao)

	// Create vbo
	gl.CreateBuffers(1, &m._vbo)
	gl.NamedBufferData(
		m._vbo,
		size_of(Vertex) * len(m.vertices),
		raw_data(m.vertices),
		gl.STATIC_DRAW,
	)

	// Create ebo
	gl.CreateBuffers(1, &m._ebo)
	gl.NamedBufferData(m._ebo, size_of(u32) * len(m.indices), raw_data(m.indices), gl.STATIC_DRAW)

	// Bind vbo-ebo to vao
	gl.VertexArrayVertexBuffer(m._vao, m._binding_index, m._vbo, 0, size_of(Vertex))
	gl.VertexArrayElementBuffer(m._vao, m._ebo)

	// Position
	gl.EnableVertexArrayAttrib(m._vao, 0)
	gl.VertexArrayAttribFormat(m._vao, 0, 3, gl.FLOAT, gl.FALSE, u32(offset_of(Vertex, position)))
	gl.VertexArrayAttribBinding(m._vao, 0, m._binding_index)

	// Normal
	gl.EnableVertexArrayAttrib(m._vao, 1)
	gl.VertexArrayAttribFormat(m._vao, 1, 3, gl.FLOAT, gl.FALSE, u32(offset_of(Vertex, normal)))
	gl.VertexArrayAttribBinding(m._vao, 1, m._binding_index)

	// Color
	gl.EnableVertexArrayAttrib(m._vao, 2)
	gl.VertexArrayAttribFormat(m._vao, 2, 3, gl.FLOAT, gl.FALSE, u32(offset_of(Vertex, color)))
	gl.VertexArrayAttribBinding(m._vao, 2, m._binding_index)

	// TexCoords
	gl.EnableVertexArrayAttrib(m._vao, 3)
	gl.VertexArrayAttribFormat(
		m._vao,
		3,
		2,
		gl.FLOAT,
		gl.FALSE,
		u32(offset_of(Vertex, tex_coords)),
	)
	gl.VertexArrayAttribBinding(m._vao, 3, m._binding_index)

	// Tangent
	gl.EnableVertexArrayAttrib(m._vao, 4)
	gl.VertexArrayAttribFormat(m._vao, 4, 3, gl.FLOAT, gl.FALSE, u32(offset_of(Vertex, tangent)))
	gl.VertexArrayAttribBinding(m._vao, 4, m._binding_index)

	// Bitangent
	gl.EnableVertexArrayAttrib(m._vao, 5)
	gl.VertexArrayAttribFormat(m._vao, 5, 3, gl.FLOAT, gl.FALSE, u32(offset_of(Vertex, bitanget)))
	gl.VertexArrayAttribBinding(m._vao, 5, m._binding_index)

	// Bones
	gl.EnableVertexArrayAttrib(m._vao, 6)
	gl.VertexArrayAttribIFormat(m._vao, 6, 4, gl.INT, u32(offset_of(Vertex, bones_ids)))
	gl.VertexArrayAttribBinding(m._vao, 6, m._binding_index)

	// Bone Weights
	gl.EnableVertexArrayAttrib(m._vao, 7)
	gl.VertexArrayAttribFormat(m._vao, 7, 4, gl.FLOAT, gl.FALSE, u32(offset_of(Vertex, weights)))
	gl.VertexArrayAttribBinding(m._vao, 7, m._binding_index)


	gl.BindVertexArray(0)
}
