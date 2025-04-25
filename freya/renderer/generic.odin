package renderer

import "base:runtime"

import "core:log"
import glm "core:math/linalg/glsl"

import gl "vendor:OpenGL"
import "vendor:glfw"

OpenGlCapability :: enum {
	DEPTH_TEST   = gl.DEPTH_TEST,
	STENCIL_TEST = gl.STENCIL_TEST,
	SCISSOR_TEST = gl.SCISSOR_TEST,
	CULL_FACE    = gl.CULL_FACE,
	BLEND        = gl.BLEND,
	DEBUG_OUTPUT = gl.DEBUG_OUTPUT,
}

initialize_context :: proc() {
	gl.load_up_to(4, 6, glfw.gl_set_proc_address)
}

@(export)
clear_screen :: proc(color: glm.vec4) {
	gl.ClearColor(color.r, color.g, color.b, color.a)
	gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT | gl.STENCIL_BUFFER_BIT)
}

@(export)
draw_grid :: proc() {
	emptyVAO: u32
	gl.GenVertexArrays(1, &emptyVAO)
	gl.BindVertexArray(emptyVAO)
	gl.DrawArrays(gl.TRIANGLE_STRIP, 0, 4)
	assert(gl.GetError() == gl.NO_ERROR, "OpenGL error")
}

on_window_resize :: proc(w, h: i32) {
	gl.Viewport(0, 0, w, h)
}

debug_callback :: proc "c" (
	source: u32,
	type: u32,
	id: u32,
	severity: u32,
	length: i32,
	message: cstring,
	userParam: rawptr,
) {
	context = runtime.default_context()
	logger := log.create_console_logger()
	context.logger = logger
	defer log.destroy_console_logger(logger)

	// TODO: not yet implemented
	log.infof("OpenGL debug message: {}", message)
}

@(export)
enable_capabilities :: proc(cap: []OpenGlCapability) {
	gl.Enable(gl.MULTISAMPLE)

	for c in cap {
		gl.Enable(u32(c))
		if c == .BLEND {
			gl.BlendEquation(gl.FUNC_ADD)
			gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)
		} else if c == .DEPTH_TEST {
			// Last element drawn are in from of all other fragments
			gl.DepthFunc(gl.LESS)
		} else if c == .CULL_FACE {
			gl.CullFace(gl.BACK)
			gl.FrontFace(gl.CCW)
		} else if c == .DEBUG_OUTPUT {
			gl.Enable(gl.DEBUG_OUTPUT)
			gl.DebugMessageCallback(debug_callback, nil)
		} else if c == .STENCIL_TEST {
			gl.Enable(gl.STENCIL_TEST)
			gl.StencilFunc(gl.NOTEQUAL, 1, 0xFF)
			gl.StencilOp(gl.KEEP, gl.KEEP, gl.REPLACE)
		}
	}
}

disable_capabilities :: proc(cap: []OpenGlCapability) {
	for c in cap {
		gl.Disable(u32(c))
	}
}

toggle_depth_writing :: proc(enable: bool) {
	if enable {
		gl.DepthMask(gl.TRUE)
	} else {
		gl.DepthMask(gl.FALSE)
	}
}

toggle_wire_mode :: proc(enable: bool) {
	if enable {
		gl.PolygonMode(gl.FRONT_AND_BACK, gl.LINE)
	} else {
		gl.PolygonMode(gl.FRONT_AND_BACK, gl.FILL)
	}
}

enable_stencil_testing :: proc() {
	gl.StencilFunc(gl.ALWAYS, 1, 0xFF)
	gl.StencilMask(0xFF)
}

disable_stencil_testing :: proc() {
	gl.StencilFunc(gl.NOTEQUAL, 1, 0xFF)
	gl.StencilMask(0x00)
	// gl.Disable(gl.DEPTH_TEST)
}

reset_stencil_testing :: proc() {
	gl.StencilMask(0xFF)
	gl.StencilFunc(gl.ALWAYS, 1, 0xFF)
	// gl.Enable(gl.DEPTH_TEST)
}

set_depth_func_to_default :: proc() {
	gl.DepthFunc(gl.LESS)
}

set_depth_func_to_equal :: proc() {
	gl.DepthFunc(gl.LEQUAL)
}
