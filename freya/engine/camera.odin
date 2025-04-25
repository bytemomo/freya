package engine

import "core:fmt"
import "core:math"
import glm "core:math/linalg/glsl"


// Perspective camera
PerspectiveCamera :: struct {
	view_mat: glm.mat4,
	proj_mat: glm.mat4,

	// Camera vectors
	_up:      glm.vec3,
	_eye:     glm.vec3,
	_center:  glm.vec3,
}

camera_new_perspective :: proc(fov, aspect_ratio, near, far: f32) -> PerspectiveCamera {
	camera := PerspectiveCamera{}
	camera_set_projection(&camera, fov, aspect_ratio, near, far)
	camera_calculate_view_matrix(&camera)
	return camera
}

camera_set_projection :: proc(camera: ^PerspectiveCamera, fov, aspect_ratio, near, far: f32) {
	camera.proj_mat = glm.mat4Perspective(glm.radians(fov), aspect_ratio, near, far)
}

camera_calculate_view_matrix :: proc(camera: ^PerspectiveCamera) {
	camera.view_mat = glm.mat4LookAt(camera._eye, camera._center, camera._up)
}

// General methods

camera_on_update :: proc {
	fps_camera_on_update,
	editor_camera_on_update,
}

camera_on_event :: proc {
	fps_camera_on_event,
	editor_camera_on_event,
}

// Editor Camera controller

EditorCameraController :: struct {
	using camera:       PerspectiveCamera,

	// Private
	_aspect_ratio:      f32,
	_fov:               f32,
	_near, _far:        f32,
	_yaw, _pitch:       f32,
	_distance:          f32,

	//
	_right:             glm.vec3,
	_forward:           glm.vec3,
	_position:          glm.vec3,
	_focus:             glm.vec3,

	//
	_rotation_speed:    f32,
	_translation_speed: f32,

	//
	_first_mouse:       bool,
	_last_mouse_pos:    glm.vec2,
}

new_editor_camera_controller :: proc(
	aspect_ratio: f32,
	fov: f32 = 45.0,
	near: f32 = 0.1,
	far: f32 = 1000.0,
) -> EditorCameraController {
	return EditorCameraController {
		camera = camera_new_perspective(fov, aspect_ratio, near, far),
		_aspect_ratio = aspect_ratio,
		_fov = fov,
		_near = near,
		_far = far,
		_yaw = -90.0,
		_pitch = 0.0,
		_distance = 10.0,
		_right = {1.0, 0.0, 0.0},
		_forward = {0.0, 0.0, -1.0},
		_position = {0.0, 0.0, 0.0},
		_focus = {0.0, 0.0, 0.0},
		_rotation_speed = 0.1,
		_translation_speed = 0.1,
		_first_mouse = true,
	}
}

editor_camera_on_event :: proc(controller: ^EditorCameraController, event: Event) {
	#partial switch e in event {
	case ImGuiViewportResizeEvent:
		{
			controller._aspect_ratio = f32(e.width) / f32(e.height)
			camera_set_projection(
				&controller.camera,
				controller._fov,
				controller._aspect_ratio,
				controller._near,
				controller._far,
			)
		}
	case MouseScrollEvent:
		{
			delta := e.y
			controller._distance -= delta * glm.clamp(controller._distance * 0.1, 0.1, 100.0)
			controller._distance = glm.clamp(controller._distance, 0.1, 1000.0)
		}
	}
}

editor_camera_on_update :: proc(controller: ^EditorCameraController, dt: f64) {
	position := get_mouse_position()

	if controller._first_mouse {
		controller._last_mouse_pos = position
		controller._first_mouse = false
	}

	xoffset := position.x - controller._last_mouse_pos.x
	yoffset := position.y - controller._last_mouse_pos.y
	controller._last_mouse_pos = position

	if is_button_pressed(MouseButton.ButtonMiddle) || is_key_pressed(KeyCode.RightAlt) {
		controller._yaw += xoffset * controller._rotation_speed
		controller._pitch -= yoffset * controller._rotation_speed
		controller._pitch = glm.clamp(controller._pitch, -89.0, 89.0)
	}

	if is_button_pressed(MouseButton.ButtonLeft) {
		// controller._focus += controller._right * xoffset * controller._translation_speed
		// controller._focus -= controller._up * yoffset * controller._translation_speed

		translation :=
			(-controller._right * xoffset + controller._up * yoffset) *
			controller._translation_speed
		controller._focus += translation
		controller._position += translation
	}

	// Update camera position to orbit around focus point
	direction: glm.vec3
	direction.x = math.cos(glm.radians(controller._yaw)) * math.cos(glm.radians(controller._pitch))
	direction.y = math.sin(glm.radians(controller._pitch))
	direction.z = math.sin(glm.radians(controller._yaw)) * math.cos(glm.radians(controller._pitch))

	controller._forward = glm.normalize(direction)
	controller._position = controller._focus - controller._forward * controller._distance
	controller._right = glm.normalize(glm.cross(controller._forward, glm.vec3{0, 1, 0}))
	controller._up = glm.normalize(glm.cross(controller._right, controller._forward))

	controller.camera._eye = controller._position
	controller.camera._center = controller._focus
	camera_calculate_view_matrix(&controller.camera)
}

