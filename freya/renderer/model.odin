package renderer

import "core:crypto"
import "core:fmt"
import "core:log"
import glm "core:math/linalg/glsl"
import "core:mem"
import "core:path/filepath"
import "core:strings"

import assimp "../vendor/odin-assimp"

Model :: struct {
	meshes:        [dynamic]^Mesh,
	materials:     [dynamic]MaterialHandle,
	bone_info_map: map[string]BoneInfo,
	bone_count:    u32,
}

AssimpNodeData :: struct {
	name:           string,
	children_count: u32,
	transformation: glm.mat4,
	children:       [dynamic]AssimpNodeData,
}

Animation :: struct {
	duration:                 f64,
	tick_per_second:          f64,
	root_node:                AssimpNodeData,
	bones:                    [dynamic]^Bone,
	bone_info_map:            map[string]BoneInfo,
	global_inverse_transform: glm.mat4,
}

model_new :: proc {
	model_new_from_filepath,
	model_new_explicit,
}

model_new_explicit :: proc(
	meshes: [dynamic]^Mesh,
	materials: [dynamic]MaterialHandle,
	bone_info_map: map[string]BoneInfo,
	bone_count: u32,
) -> ^Model {
	model := new(Model)
	model.meshes = meshes
	model.materials = materials
	model.bone_info_map = bone_info_map
	model.bone_count = bone_count
	return model
}

model_new_from_filepath :: proc(file_path: string) -> ^Model {
	log.infof("Loading model: {}", file_path)

	import_flags := get_import_flags_by_extension(file_path)
	scene := assimp.import_file(file_path, u32(import_flags))

	defer {
		// assimp.release_import(scene)
		assimp.free_scene(scene)
		log.info("Model loaded, unload model's scene completed!")
	}

	if scene == nil ||
	   scene.mFlags & u32(assimp.SceneFlags.INCOMPLETE) != 0 ||
	   scene.mRootNode == nil {
		log.error("Failed to load model: ", file_path)
		return nil
	}

	if scene.mFlags & u32(assimp.SceneFlags.VALIDATED) != 0 {
		log.warn("Model is not validated")
	}

	if scene.mFlags & u32(assimp.SceneFlags.VALIDATION_WARNING) != 0 {
		log.warn("Model has validation warnings")
	}

	if scene.mFlags & u32(assimp.SceneFlags.NON_VERBOSE_FORMAT) != 0 {
		log.warn("Model is in a non-verbose format")
	}

	if scene.mFlags & u32(assimp.SceneFlags.FLAGS_TERRAIN) != 0 {
		log.warn("Model is a terrain")
	}

	base_path := filepath.dir(file_path)

	model := new(Model)
	extract_materials(model, scene, base_path)
	process_root_node(scene.mRootNode, scene, model)

	return model
}

process_root_node :: proc(root: ^assimp.Node, scene: ^assimp.Scene, model: ^Model) {
	stack: [dynamic]^assimp.Node = make([dynamic]^assimp.Node)
	defer delete(stack)
	append(&stack, root)

	for len(stack) > 0 {
		node := stack[len(stack) - 1]
		pop(&stack)

		for i in 0 ..< node.mNumMeshes {
			mesh_idx := node.mMeshes[i]
			mesh := scene.mMeshes[mesh_idx]
			extract_mesh(model, scene, mesh)
		}

		for i in 0 ..< node.mNumChildren {
			append(&stack, node.mChildren[i])
		}
	}
}

extract_mesh :: proc(model: ^Model, scene: ^assimp.Scene, mesh: ^assimp.Mesh) {
	vertices: []Vertex = make([]Vertex, mesh.mNumVertices)
	defer delete(vertices)
	for i in 0 ..< mesh.mNumVertices {

		for j in 0 ..< MAX_BONE_INFLUENCES {
			vertices[i].bones_ids[j] = -1
			vertices[i].weights[j] = 0.0
		}

		vertices[i].position = mesh.mVertices[i].xyz

		if mesh.mColors[0] != nil {
			vertices[i].color = mesh.mColors[0][i].rgb
		}

		if mesh.mNormals != nil {
			vertices[i].normal = mesh.mNormals[i].xyz
		}

		if mesh.mTextureCoords[0] != nil {
			vertices[i].tex_coords = mesh.mTextureCoords[0][i].xy
		} else {
			vertices[i].tex_coords = {0.0, 0.0}
		}

		if mesh.mTangents != nil {
			vertices[i].tangent = mesh.mTangents[i].xyz
		}

		if mesh.mBitangents != nil {
			vertices[i].bitanget = mesh.mBitangents[i].xyz
		}
	}

	// Get indices
	index_count: u32 = 0
	for i in 0 ..< mesh.mNumFaces {
		index_count += mesh.mFaces[i].mNumIndices
	}
	indices: []u32 = make([]u32, index_count)
	defer delete(indices)

	idx: u32 = 0
	for i in 0 ..< mesh.mNumFaces {
		face := mesh.mFaces[i]
		for j in 0 ..< face.mNumIndices {
			indices[idx] = face.mIndices[j]
			idx += 1
		}
	}

	extract_bones(model, mesh, scene, vertices)

	mat_name: assimp.String
	if assimp.get_material_string(
		   scene.mMaterials[mesh.mMaterialIndex],
		   "?mat.name",
		   0,
		   0,
		   &mat_name,
	   ) !=
	   assimp.Return.SUCCESS {
		log.error("Failed to get material name")
	}

	name := string(mat_name.data[:mat_name.length])
	append(&model.meshes, mesh_new(vertices, indices, MaterialHandle(strings.clone(name))))
}

