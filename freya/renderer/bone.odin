package renderer

import "core:strings"

import glm "core:math/linalg/glsl"

import assimp "../vendor/odin-assimp"

BoneInfo :: struct {
	id:     i32,
	offset: glm.mat4,
}

KeyPosition :: struct {
	time:     f64,
	position: glm.vec3,
}

KeyRotation :: struct {
	time:        f64,
	orientation: glm.quat,
}

KeyScale :: struct {
	time:  f64,
	scale: glm.vec3,
}


Bone :: struct {
	id:            i32,
	name:          string,
	offset:        glm.mat4,
	num_positions: u32,
	num_rotations: u32,
	num_scalings:  u32,
	keys_pos:      [dynamic]KeyPosition,
	keys_rot:      [dynamic]KeyRotation,
	keys_scl:      [dynamic]KeyScale,
}

bone_new :: proc(name: string, id: i32, chan: ^assimp.NodeAnim) -> ^Bone {
	bone := new(Bone)
	bone.id = id
	bone.name = strings.clone(name)
	bone.offset = glm.mat4(1.0)
	bone.num_positions = 0
	bone.num_rotations = 0
	bone.num_scalings = 0
	bone.keys_pos = make([dynamic]KeyPosition)
	bone.keys_rot = make([dynamic]KeyRotation)
	bone.keys_scl = make([dynamic]KeyScale)


	bone.num_positions = chan.mNumPositionKeys
	for i in 0 ..< bone.num_positions {
		pos := chan.mPositionKeys[i].mValue
		time := chan.mPositionKeys[i].mTime
		append(&bone.keys_pos, KeyPosition{time = time, position = transmute(glm.vec3)pos})
	}

	bone.num_rotations = chan.mNumRotationKeys
	for i in 0 ..< bone.num_rotations {
		rot := chan.mRotationKeys[i].mValue
		time := chan.mRotationKeys[i].mTime
		append(
			&bone.keys_rot,
			KeyRotation{time = time, orientation = assimp.quaterion_convert(rot)},
		)
	}

	bone.num_scalings = chan.mNumScalingKeys
	for i in 0 ..< bone.num_scalings {
		scl := chan.mScalingKeys[i].mValue
		time := chan.mScalingKeys[i].mTime
		append(&bone.keys_scl, KeyScale{time = time, scale = transmute(glm.vec3)scl})
	}

	return bone
}

bone_free :: proc(self: ^Bone) {
	delete_string(self.name)
	delete(self.keys_pos)
	delete(self.keys_rot)
	delete(self.keys_scl)

	free(self)
}

bone_update :: proc(self: ^Bone, animTime: f64) {
	translation := interpolate_positions(self, animTime)
	rotation := interpolate_rotation(self, animTime)
	scaling := interpolate_scaling(self, animTime)

	self.offset = translation * rotation * scaling
}

get_position_index :: proc(self: ^Bone, anim_time: f64) -> u32 {
	for i in 0 ..< (self.num_positions - 1) {
		if anim_time < self.keys_pos[i + 1].time {
			return i
		}
	}
	assert(false)
	return 0
}

get_rotation_index :: proc(self: ^Bone, anim_time: f64) -> u32 {
	for i in 0 ..< (self.num_rotations - 1) {
		if anim_time < self.keys_rot[i + 1].time {
			return i
		}
	}
	assert(false)
	return 0
}

get_scaling_index :: proc(self: ^Bone, anim_time: f64) -> u32 {
	for i in 0 ..< (self.num_scalings - 1) {
		if anim_time < self.keys_scl[i + 1].time {
			return i
		}
	}
	assert(false)
	return 0
}

@(private)
get_scale_factor :: proc(last_time_stamp: f64, next_time_stamp: f64, anim_time: f64) -> f64 {
	scale_factor: f64 = 0
	midway_length := anim_time - last_time_stamp
	frames_diff := next_time_stamp - last_time_stamp
	scale_factor = midway_length / frames_diff
	return scale_factor
}

@(private)
interpolate_positions :: proc(self: ^Bone, anim_time: f64) -> glm.mat4 {
	if self.num_positions == 1 {
		return glm.mat4Translate(self.keys_pos[0].position)
	}

	p0_idx := get_position_index(self, anim_time)
	p1_idx := p0_idx + 1
	assert(p1_idx < self.num_positions)

	scale_factor := get_scale_factor(
		self.keys_pos[p0_idx].time,
		self.keys_pos[p1_idx].time,
		anim_time,
	)

	final_pos := glm.mix(
		self.keys_pos[p0_idx].position,
		self.keys_pos[p1_idx].position,
		f32(scale_factor),
	)
	return glm.mat4Translate(final_pos)
}

@(private)
interpolate_rotation :: proc(self: ^Bone, anim_time: f64) -> glm.mat4 {
	if self.num_rotations == 1 {
		rot := glm.normalize(self.keys_rot[0].orientation)
		return glm.mat4FromQuat(rot)
	}

	r0_idx := get_rotation_index(self, anim_time)
	r1_idx := r0_idx + 1
	assert(r1_idx < self.num_rotations)

	scale_factor := get_scale_factor(
		self.keys_rot[r0_idx].time,
		self.keys_rot[r1_idx].time,
		anim_time,
	)

	final_rot := glm.slerp(
		self.keys_rot[r0_idx].orientation,
		self.keys_rot[r1_idx].orientation,
		f32(scale_factor),
	)

	return glm.mat4FromQuat(glm.normalize(final_rot))
}

@(private)
interpolate_scaling :: proc(self: ^Bone, anim_time: f64) -> glm.mat4 {
	if self.num_scalings == 1 {
		return glm.mat4Scale(self.keys_scl[0].scale)
	}

	s0_idx := get_scaling_index(self, anim_time)
	s1_idx := s0_idx + 1
	assert(s1_idx < self.num_scalings)

	scale_factor := get_scale_factor(
		self.keys_scl[s0_idx].time,
		self.keys_scl[s1_idx].time,
		anim_time,
	)


	final_scl := glm.mix(
		self.keys_scl[s0_idx].scale,
		self.keys_scl[s1_idx].scale,
		f32(scale_factor),
	)

	return glm.mat4Scale(final_scl)
}
