package animagik

import "core:fmt"

import gui_panels "panels"

import freya "../freya"
import engine "../freya/engine"
import renderer "../freya/renderer"

import glm "core:math/linalg/glsl"

import ecs "../freya/vendor/odin-ecs"

import im "../freya/vendor/odin-imgui"
import guizmo "../freya/vendor/odin-imguizmo"

camera_controller: engine.EditorCameraController
viewport_fb: ^renderer.FrameBuffer
cubemap: ^renderer.Cubemap

scene_panel: ^gui_panels.ScenePanel

entities_world: ecs.Context

is_viewport_overed: bool = false
is_cursor_captured: bool = true
is_wire_mode: bool = false
guizmo_is_enabled: bool = true

last_frame_time: f64 = 0.0

currentGirmoOperation: guizmo.Operation = guizmo.Operation.ROTATE
currentGizmoMode: guizmo.Mode = guizmo.Mode.WORLD

GuiLayer :: struct {
	using base: engine.Layer,
}

gui_layer_new :: proc() -> ^GuiLayer {
	layer := new(GuiLayer)
	layer.initialize = initialize
	layer.shutdown = shutdown
	layer.update = update
	layer.render = render
	layer.imgui_render = imgui_render
	layer.on_event = on_event
	layer.is_active = true
	return layer
}

initialize :: proc() {
	renderer.enable_capabilities(
		{
			renderer.OpenGlCapability.CULL_FACE,
			renderer.OpenGlCapability.DEPTH_TEST,
			renderer.OpenGlCapability.STENCIL_TEST,
			renderer.OpenGlCapability.BLEND,
		},
	)

	camera_controller = engine.new_editor_camera_controller(800.0 / 600.0)

	viewport_fb = renderer.framebuffer_new(
		800,
		600,
		{renderer.FrameBufferAttachment.Color, renderer.FrameBufferAttachment.DepthStencil},
	)

	entities_world = ecs.init_ecs()
	{ 	// TODO: Remove this code, only to try gui
		{
			ent := ecs.create_entity(&entities_world)
			model_component, animation := renderer.model_new_with_anim(
				"assets/models/lowpoly_dragon/scene.gltf",
			)


			animator_component := renderer.animator_new(animation)
			ecs.add_component(&entities_world, ent, model_component)
			ecs.add_component(&entities_world, ent, animator_component)

			t := engine.Transform {
				glm.vec3{0.0, 0.0, 0.0},
				glm.vec3{0.0, 0.0, 0.0},
				glm.vec3{0.7, 0.7, 0.7},
				glm.mat4Translate({0.0, 0.0, 0.0}),
			}
			t.model_matrix =
				glm.mat4Translate(t.position) *
				glm.mat4Rotate({1, 0, 0}, t.rotation.x) *
				glm.mat4Rotate({0, 1, 0}, t.rotation.y) *
				glm.mat4Rotate({0, 0, 1}, t.rotation.z) *
				glm.mat4Scale(t.scale)
			ecs.add_component(&entities_world, ent, t)
			ecs.add_component(&entities_world, ent, engine.Name("Dragon"))
		}

		{ 	// Ambient light
			renderer.ambientlight_add_from_entity_world(
				&entities_world,
				engine.Name("Ambient Light 1"),
				glm.vec3{10.0, 10.0, 20.0},
				glm.vec3{0.5, 0.5, 0.5},
				glm.vec3{1.0, 1.0, 1.0},
				glm.vec3{1.0, 1.0, 1.0},
			)
		}
	}

	{ 	// Cubemap, TODO: Check error
		cubemap, _ = renderer.cubemap_new(
			{
				"assets/skyboxes/normal_sky/right.jpg",
				"assets/skyboxes/normal_sky/left.jpg",
				"assets/skyboxes/normal_sky/top.jpg",
				"assets/skyboxes/normal_sky/bottom.jpg",
				"assets/skyboxes/normal_sky/front.jpg",
				"assets/skyboxes/normal_sky/back.jpg",
			},
		)
	}


	{ 	// Gui panels
		scene_panel = gui_panels.scene_panel_new(&entities_world)
	}
}

shutdown :: proc() {
	renderer.framebuffer_free(viewport_fb)
	renderer.cubemap_free(cubemap)

	{ 	// Clear entities world
		// TODO: Get all entities and free them in the correct way

		for ent in ecs.get_entities_with_components(
			&entities_world,
			{^renderer.Model, engine.Transform},
		) {
			model, _ := ecs.get_component(&entities_world, ent, ^renderer.Model)
			renderer.model_free(model^)
		}

		for ent in ecs.get_entities_with_components(&entities_world, {^renderer.Animator}) {
			animator, _ := ecs.get_component(&entities_world, ent, ^renderer.Animator)
			renderer.animator_free(animator^)
		}

		renderer.ambientlight_remove_from_entity_world(
			engine.Name("Ambient Light 1"),
			&entities_world,
		)

		ecs.deinit_ecs(&entities_world)
	}

	{ 	// Gui panels
		gui_panels.scene_panel_destroy(scene_panel)
	}
}