extract_bones :: proc(
	model: ^Model,
	mesh: ^assimp.Mesh,
	scene: ^assimp.Scene,
	vertices: []Vertex,
) {
	if mesh.mNumBones == 0 {
		return
	}

	log.debugf("Extracting bones for mesh: {}", mesh.mName.data[:mesh.mName.length])

	for bone_idx in 0 ..< mesh.mNumBones {
		bone_id: i32 = -1
		bone_name := assimp.string_clone_from_ai_string(&mesh.mBones[bone_idx].mName)
		if _, ok := model.bone_info_map[bone_name]; !ok {
			model.bone_info_map[bone_name] = BoneInfo {
				id     = i32(model.bone_count),
				offset = assimp.matrix_convert(mesh.mBones[bone_idx].mOffsetMatrix),
			}
			bone_id = i32(model.bone_count)
			model.bone_count += 1
		} else {
			bone_id = model.bone_info_map[bone_name].id
		}
		assert(bone_id != -1)

		num_weights := mesh.mBones[bone_idx].mNumWeights
		weights := mesh.mBones[bone_idx].mWeights

		if weights == nil {
			log.warnf("No weights for bone: {}", bone_name)
			continue
		}

		for weight_idx in 0 ..< num_weights {
			vertex_id := weights[weight_idx].mVertexId
			weight := weights[weight_idx].mWeight
			assert(vertex_id < u32(len(vertices)))

			for k in 0 ..< MAX_BONE_INFLUENCES {
				if vertices[vertex_id].bones_ids[k] < 0 {
					vertices[vertex_id].bones_ids[k] = bone_id
					vertices[vertex_id].weights[k] = weight
					break
				}
			}
		}

	}
}

