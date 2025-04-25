package renderer

import "core:crypto/hash"
import "core:log"

import "core:encoding/hex"


// @(private) // TODO: Make this private
RESOURCE_MANAGER: ^ResourceManager = nil

Handle :: #type string
TextureHandle :: distinct Handle
MaterialHandle :: distinct Handle

ResourceManager :: struct {
	textures:  map[TextureHandle]^Texture,
	materials: map[MaterialHandle]^Material,
}

ResourceManagerError :: enum {
	NoError,
	TextureNotFound,
	MaterialNotFound,
}

resource_manager_get :: proc {
	resource_manager_get_texture,
	resource_manager_get_material,
}

resource_manager_add :: proc {
	resource_manager_add_texture,
	resource_manager_add_material,
}

resource_manager_delete :: proc {
	resource_manager_delete_texture,
	resource_manager_delete_material,
}

// Its fine to use SHA1 here since we are not using it for security purposes
HASH_ALGORITHM :: hash.Algorithm.Insecure_SHA1

// Material

resource_manager_get_material :: proc(
	handle: MaterialHandle,
) -> (
	^Material,
	ResourceManagerError,
) {
	material, ok := RESOURCE_MANAGER.materials[handle]
	if !ok {
		return nil, ResourceManagerError.MaterialNotFound // NOTE: Return a default material ?
	}
	return material, ResourceManagerError.NoError
}

resource_manager_add_material :: proc(
	name: string,
	diffuse, specular, height, normal: TextureHandle,
	shininess: f64,
) -> MaterialHandle {
	// digest := hash.hash(hash.Algorithm.Insecure_SHA1, name)
	// defer delete(digest)

	handle := MaterialHandle(name)
	if _, ok := RESOURCE_MANAGER.materials[handle]; ok {
		// log.debugf("Material already loaded: {}", handle)
		return handle
	}

	RESOURCE_MANAGER.materials[handle] = material_new(
		name,
		diffuse,
		specular,
		height,
		normal,
		shininess,
	)

	return handle
}

resource_manager_delete_material :: proc(handle: MaterialHandle) {
	material, ok := RESOURCE_MANAGER.materials[handle]
	if !ok {
		log.warnf("Material already deleted: {}", handle)
		return
	}

	material_free(material)
	delete_key(&RESOURCE_MANAGER.materials, handle)
}

// Texture

@(export)
resource_manager_get_texture :: proc(handle: TextureHandle) -> (^Texture, ResourceManagerError) {
	texture, ok := RESOURCE_MANAGER.textures[handle]
	if !ok {
		return nil, ResourceManagerError.TextureNotFound // NOTE: Return a default texture ?
	}
	return texture, ResourceManagerError.NoError
}

@(export)
resource_manager_add_texture :: proc(path: string, type: TextureType) -> TextureHandle {
	// digest := hash.hash(hash.Algorithm.Insecure_SHA1, path)
	// defer delete(digest)

	handle := TextureHandle(path)
	if _, ok := RESOURCE_MANAGER.textures[handle]; ok {
		return handle
	}

	texture, err := texture_new(path, type)
	if err != TextureError.NoError {
		return TextureHandle("")
	}
	RESOURCE_MANAGER.textures[handle] = texture

	return handle
}

@(export)
resource_manager_delete_texture :: proc(handle: TextureHandle) {
	texture, ok := RESOURCE_MANAGER.textures[handle]
	if !ok {
		log.warnf("Texture already deleted: {}", handle)
		return
	}

	texture_free(texture)
	delete_key(&RESOURCE_MANAGER.textures, handle)
}

// General methods

resource_manager_new :: proc() {
	if RESOURCE_MANAGER != nil {
		log.panic("Can't have more than one ResourceManager instance!")
	}

	RESOURCE_MANAGER = new(ResourceManager)
	RESOURCE_MANAGER.textures = make(map[TextureHandle]^Texture)
}

resource_manager_free :: proc() {
	if RESOURCE_MANAGER == nil {
		log.panic("ResourceManager instance is nil!")
	}

	delete(RESOURCE_MANAGER.textures)
	delete(RESOURCE_MANAGER.materials)
	free(RESOURCE_MANAGER)

	RESOURCE_MANAGER = nil
}

resource_manager_get_textures :: proc() -> map[TextureHandle]^Texture {
	return RESOURCE_MANAGER.textures
}

resource_manager_get_materials :: proc() -> map[MaterialHandle]^Material {
	return RESOURCE_MANAGER.materials
}
