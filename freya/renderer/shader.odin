package renderer

import "core:log"
import "core:strings"

import glm "core:math/linalg/glsl"

import gl "vendor:OpenGL"


// NOTE: Do i need to keep track of the shader's code source path?
ShaderProgram :: u32

@(export)
shader_new :: proc(vertex_source, fragment_source: string) -> ShaderProgram {
	if program, ok := gl.load_shaders_source(vertex_source, fragment_source); ok {
		return program
	} else {
		log.panic("Failed to load shader")
	}
}

@(export)
shader_use :: proc(shader: ShaderProgram) {
	gl.UseProgram(shader)
}

@(export)
shader_delete :: proc(shader: ShaderProgram) {
	gl.DeleteProgram(shader)
}

shader_set_uniform :: proc {
	_shader_set_uniform_bool,
	_shader_set_uniform_int,
	_shader_set_uniform_float,
	_shader_set_uniform_f64,
	_shader_set_uniform_vec2,
	_shader_set_uniform_vec3,
	_shader_set_uniform_mat4,
}

@(export, private)
_shader_set_uniform_bool :: proc(shader: ShaderProgram, name: string, value: bool) {
	n := strings.unsafe_string_to_cstring(name)
	gl.Uniform1i(gl.GetUniformLocation(shader, n), i32(value))
}

@(export, private)
_shader_set_uniform_int :: proc(shader: ShaderProgram, name: string, value: i32) {
	n := strings.unsafe_string_to_cstring(name)
	gl.Uniform1i(gl.GetUniformLocation(shader, n), value)
}

@(export, private)
_shader_set_uniform_float :: proc(shader: ShaderProgram, name: string, value: f32) {
	n := strings.unsafe_string_to_cstring(name)
	gl.Uniform1f(gl.GetUniformLocation(shader, n), value)
}

@(export, private)
_shader_set_uniform_f64 :: proc(shader: ShaderProgram, name: string, value: f64) {
	n := strings.unsafe_string_to_cstring(name)
	gl.Uniform1f(gl.GetUniformLocation(shader, n), f32(value))
}

@(export, private)
_shader_set_uniform_vec2 :: proc(shader: ShaderProgram, name: string, value: ^glm.vec2) {
	n := strings.unsafe_string_to_cstring(name)
	gl.Uniform2f(gl.GetUniformLocation(shader, n), value.x, value.y)
}

@(export, private)
_shader_set_uniform_vec3 :: proc(shader: ShaderProgram, name: string, value: ^glm.vec3) {
	n := strings.unsafe_string_to_cstring(name)
	gl.Uniform3f(gl.GetUniformLocation(shader, n), value.x, value.y, value.z)
}

@(export, private)
_shader_set_uniform_mat4 :: proc(shader: ShaderProgram, name: string, value: ^glm.mat4) {
	n := strings.unsafe_string_to_cstring(name)
	gl.UniformMatrix4fv(gl.GetUniformLocation(shader, n), 1, gl.FALSE, raw_data(value))
}