extract_materials :: proc(model: ^Model, scene: ^assimp.Scene, base_path: string) {
	for i in 0 ..< scene.mNumMaterials {
		mat: ^assimp.Material = scene.mMaterials[i]

		mat_name: assimp.String
		if assimp.get_material_string(mat, "?mat.name", 0, 0, &mat_name) != assimp.Return.SUCCESS {
			log.error("Failed to get material name")
			continue
		}

		max: u32
		shininess: f64
		if assimp.get_material_floatArray(mat, "$mat.shininess", 0, 0, &shininess, &max) !=
		   assimp.Return.SUCCESS {
			log.error("Failed to get material name")
			continue
		}

		if max > 1 {
			log.error("More than one shininess value")
			continue
		}

		diffuse, specular, height, ambient, normal: TextureHandle = "", "", "", "", ""
		// Get textures, NOTE: more than one texture per type is not supported
		if assimp.get_material_textureCount(mat, assimp.TextureType.DIFFUSE) > 0 {
			relative_path: assimp.String
			mapping: assimp.TextureMapping
			uvindex: u32
			blend: f64
			op: assimp.TextureOp
			mapmode: assimp.TextureMapMode
			if assimp.get_material_texture(
				   mat,
				   assimp.TextureType.DIFFUSE,
				   0,
				   &relative_path,
				   &mapping,
				   &uvindex,
				   &blend,
				   &op,
				   &mapmode,
			   ) !=
			   assimp.Return.SUCCESS {
				log.error("Failed to get material texture")
				continue
			}

			texture_path := filepath.join(
				{base_path, assimp.string_clone_from_ai_string(&relative_path)},
			)

			diffuse = resource_manager_add(texture_path, TextureType.Diffuse)
		}
		if assimp.get_material_textureCount(mat, assimp.TextureType.SPECULAR) > 0 {
			relative_path: assimp.String
			mapping: assimp.TextureMapping
			uvindex: u32
			blend: f64
			op: assimp.TextureOp
			mapmode: assimp.TextureMapMode
			if assimp.get_material_texture(
				   mat,
				   assimp.TextureType.SPECULAR,
				   0,
				   &relative_path,
				   &mapping,
				   &uvindex,
				   &blend,
				   &op,
				   &mapmode,
			   ) !=
			   assimp.Return.SUCCESS {
				log.error("Failed to get material texture")
				continue
			}

			texture_path := filepath.join(
				{base_path, assimp.string_clone_from_ai_string(&relative_path)},
			)

			specular = resource_manager_add(texture_path, TextureType.Specular)
		}
		if assimp.get_material_textureCount(mat, assimp.TextureType.HEIGHT) > 0 {
			relative_path: assimp.String
			mapping: assimp.TextureMapping
			uvindex: u32
			blend: f64
			op: assimp.TextureOp
			mapmode: assimp.TextureMapMode
			if assimp.get_material_texture(
				   mat,
				   assimp.TextureType.HEIGHT,
				   0,
				   &relative_path,
				   &mapping,
				   &uvindex,
				   &blend,
				   &op,
				   &mapmode,
			   ) !=
			   assimp.Return.SUCCESS {
				log.error("Failed to get material texture")
				continue
			}

			texture_path := filepath.join(
				{base_path, assimp.string_clone_from_ai_string(&relative_path)},
			)

			height = resource_manager_add(texture_path, TextureType.Height)
		}
		if assimp.get_material_textureCount(mat, assimp.TextureType.NORMALS) > 0 {
			relative_path: assimp.String
			mapping: assimp.TextureMapping
			uvindex: u32
			blend: f64
			op: assimp.TextureOp
			mapmode: assimp.TextureMapMode
			if assimp.get_material_texture(
				   mat,
				   assimp.TextureType.NORMALS,
				   0,
				   &relative_path,
				   &mapping,
				   &uvindex,
				   &blend,
				   &op,
				   &mapmode,
			   ) !=
			   assimp.Return.SUCCESS {
				log.error("Failed to get material texture")
				continue
			}
			texture_path := filepath.join(
				{base_path, assimp.string_clone_from_ai_string(&relative_path)},
			)

			normal = resource_manager_add(texture_path, TextureType.Normals)
		}
		// if assimp.get_material_textureCount(mat, assimp.TextureType.AMBIENT) > 0 {
		// 	relative_path: assimp.String
		// 	mapping: assimp.TextureMapping
		// 	uvindex: u32
		// 	blend: f64
		// 	op: assimp.TextureOp
		// 	mapmode: assimp.TextureMapMode
		// 	if assimp.get_material_texture(
		// 		   mat,
		// 		   assimp.TextureType.AMBIENT,
		// 		   0,
		// 		   &relative_path,
		// 		   &mapping,
		// 		   &uvindex,
		// 		   &blend,
		// 		   &op,
		// 		   &mapmode,
		// 	   ) !=
		// 	   assimp.Return.SUCCESS {
		// 		log.error("Failed to get material texture")
		// 		continue
		// 	}
		//
		// 	texture_path := filepath.join(
		// 		{base_path, assimp.string_clone_from_ai_string(&relative_path)},
		// 	)
		//
		// 	ambient = resource_manager_add(texture_path, TextureType.Ambient)
		// }

		// if shininess == 0.0 && diffuse == "" && specular == "" && height == "" && ambient == "" {
		// continue
		// }

		append(
			&model.materials,
			resource_manager_add(
				assimp.string_clone_from_ai_string(&mat_name),
				diffuse,
				specular,
				height,
				normal,
				shininess,
			),
		)
	}
}

@(export)
model_free :: proc(model: ^Model) {
	for &mesh in model.meshes {
		mesh_free(mesh)
	}

	for &material in model.materials {
		resource_manager_delete(material)
	}

	delete_map(model.bone_info_map)
	delete(model.meshes)
	delete(model.materials)
	free(model)
}

@(export)
model_draw :: proc(model: ^Model, shader: ShaderProgram) {
	for &mesh in model.meshes {
		mesh_draw_with_material(mesh, shader)
	}
}


@(private)
get_import_flags_by_extension :: proc(file_path: string) -> assimp.PostProcessSteps {
	flags: assimp.PostProcessSteps =
		assimp.PostProcessSteps.Triangulate |
		assimp.PostProcessSteps.GenSmoothNormals |
		assimp.PostProcessSteps.CalcTangentSpace |
		assimp.PostProcessSteps.ValidateDataStructure |
		assimp.PostProcessSteps.LimitBoneWeights |
		assimp.PostProcessSteps.SplitLargeMeshes |
		assimp.PostProcessSteps.RemoveRedundantMaterials |
		assimp.PostProcessSteps.FindInvalidData |
		assimp.PostProcessSteps.GenUVCoords |
		assimp.PostProcessSteps.TransformUVCoords |
		assimp.PostProcessSteps.FindDegenerates |
		assimp.PostProcessSteps.JoinIdenticalVertices |
		assimp.PostProcessSteps.ImproveCacheLocality |
		assimp.PostProcessSteps.OptimizeGraph

	ext := filepath.ext(file_path)
	switch ext {
	case ".obj":
	// flags |= assimp.PostProcessSteps.FlipUVs
	case ".blend", ".dae", ".3ds", ".ase", ".ifc", ".xgl", ".zgl":
	// flags |= assimp.PostProcessSteps.FlipUVs
	case ".fbx":
	// flags |= assimp.PostProcessSteps.MakeLeftHanded
	case ".gltf":
	// flags |= assimp.PostProcessSteps.FlipWindingOrder
	}

	return flags
}

