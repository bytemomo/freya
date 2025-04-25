package renderer

import "core:log"
import glm "core:math/linalg/glsl"

fmod :: proc(x, y: f64) -> f64 {
	if y == 0.0 {
		return 0.0
	}
	quotient := int(x / y)
	return x - (y * f64(quotient))
}

Animator :: struct {
	current_time:        f64,
	delta_time:          f64,
	final_bone_matrices: [dynamic]glm.mat4,
	current_animation:   ^Animation,
	is_playing:          bool,
}

animator_new :: proc(animation: ^Animation) -> ^Animator {
	animator := new(Animator)
	animator.is_playing = false
	animator.delta_time = 0.0
	animator.current_time = 0.0
	animator.current_animation = animation
	animator.final_bone_matrices = make([dynamic]glm.mat4, len(animation.bone_info_map))
	log.infof("Animator created with %d bones", len(animation.bone_info_map))

	calculate_bone_transform(animator, &animation.root_node, glm.mat4(1.0))
	return animator
}

animator_free :: proc(self: ^Animator) {
	delete(self.final_bone_matrices)
	animation_free(self.current_animation)
	free(self)
}

animator_update_animation :: proc(self: ^Animator, delta_time: f64) {
	self.delta_time = delta_time
	if self.current_animation != nil && self.is_playing {
		self.current_time += self.current_animation.tick_per_second * delta_time
		self.current_time = fmod(self.current_time, self.current_animation.duration)
		calculate_bone_transform(self, &self.current_animation.root_node, glm.mat4(1.0))
	}
}

animation_play_animation :: proc(self: ^Animator, animation: ^Animation) {
	if self.current_animation != nil {
		if self.current_animation == animation {
			return
		}
		animation_free(self.current_animation)
	}

	self.current_animation = animation
	self.current_time = 0.0
}

calculate_bone_transform :: proc(
	self: ^Animator,
	node: ^AssimpNodeData,
	parent_transform: glm.mat4,
) {
	node_transformation := node.transformation
	bone := anim_find_bone(self.current_animation, node.name)
	if bone != nil {
		bone_update(bone, self.current_time)
		node_transformation = bone.offset
	}

	global_transform := parent_transform * node_transformation
	if _, ok := self.current_animation.bone_info_map[node.name]; ok {
		index := self.current_animation.bone_info_map[node.name].id
		offset := self.current_animation.bone_info_map[node.name].offset
		self.final_bone_matrices[index] = global_transform * offset
	}

	for i in 0 ..< node.children_count {
		calculate_bone_transform(self, &node.children[i], global_transform)
	}
}