update :: proc(dt: f64) {
	last_frame_time = dt

	if is_viewport_overed && !guizmo.is_using() {
		engine.camera_on_update(&camera_controller, dt)
	}

	for ent in ecs.get_entities_with_components(&entities_world, {^renderer.Animator}) {
		animator, _ := ecs.get_component(&entities_world, ent, ^renderer.Animator)
		renderer.animator_update_animation(animator^, dt)
	}
}

render :: proc() {
	renderer.framebuffer_bind(viewport_fb)
	renderer.clear_screen({0.28, 0.28, 0.28, 1.0})

	{ 	// Render entities
		ambient_light: ^renderer.AmbientLight = nil
		{ 	// Render lights
			for ent in ecs.get_entities_with_components(
				&entities_world,
				{^renderer.AmbientLight},
			) {
				ambient_light_comp, err := ecs.get_component(
					&entities_world,
					ent,
					^renderer.AmbientLight,
				)

				if err == ecs.ECS_Error.NO_ERROR {
					ambient_light = ambient_light_comp^

					transform, err := ecs.get_component(&entities_world, ent, engine.Transform)
					if err == ecs.ECS_Error.NO_ERROR {
						renderer.renderer_draw_light(
							ambient_light,
							transform,
							&camera_controller._position,
							&camera_controller.view_mat,
							&camera_controller.proj_mat,
						)
					}
					break
				}
			}
		}

		{ 	// Render selected entity
			if !ecs.has_component(
				&entities_world,
				scene_panel.selected_entity,
				^renderer.AmbientLight,
			) {
				model, _ := ecs.get_component(
					&entities_world,
					scene_panel.selected_entity,
					^renderer.Model,
				)
				transform, _ := ecs.get_component(
					&entities_world,
					scene_panel.selected_entity,
					engine.Transform,
				)

				animator_comp, err := ecs.get_component(
					&entities_world,
					scene_panel.selected_entity,
					^renderer.Animator,
				)

				animator: ^renderer.Animator = nil
				if err == ecs.ECS_Error.NO_ERROR {
					animator = animator_comp^
				}

				if model != nil && transform != nil {
					renderer.renderer_draw_model_outlined(
						model^,
						ambient_light,
						animator,
						transform,
						&camera_controller._position,
						&camera_controller.view_mat,
						&camera_controller.proj_mat,
					)
				}

			}
		}

		{ 	// Render models
			for ent in ecs.get_entities_with_components(
				&entities_world,
				{^renderer.Model, engine.Transform},
			) {
				model, _ := ecs.get_component(&entities_world, ent, ^renderer.Model)
				transform, _ := ecs.get_component(&entities_world, ent, engine.Transform)

				animator_comp, err := ecs.get_component(&entities_world, ent, ^renderer.Animator)

				animator: ^renderer.Animator = nil
				if err == ecs.ECS_Error.NO_ERROR {
					animator = animator_comp^
				}

				if scene_panel.selected_entity != ent && (model != nil && transform != nil) {
					renderer.renderer_draw_model(
						model^,
						ambient_light,
						animator,
						transform,
						&camera_controller._position,
						&camera_controller.view_mat,
						&camera_controller.proj_mat,
					)
				}
			}
		}
	}

	renderer.render_skybox(cubemap, &camera_controller.view_mat, &camera_controller.proj_mat)

	if scene_panel.should_draw_grid {
		renderer.renderer_draw_grid(&camera_controller.view_mat, &camera_controller.proj_mat)
	}

	renderer.framebuffer_unbind()
}

