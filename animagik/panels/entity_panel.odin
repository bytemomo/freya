package panel

import "core:crypto"
import "core:fmt"
import "core:log"
import "core:math"
import "core:os"
import "core:strings"

import engine "../../freya/engine"
import renderer "../../freya/renderer"

import ecs "../../freya/vendor/odin-ecs"

import im "../../freya/vendor/odin-imgui"
import guizmo "../../freya/vendor/odin-imguizmo"

import glm "core:math/linalg/glsl"


show_add_entity_panel: bool = false

ScenePanel :: struct {
	entities_world:      ^ecs.Context,
	selected_entity:     ecs.Entity,
	model_file_selector: ^FileSelector,
	should_draw_grid:    bool,
}

scene_panel_new :: proc(entities_world: ^ecs.Context) -> ^ScenePanel {
	panel := new(ScenePanel)
	panel.entities_world = entities_world
	panel.should_draw_grid = true
	panel.model_file_selector = file_selector_new()
	return panel
}

scene_panel_destroy :: proc(panel: ^ScenePanel) {
	file_selector_free(panel.model_file_selector)
	free(panel)
}

scene_panel_render :: proc(panel: ^ScenePanel, camera: ^engine.PerspectiveCamera) {
	im.Begin("Entities")

	if im.Button("Add entity") {
		show_add_entity_panel = true
	}

	if show_add_entity_panel {
		im.Begin("Add Entity")
		add_model_panel(panel)
		im.End()
	}

	selected: bool = false
	for ent, idx in panel.entities_world.entities.entities {
		if !ent.is_valid {
			continue
		}

		ent := ent.entity
		name, err := ecs.get_component(panel.entities_world, ent, engine.Name)
		if err == ecs.ECS_Error.ENTITY_DOES_NOT_HAVE_THIS_COMPONENT {
			continue
		}

		selected = panel.selected_entity == ent
		if im.Selectable(strings.unsafe_string_to_cstring(name^), selected) {
			panel.selected_entity = ent
		}
	}
	im.End()

	im.Begin("Selected entity")
	name, err := ecs.get_component(panel.entities_world, panel.selected_entity, engine.Name)
	if err != ecs.ECS_Error.ENTITY_DOES_NOT_HAVE_THIS_COMPONENT {
		// TODO: Change font size/style(bold)
		im.Text("Entity name: %s", strings.unsafe_string_to_cstring(name^))

		if im.Button("Delete entity") {
			ecs.destroy_entity(panel.entities_world, panel.selected_entity)
			im.End()
			return
		}

		{ 	// TRANSFORM COMPONENT
			im.SeparatorText("Transform")
			transform, err := ecs.get_component(
				panel.entities_world,
				panel.selected_entity,
				engine.Transform,
			)
			if err == ecs.ECS_Error.NO_ERROR {
				changed := transform_dialog(transform)

				if changed {
					light, err := ecs.get_component(
						panel.entities_world,
						panel.selected_entity,
						^renderer.AmbientLight,
					)
					if err == ecs.ECS_Error.NO_ERROR {
						light^.position = transform.position
					}
				}
			}
		}


		{ 	// BONE STRUCTURE
			im.SeparatorText("Animation data")
			animator, err := ecs.get_component(
				panel.entities_world,
				panel.selected_entity,
				^renderer.Animator,
			)

			if err == ecs.ECS_Error.NO_ERROR {
				im.Checkbox("Play animation", &(animator^).is_playing)
				root_node := (animator^).current_animation.root_node
				node_tree_dialog(&root_node)
			}
		}

		// TODO: Add buttons to add components
		// - Mesh
		// - Model
		// - Light
		// - Camera
		// - Animation
		// - Transform
	}
	im.End()


	when ODIN_DEBUG {
		{
			im.Begin("Material")

			model, err := ecs.get_component(
				panel.entities_world,
				panel.selected_entity,
				^renderer.Model,
			)
			if err == ecs.ECS_Error.NO_ERROR {
				for handle in model^.materials {
					material, err := renderer.resource_manager_get_material(handle)

					im.Text("Material Name : %s", strings.unsafe_string_to_cstring(material.name))
					im.Separator()

					diffuse, differr := renderer.resource_manager_get_texture(
						material.diffuse_texture,
					)
					if differr == renderer.ResourceManagerError.NoError {
						im.Text("Diffuse texture")
						im.Image(
							im.TextureID(uintptr(diffuse.id)),
							{100, 100},
							{0, 1},
							{1, 0},
							{1, 1, 1, 1},
							{0, 0, 0, 0},
						)
					}

					specular, specerr := renderer.resource_manager_get_texture(
						material.specular_texture,
					)
					if specerr == renderer.ResourceManagerError.NoError {
						im.Text("Specular texture")
						im.Image(
							im.TextureID(uintptr(specular.id)),
							{100, 100},
							{0, 1},
							{1, 0},
							{1, 1, 1, 1},
							{0, 0, 0, 0},
						)
					}

					normal, normalerr := renderer.resource_manager_get_texture(
						material.normal_texture,
					)
					if normalerr == renderer.ResourceManagerError.NoError {
						im.Text("Normal texture")
						im.Image(
							im.TextureID(uintptr(normal.id)),
							{100, 100},
							{0, 1},
							{1, 0},
							{1, 1, 1, 1},
							{0, 0, 0, 0},
						)
					}

					height, heighterr := renderer.resource_manager_get_texture(
						material.height_texture,
					)
					if heighterr == renderer.ResourceManagerError.NoError {
						im.Text("Height texture")
						im.Image(
							im.TextureID(uintptr(height.id)),
							{100, 100},
							{0, 1},
							{1, 0},
							{1, 1, 1, 1},
							{0, 0, 0, 0},
						)
					}
					im.Text("Material - shininess : %f", material.shininess)
					im.Separator()
				}
			}
			im.End()
		}
	}
}