// Animation ===================================================================

model_new_with_anim :: proc(file_path: string) -> (^Model, ^Animation) {
	log.infof("Loading model: {}", file_path)

	import_flags := get_import_flags_by_extension(file_path)
	scene := assimp.import_file(file_path, u32(import_flags))

	defer {
		// assimp.release_import(scene)
		assimp.free_scene(scene)
		log.info("Model loaded, unload model's scene completed!")
	}

	if scene == nil ||
	   scene.mFlags & u32(assimp.SceneFlags.INCOMPLETE) != 0 ||
	   scene.mRootNode == nil {
		log.error("Failed to load model: ", file_path)
		return nil, nil
	}

	if scene.mFlags & u32(assimp.SceneFlags.VALIDATED) != 0 {
		log.warn("Model is not validated")
	}

	if scene.mFlags & u32(assimp.SceneFlags.VALIDATION_WARNING) != 0 {
		log.warn("Model has validation warnings")
	}

	if scene.mFlags & u32(assimp.SceneFlags.NON_VERBOSE_FORMAT) != 0 {
		log.warn("Model is in a non-verbose format")
	}

	if scene.mFlags & u32(assimp.SceneFlags.FLAGS_TERRAIN) != 0 {
		log.warn("Model is a terrain")
	}

	base_path := filepath.dir(file_path)

	if scene.mAnimations == nil {
		log.warn("Model do not have animation, cannot import!")
		return nil, nil
	}

	model := new(Model)
	extract_materials(model, scene, base_path)
	process_root_node(scene.mRootNode, scene, model)

	animation := new(Animation)
	animation.duration = scene.mAnimations[0].mDuration
	animation.tick_per_second = scene.mAnimations[0].mTicksPerSecond
	animation.root_node = AssimpNodeData {
		children = make([dynamic]AssimpNodeData),
	}
	animation.bones = make([dynamic]^Bone)

	animation.global_inverse_transform = glm.inverse_mat4(
		assimp.matrix_convert(scene.mRootNode.mTransformation),
	)


	read_hierarchy_data(scene.mRootNode, &animation.root_node)
	read_missing_bones(animation, scene.mAnimations[0], model)

	return model, animation
}

@(private)
read_missing_bones :: proc(self: ^Animation, animation: ^assimp.Animation, model: ^Model) {
	size := animation.mNumChannels

	for i in 0 ..< size {
		channel := animation.mChannels[i]
		bone_name := assimp.string_clone_from_ai_string(&channel.mNodeName)

		if _, ok := model.bone_info_map[bone_name]; !ok {
			model.bone_info_map[bone_name] = BoneInfo {
				id     = i32(model.bone_count),
				offset = glm.mat4(1.0),
			}
			model.bone_count += 1
		}

		append(&self.bones, bone_new(bone_name, model.bone_info_map[bone_name].id, channel))
	}

	self.bone_info_map = model.bone_info_map
}

@(private)
read_hierarchy_data :: proc(src: ^assimp.Node, dst: ^AssimpNodeData) {
	assert(src != nil)
	assert(string(src.mName.data[:src.mName.length]) != "")

	dst.name = assimp.string_clone_from_ai_string(&src.mName)
	dst.transformation = assimp.matrix_convert(src.mTransformation)
	dst.children_count = src.mNumChildren

	for i in 0 ..< src.mNumChildren {
		child := AssimpNodeData {
			children = make([dynamic]AssimpNodeData),
		}
		read_hierarchy_data(src.mChildren[i], &child)
		append(&dst.children, child)
	}
}

anim_find_bone :: proc(self: ^Animation, name: string) -> ^Bone {
	for &bone in self.bones {
		if bone.name == name {
			return bone
		}
	}
	return nil
}

animation_free :: proc(self: ^Animation) {
	for &bone in self.bones {
		bone_free(bone)
	}

	for &data in self.root_node.children {
		delete(data.name)
	}

	stack: [dynamic]AssimpNodeData = make([dynamic]AssimpNodeData, 0)
	defer delete(stack)

	append(&stack, self.root_node)

	for len(stack) > 0 {
		node := pop(&stack)

		for &child in node.children {
			append(&stack, child)
		}

		delete(node.children)
	}

	// delete_map(animation.bone_info_map) // NOTE: It will be deleted by the model
	delete(self.bones)
	free(self)
}