// FSP Camera controller
FPSCameraController :: struct {
	using camera:       PerspectiveCamera,

	// Private
	_aspect_ratio:      f32,
	_fov:               f32,
	_near, _far:        f32,
	_yaw, _pitch:       f32,

	//
	_right:             glm.vec3,
	_forward:           glm.vec3,
	_position:          glm.vec3,

	//
	_rotation_speed:    f32,
	_translation_speed: f32,

	//
	_first_mouse:       bool,
	_last_mouse_pos:    glm.vec2,
}

new_fps_camera_controller :: proc(
	aspect_ratio: f32,
	fov: f32 = 45.0,
	near: f32 = 0.1,
	far: f32 = 1000.0,
) -> FPSCameraController {
	return FPSCameraController {
		camera             = camera_new_perspective(fov, aspect_ratio, near, far),

		//
		_aspect_ratio      = aspect_ratio,
		_fov               = fov,
		_near              = near,
		_far               = far,
		_yaw               = -90.0,
		_pitch             = 0.0,

		//
		_right             = {0.0, 0.0, 0.0},
		_forward           = {0.0, 0.0, -1.0},
		_position          = {0.0, 0.0, 0.0},

		//
		_rotation_speed    = 10.0,
		_translation_speed = 10.0,

		// Camera parameter based on OpenGL
		_up                = {0.0, 1.0, 0.0},
		_eye               = {0.0, 0.0, 0.0},
		_center            = {0.0, 0.0, 0.0},

		//
		_first_mouse       = true,
	}
}

fps_camera_on_event :: proc(controller: ^FPSCameraController, event: Event) {
	#partial switch e in event {
	case ImGuiViewportResizeEvent:
		{
			controller._aspect_ratio = f32(e.width) / f32(e.height)
			camera_set_projection(
				&controller.camera,
				controller._fov,
				controller._aspect_ratio,
				controller._near,
				controller._far,
			)
		}
	}
}

fps_camera_on_update :: proc(controller: ^FPSCameraController, dt: f64) {
	{ 	// Keyboard input
		if (is_key_pressed(.W)) {
			controller._position +=
				controller._forward * controller._translation_speed * {f32(dt), f32(dt), f32(dt)}
		} else if (is_key_pressed(.S)) {
			controller._position -=
				controller._forward * controller._translation_speed * {f32(dt), f32(dt), f32(dt)}
		}

		if (is_key_pressed(.D)) {
			controller._position +=
				controller._right * controller._translation_speed * {f32(dt), f32(dt), f32(dt)}
		} else if (is_key_pressed(.A)) {
			controller._position -=
				controller._right * controller._translation_speed * {f32(dt), f32(dt), f32(dt)}
		}

		if (is_key_pressed(.Space)) {
			controller._position +=
				controller._up * controller._translation_speed * {f32(dt), f32(dt), f32(dt)}
		} else if (is_key_pressed(.LeftShift)) {
			controller._position -=
				controller._up * controller._translation_speed * {f32(dt), f32(dt), f32(dt)}
		}
	}

	{ 	// Mouse input

		position := get_mouse_position()

		if (controller._first_mouse) {
			controller._last_mouse_pos = position
			controller._first_mouse = false
		}

		xoffset := position.x - controller._last_mouse_pos.x
		yoffset := position.y - controller._last_mouse_pos.y

		controller._last_mouse_pos = position

		controller._yaw += xoffset * controller._rotation_speed * f32(dt)
		controller._pitch -= yoffset * controller._rotation_speed * f32(dt)
		if (controller._pitch > 89.0) {
			controller._pitch = 89.0
		}
		if (controller._pitch < -89.0) {
			controller._pitch = -89.0
		}
	}

	{ 	// Update view matrix
		direction: glm.vec3
		direction.x =
			math.cos(glm.radians(controller._yaw)) * math.cos(glm.radians(controller._pitch))
		direction.y = math.sin(glm.radians(controller._pitch))
		direction.z =
			math.sin(glm.radians(controller._yaw)) * math.cos(glm.radians(controller._pitch))

		controller._forward = glm.normalize(direction)
		controller._right = glm.normalize(glm.cross(controller._forward, glm.vec3{0, 1, 0}))
		controller._up = glm.normalize(glm.cross(controller._right, controller._forward))

		controller._eye = controller._position
		controller._center = controller._position + controller._forward
		camera_calculate_view_matrix(&controller.camera)
	}
}