imgui_render :: proc() {
	window_flags: im.WindowFlags = {
		im.WindowFlag.NoTitleBar,
		im.WindowFlag.NoCollapse,
		im.WindowFlag.NoResize,
		im.WindowFlag.NoMove,
		im.WindowFlag.NoBringToFrontOnFocus,
		im.WindowFlag.NoNavFocus,
		im.WindowFlag.MenuBar,
	}

	{ 	// Docking stuff
		viewport := im.GetMainViewport()
		im.SetNextWindowPos(viewport.WorkPos)
		im.SetNextWindowSize(viewport.WorkSize)
		im.SetNextWindowViewport(viewport.ID_)

		im.PushStyleVar(im.StyleVar.WindowRounding, 0.0)
		im.PushStyleVar(im.StyleVar.WindowBorderSize, 0.0)

		dockspace_flags: im.DockNodeFlags = {im.DockNodeFlag.PassthruCentralNode}

		im.Begin("DockSpace Demo", nil, window_flags)
		im.PopStyleVar(2)

		dockspace_id := im.GetID("MyDockSpace")
		im.DockSpace(dockspace_id, im.Vec2{0, 0}, dockspace_flags)

		if im.BeginMenuBar() {
			if im.BeginMenu("Quit") {
				freya.SHOULD_RUN = false
				im.EndMenu()
			}

			if im.BeginMenu("File") {
				im.EndMenu()
			}

			if im.BeginMenu("View") {
				im.Checkbox("Draw Grid", &scene_panel.should_draw_grid)
				im.Checkbox("Gizmos", &guizmo_is_enabled)
				im.EndMenu()
			}
			im.EndMenuBar()
		}
		im.End()
	}


	im.PushStyleVarImVec2(im.StyleVar.WindowPadding, im.Vec2{0, 0})
	im.Begin("Viewport")
	is_viewport_overed = im.IsWindowHovered()
	content_region := im.GetContentRegionAvail()

	@(static) win_width: f32 = 0
	@(static) win_height: f32 = 0

	if win_width != content_region.x || win_height != content_region.y {
		win_width = content_region.x
		win_height = content_region.y

		on_event(engine.ImGuiViewportResizeEvent{win_width, win_height})
		renderer.framebuffer_rescale(viewport_fb, i32(win_width), i32(win_height))
	}

	im.Image(
		im.TextureID(uintptr(viewport_fb.texture.id)),
		im.Vec2{win_width, win_height},
		im.Vec2{0, 1},
		im.Vec2{1, 0},
	)

	if guizmo_is_enabled { 	// Gizmo
		transform, err := ecs.get_component(
			&entities_world,
			scene_panel.selected_entity,
			engine.Transform,
		)

		if err == ecs.ECS_Error.NO_ERROR {
			guizmo.set_orthographic(false)
			guizmo.set_draw_list()

			pos := im.GetWindowPos()

			guizmo.set_rect(pos.x, pos.y, win_width, win_height)

			changed := guizmo.manipulate(
				&camera_controller.camera.view_mat,
				&camera_controller.camera.proj_mat,
				&transform.model_matrix,
				currentGirmoOperation,
				currentGizmoMode,
			)

			if changed {
				guizmo.decompose_matrix_to_components(
					&transform.model_matrix,
					&transform.position,
					&transform.rotation,
					&transform.scale,
				)
			}

			if changed {
				light, err := ecs.get_component(
					scene_panel.entities_world,
					scene_panel.selected_entity,
					^renderer.AmbientLight,
				)
				if err == ecs.ECS_Error.NO_ERROR {
					light^.position = transform.position
				}
			}
		}
	}
	im.End()
	im.PopStyleVar()

	{ 	// Gui panels
		gui_panels.scene_panel_render(scene_panel, &camera_controller.camera)

		{ 	// Stats panel
			im.Begin("Stats", nil, {im.WindowFlag.NoTitleBar})
			{
				frame_time_ms := last_frame_time * 1000.0

				fps: f64 = 0.0
				if last_frame_time > 0 {
					fps = 1.0 / last_frame_time
				}

				im.Text("Frame Time: %.3f ms", frame_time_ms)
				im.Text("FPS: %.1f", fps)


				im.Separator()

				// --- Scene Stats ---
				im.Text("Scene:")
				entity_count := len(entities_world.entities.entities)
				im.Text("  Entity Count: %d", entity_count)

				im.Separator()

				// --- Viewport & Camera ---
				im.Text("Viewport & Camera:")
				im.Text("  Viewport Size: %.0f x %.0f", win_width, win_height)
				cam_pos := camera_controller._position
				im.Text("  Camera Pos: %.2f, %.2f, %.2f", cam_pos.x, cam_pos.y, cam_pos.z)

			}
			im.End()
		}
	}
}

on_event :: proc(ev: engine.Event) {
	#partial switch e in ev {
	case engine.KeyPressEvent:
		{
			if e.code == engine.KeyCode.P {
				engine.window_toggle_cursor(&engine.WINDOW, is_cursor_captured)
				is_cursor_captured = !is_cursor_captured
			}

			if e.code == engine.KeyCode.K {
				renderer.toggle_wire_mode(is_wire_mode)
				is_wire_mode = !is_wire_mode
			}

			if e.code == engine.KeyCode.Tab {
				if currentGirmoOperation == guizmo.Operation.TRANSLATE {
					currentGirmoOperation = guizmo.Operation.ROTATE
				} else if currentGirmoOperation == guizmo.Operation.ROTATE {
					currentGirmoOperation = guizmo.Operation.SCALE
				} else {
					currentGirmoOperation = guizmo.Operation.TRANSLATE
				}
			}
		}
	}
	engine.camera_on_event(&camera_controller, ev)
}
