package imguizmo

import im "../odin-imgui"
import "base:intrinsics"
import glm "core:math/linalg/glsl"

when ODIN_OS == .Linux || ODIN_OS == .Darwin {@(require) foreign import stdcpp "system:c++"}

when ODIN_OS == .Linux {
	when ODIN_ARCH == .amd64 {
		foreign import lib "ImGuizmo/libImGuizmo.a"
	} else {
		#panic("Unsupported architecture")
	}
}when ODIN_OS == .Windows {
	#panic("Windows is not supported yet")
} else when ODIN_OS == .Darwin {
	#panic("macOS is not supported yet")
}


// Enum definitions
Operation :: enum {
	TRANSLATE = 7,
	ROTATE    = 120,
	SCALE     = 896,
	SCALEU    = 14336,
	UNIVERSAL = 14463,
}

Mode :: enum {
	LOCAL = 0,
	WORLD = 1,
}

@(private)
foreign lib {
	@(link_name = "BeginFrame")
	BeginFrame :: proc() ---

	@(link_name = "IsOver")
	IsOver :: proc() -> bool ---

	@(link_name = "IsUsing")
	IsUsing :: proc() -> bool ---

	@(link_name = "Enable")
	Enable :: proc(enable: bool) ---

	@(link_name = "DecomposeMatrixToComponents")
	DecomposeMatrixToComponents :: proc(mat: [^]f32, translation: [^]f32, rotation: [^]f32, scale: [^]f32) ---

	@(link_name = "RecomposeMatrixFromComponents")
	RecomposeMatrixFromComponents :: proc(translation: [^]f32, rotation: [^]f32, scale: [^]f32, mat: [^]f32) ---

	@(link_name = "DrawCube")
	DrawCube :: proc(view: [^]f32, projection: [^]f32, mat: [^]f32) ---

	@(link_name = "Manipulate")
	Manipulate :: proc(view: [^]f32, projection: [^]f32, operation: Operation, mode: Mode, mat: [^]f32, delta_matrix: [^]f32 = nil, snap: [^]f32 = nil) -> bool ---

	@(link_name = "SetRect")
	SetRect :: proc(x, y, width, height: f32) ---

	@(link_name = "SetOrthographic")
	SetOrthographic :: proc(is_orthographic: bool) ---

	@(link_name = "SetDrawlist")
	SetDrawList :: proc(drawlist: ^im.DrawList = nil) ---
}

// Helper function to create a slice from a raw pointer and length
make_slice_from_ptr :: proc(ptr: [^]f32, length: int) -> []f32 {
	return ptr[:length]
}

begin_frame :: proc() {
	BeginFrame()
}

is_over :: proc() -> bool {
	return IsOver()
}

is_using :: proc() -> bool {
	return IsUsing()
}

enable :: proc(enable: bool) {
	Enable(enable)
}

draw_cube :: proc(view, projection, mat: []f32) {
	DrawCube(raw_data(view), raw_data(projection), raw_data(mat))
}

manipulate :: proc(
	view, projection, mat: ^matrix[4, 4]f32,
	operation: Operation,
	mode: Mode,
	delta_matrix: []f32 = nil,
	snap: []f32 = nil,
) -> bool {
	return Manipulate(
		&view[0, 0],
		&projection[0, 0],
		operation,
		mode,
		&mat[0, 0],
		delta_matrix != nil ? raw_data(delta_matrix) : nil,
		snap != nil ? raw_data(snap) : nil,
	)
}

decompose_matrix_to_components :: proc(
	mat: ^matrix[4, 4]f32,
	translation, rotation, scale: ^glm.vec3,
) {
	DecomposeMatrixToComponents(&mat[0, 0], &translation[0], &rotation[0], &scale[0])
}

set_rect :: proc(x, y, width, height: f32) {
	SetRect(x, y, width, height)
}

set_orthographic :: proc(is_orthographic: bool) {
	SetOrthographic(is_orthographic)
}

set_draw_list :: proc(drawlist: ^im.DrawList = nil) {
	SetDrawList(drawlist)
}
