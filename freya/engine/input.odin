package engine

import glm "core:math/linalg/glsl"
import "vendor:glfw"

is_key_pressed :: proc(code: KeyCode) -> bool {
	return glfw.GetKey(WINDOW.glfw_window, i32(code)) == glfw.PRESS
}

is_button_pressed :: proc(button: MouseButton) -> bool {
	return glfw.GetMouseButton(WINDOW.glfw_window, i32(button)) == glfw.PRESS
}

get_mouse_position :: proc() -> glm.vec2 {
	x, y := glfw.GetCursorPos(WINDOW.glfw_window)
	return {f32(x), f32(y)}
}