@(private = "file")
name_buffer: []byte = make([]byte, 30)

@(private)
add_model_panel :: proc(panel: ^ScenePanel) {
	im.InputText("Entity Name", cstring(&name_buffer[0]), 30)
	object_path := file_selector_panel(panel.model_file_selector)

	@(static) add_with_animation: bool = false
	im.Checkbox("Add with animation", &add_with_animation)


	if object_path != "" {
		model_component: ^renderer.Model = nil
		animation_component: ^renderer.Animation = nil
		if add_with_animation {
			model_component, animation_component = renderer.model_new_with_anim(object_path)
			if model_component == nil {
				file_selector_reset(panel.model_file_selector)
				return
			}
		} else {
			model_component = renderer.model_new(object_path)
			if model_component == nil {
				file_selector_reset(panel.model_file_selector)
				return
			}
		}

		ent := ecs.create_entity(panel.entities_world)
		ecs.add_component(panel.entities_world, ent, model_component)

		if animation_component != nil {
			animator := renderer.animator_new(animation_component)
			ecs.add_component(panel.entities_world, ent, animator)
		}

		ecs.add_component(
			panel.entities_world,
			ent,
			engine.Transform {
				glm.vec3{0.0, 0.0, 0.0},
				glm.vec3{0.0, 0.0, 0.0},
				glm.vec3{1.0, 1.0, 1.0},
				glm.mat4Translate({0.0, 0.0, 0.0}),
			},
		)

		null_pos := 0
		for null_pos < 20 && name_buffer[null_pos] != 0 {
			null_pos += 1
		}

		name := string(name_buffer[:null_pos])
		if name == "" {
			name_buffer: [5]u8
			crypto.rand_bytes(name_buffer[:])

			name = fmt.tprintf(
				"%02x%02x%02x%02x%02x",
				name_buffer[0],
				name_buffer[1],
				name_buffer[2],
				name_buffer[3],
				name_buffer[4],
			)
			ecs.add_component(panel.entities_world, ent, engine.Name(name))

		} else {
			ecs.add_component(panel.entities_world, ent, engine.Name(strings.clone(name)))
		}
		file_selector_reset(panel.model_file_selector)
		show_add_entity_panel = false
	}
}

@(private)
node_tree_dialog :: proc(node: ^renderer.AssimpNodeData) {
	if im.TreeNode(strings.unsafe_string_to_cstring(node.name)) {
		im.Text("Children Count: %d", node.children_count)

		for &child in node.children {
			node_tree_dialog(&child)
		}

		im.TreePop()
	}
}


@(private)
drag_float3 :: proc(label: string, value: ^glm.vec3, speed, min, max: f32) -> bool {
	changed := false
	im.AlignTextToFramePadding()
	{
		im.PushStyleColor(im.Col.Text, 0xFF000000)
		im.PushStyleColor(im.Col.Button, 0xFF6BB3FC) // Blue
		im.Button("X")
		im.PopStyleColor(2)
	}
	im.SameLine()
	im.PushItemWidth(80)
	tmplabel := strings.concatenate({"##x", label}, allocator = context.temp_allocator)
	changed |= im.DragFloat(
		strings.unsafe_string_to_cstring(tmplabel),
		&value[0],
		speed,
		min,
		max,
		nil,
	)
	im.PopItemWidth()

	im.SameLine()
	{
		im.PushStyleColor(im.Col.Text, 0xFF000000)
		im.PushStyleColor(im.Col.Button, 0xFF6BFCC0) // Green
		im.Button("Y")
		im.PopStyleColor(2)
	}
	im.SameLine()
	im.PushItemWidth(80)
	tmplabel = strings.concatenate({"##y", label}, allocator = context.temp_allocator)
	changed |= im.DragFloat(
		strings.unsafe_string_to_cstring(tmplabel),
		&value[1],
		speed,
		min,
		max,
		nil,
	)
	im.PopItemWidth()

	im.SameLine()
	{
		im.PushStyleColor(im.Col.Text, 0xFF000000)
		im.PushStyleColor(im.Col.Button, 0xFFFC6B6B) // Red
		im.Button("Z")
		im.PopStyleColor(2)
	}
	im.SameLine()
	im.PushItemWidth(80)
	tmplabel = strings.concatenate({"##z", label}, allocator = context.temp_allocator)
	changed |= im.DragFloat(
		strings.unsafe_string_to_cstring(tmplabel),
		&value[2],
		speed,
		min,
		max,
		nil,
	)
	im.PopItemWidth()
	return changed
}

@(private)
transform_dialog :: proc(transform: ^engine.Transform) -> bool {
	im.Text("Pos:")
	im.SameLine()
	changed := false
	changed |= drag_float3("Pos", &transform.position, 0.1, -math.F32_MAX, math.F32_MAX)

	im.Text("Rot:")
	im.SameLine()
	changed |= drag_float3("Rot", &transform.rotation, 0.1, -math.PI, math.PI)

	im.Text("Scl:")
	im.SameLine()
	changed |= drag_float3("Scale", &transform.scale, 0.01, 0, 10)

	if changed {
		transform.model_matrix =
			glm.mat4Translate(transform.position) *
			glm.mat4Rotate({1, 0, 0}, transform.rotation.x) *
			glm.mat4Rotate({0, 1, 0}, transform.rotation.y) *
			glm.mat4Rotate({0, 0, 1}, transform.rotation.z) *
			glm.mat4Scale(transform.scale)
	}

	return changed
}
