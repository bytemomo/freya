package renderer

import "core:log"
import "core:mem"
import "core:strings"

import exr "vendor:OpenEXRCore"
import gl "vendor:OpenGL"
import stb_img "vendor:stb/image"

Skybox :: Cubemap

Cubemap :: struct {
	using tex: Texture,
	_vao:      u32,
	_vbo:      u32,
}

Texture :: struct {
	id:   u32,
	type: TextureType,
	path: string,
}

TextureType :: enum {
	Diffuse,
	Specular,
	Height,
	Ambient,
	Normals,
}

TextureError :: enum {
	NoError,
	FailedToLoad,
	NotSupported,
}

texture_new :: proc(file_path: string, type: TextureType) -> (^Texture, TextureError) {
	data: [1024]u8

	arena: mem.Arena
	mem.arena_init(&arena, data[:])
	alloc := mem.arena_allocator(&arena)

	path, allocation := strings.replace(file_path, "\\", "/", -1, alloc)
	if strings.has_suffix(path, ".exr") {
		log.errorf("EXR textures are not supported yet, path: %s\n", path)
		return nil, TextureError.NotSupported
		// return texture_new_with_exr(file_path, type)
	} else {
		return texture_new_with_stb(path, type)
	}
}

texture_new_with_stb :: proc(file_path: string, type: TextureType) -> (^Texture, TextureError) {
	filename := strings.unsafe_string_to_cstring(file_path)

	width, height, channels: i32
	stb_img.set_flip_vertically_on_load(1)
	data: [^]byte = stb_img.load(filename, &width, &height, &channels, 0)
	defer stb_img.image_free(data)

	if data == nil {
		log.errorf("Failed to load texture of type %v, path: %s\n", type, file_path)
		return nil, TextureError.FailedToLoad
	}

	format: i32
	switch channels {
	case 1:
		format = gl.RED
	case 3:
		format = gl.RGB
	case 4:
		format = gl.RGBA
	}

	texture: u32 = 0
	gl.GenTextures(1, &texture)
	gl.BindTexture(gl.TEXTURE_2D, texture)

	gl.TexImage2D(gl.TEXTURE_2D, 0, format, width, height, 0, u32(format), gl.UNSIGNED_BYTE, data)
	gl.GenerateMipmap(gl.TEXTURE_2D)

	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR_MIPMAP_LINEAR)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)
	gl.BindTexture(gl.TEXTURE_2D, 0)


	tex := new(Texture)
	tex.id = texture
	tex.type = type
	tex.path = file_path[:]

	return tex, TextureError.NoError
}

texture_new_with_exr :: proc(file_path: string, type: TextureType) -> (^Texture, TextureError) {
	exrctx: exr.context_t
	ctxinit: exr.context_initializer_t = exr.DEFAULT_CONTEXT_INITIALIZER

	result := exr.start_read(&exrctx, strings.unsafe_string_to_cstring(file_path), &ctxinit)
	if result != exr.result_t.SUCCESS {
		log.errorf("Failed to load EXR texture of type %v, path: %s\n", type, file_path)
	}
	defer exr.finish(&exrctx)

	part_count: i32 = 0
	if exr.get_count(exrctx, &part_count) != exr.result_t.SUCCESS {
		log.errorf(
			"Failed to get part count for EXR texture of type %v, path: %s\n",
			type,
			file_path,
		)
	}

	log.infof("EXR texture has %d parts\n", part_count)

	if part_count == 0 {
		log.errorf("EXR texture has no part, path: %s\n", file_path)
		return nil, TextureError.FailedToLoad
	} else if part_count > 1 {
		log.errorf("EXR texture has more than one part (not supported), path: %s\n", file_path)
		return nil, TextureError.FailedToLoad
	}

	i: i32 = 0
	data_window: exr.attr_box2i_t
	if exr.get_data_window(exrctx, i, &data_window) != exr.result_t.SUCCESS {
		log.errorf(
			"Failed to get data window for EXR texture of type %v, path: %s\n",
			type,
			file_path,
		)
		return nil, TextureError.FailedToLoad
	}

	width := data_window.max.x - data_window.min.x + 1
	height := data_window.max.y - data_window.min.y + 1

	chnlist: ^exr.attr_chlist_t
	if exr.get_channels(exrctx, i, &chnlist) != exr.result_t.SUCCESS {
		log.errorf(
			"Failed to get channels for EXR texture of type %v, path: %s\n",
			type,
			file_path,
		)
		return nil, TextureError.FailedToLoad
	}


	if chnlist.num_channels == 0 {
		log.errorf("EXR texture has no channels, path: %s\n", file_path)
		return nil, TextureError.FailedToLoad
	}

	format: i32
	if chnlist.num_channels == 1 {
		format = gl.RED
	} else if chnlist.num_channels == 2 {
		format = gl.RG
	} else if chnlist.num_channels == 3 {
		format = gl.RGB
	} else if chnlist.num_channels == 4 {
		format = gl.RGBA
	}

	pixel_type: u32
	pixel_size: i32 = 0
	switch chnlist.entries[0].pixel_type {
	case exr.pixel_type_t.FLOAT:
		pixel_type = gl.FLOAT
		pixel_size = chnlist.num_channels * size_of(f32)
	case exr.pixel_type_t.HALF:
		pixel_type = gl.HALF_FLOAT
		pixel_size = chnlist.num_channels * size_of(f16)
	case exr.pixel_type_t.UINT:
		pixel_type = gl.UNSIGNED_INT
		pixel_size = chnlist.num_channels * size_of(u32)
	}


	scanlines_per_chunk: i32
	if exr.get_scanlines_per_chunk(exrctx, i, &scanlines_per_chunk) != exr.result_t.SUCCESS {
		log.errorf(
			"Failed to get scanlines per chunk for EXR texture of type %v, path: %s\n",
			type,
			file_path,
		)
		return nil, TextureError.FailedToLoad
	}

	raw_image_size: u64
	if exr.get_chunk_unpacked_size(exrctx, i, &raw_image_size) != exr.result_t.SUCCESS {
		log.errorf(
			"Failed to get chunk unpacked size for EXR texture of type %v, path: %s\n",
			type,
			file_path,
		)
		return nil, TextureError.FailedToLoad
	}


	image_buffer: []byte = make([]byte, raw_image_size)
	defer delete(image_buffer)
	for j in 0 ..< height {
		chunk_info: exr.chunk_info_t
		if exr.read_scanline_chunk_info(exrctx, i, j, &chunk_info) != exr.result_t.SUCCESS {
			log.errorf(
				"Failed to get chunk info for EXR texture of type %v, path: %s\n",
				type,
				file_path,
			)
			return nil, TextureError.FailedToLoad
		}


		packed_data: []byte = make([]byte, chunk_info.packed_size)
		// defer delete(packed_data)
		if exr.read_chunk(exrctx, i, &chunk_info, rawptr(raw_data(packed_data))) !=
		   exr.result_t.SUCCESS {
			log.errorf(
				"Failed to read chunk for EXR texture of type %v, path: %s\n",
				type,
				file_path,
			)
		}

		decoder: exr.decode_pipeline_t = exr.DECODE_PIPELINE_INITIALIZER
		if exr.decoding_initialize(exrctx, i, &chunk_info, &decoder) != exr.result_t.SUCCESS {
			log.errorf(
				"Failed to initialize decoding for EXR texture of type %v, path: %s\n",
				type,
				file_path,
			)
			return nil, TextureError.FailedToLoad
		}
		// defer exr.decoding_destroy(exrctx, &decoder) // FIXME

		if exr.decoding_choose_default_routines(exrctx, i, &decoder) != exr.result_t.SUCCESS {
			log.errorf(
				"Failed to choose default routines for EXR texture of type %v, path: %s\n",
				type,
				file_path,
			)
			return nil, TextureError.FailedToLoad
		}

		bytes_per_channel: i8 = decoder.channels[0].bytes_per_element
		dest_chunk := mem.ptr_offset(
			raw_data(image_buffer),
			(j - data_window.min.y) * width * pixel_size,
		)
		for c in 0 ..< decoder.channel_count {
			decoder.channels[c].decode_to_ptr = mem.ptr_offset(
				dest_chunk,
				(c * i16(bytes_per_channel)),
			)
			decoder.channels[c].user_pixel_stride = pixel_size
			decoder.channels[c].user_line_stride = width * pixel_size
			decoder.channels[c].user_bytes_per_element = size_of(f32)
		}

		if exr.decoding_run(exrctx, i, &decoder) != exr.result_t.SUCCESS {
			log.errorf(
				"Failed to run decoding for EXR texture of type %v, path: %s\n",
				type,
				file_path,
			)
			return nil, TextureError.FailedToLoad
		}
	}


	texture: u32 = 0
	gl.GenTextures(1, &texture)
	gl.BindTexture(gl.TEXTURE_2D, texture)

	gl.TexImage2D(
		gl.TEXTURE_2D,
		0,
		format,
		width,
		height,
		0,
		u32(format),
		pixel_type,
		rawptr(raw_data(image_buffer)),
	)
	gl.GenerateMipmap(gl.TEXTURE_2D)

	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR_MIPMAP_LINEAR)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)
	gl.BindTexture(gl.TEXTURE_2D, 0)


	tex := new(Texture)
	tex.id = texture
	tex.type = type
	tex.path = file_path[:]

	return tex, TextureError.NoError
}

texture_new_empty :: proc(width: i32, height: i32) -> (^Texture, TextureError) {
	texture: u32 = 0
	gl.GenTextures(1, &texture)
	gl.BindTexture(gl.TEXTURE_2D, texture)

	gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA, width, height, 0, gl.RGBA, gl.UNSIGNED_BYTE, nil)

	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)

	tex := new(Texture)
	tex.id = texture
	// tex.type = type
	tex.path = ""

	return tex, TextureError.NoError
}

texture_free :: proc(texture: ^Texture) {
	gl.DeleteTextures(1, &texture.id)
	free(texture)
}

cubemap_new :: proc(file_paths: [6]string) -> (^Cubemap, TextureError) {
	cubemap: u32 = 0
	gl.GenTextures(1, &cubemap)
	gl.BindTexture(gl.TEXTURE_CUBE_MAP, cubemap)

	for i in 0 ..< 6 {
		filename := strings.unsafe_string_to_cstring(file_paths[i])

		width, height, channels: i32
		stb_img.set_flip_vertically_on_load(0)
		data: [^]byte = stb_img.load(filename, &width, &height, &channels, 0)
		defer stb_img.image_free(data)

		if data == nil {
			log.errorf("Failed to load cubemap texture, path: %s\n", file_paths[i])
			continue
		}

		format: i32
		switch channels {
		case 1:
			format = gl.RED
		case 3:
			format = gl.RGB
		case 4:
			format = gl.RGBA
		}

		gl.TexImage2D(
			u32(gl.TEXTURE_CUBE_MAP_POSITIVE_X + int(i)),
			0,
			format,
			width,
			height,
			0,
			u32(format),
			gl.UNSIGNED_BYTE,
			data,
		)
	}

	gl.TexParameteri(gl.TEXTURE_CUBE_MAP, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
	gl.TexParameteri(gl.TEXTURE_CUBE_MAP, gl.TEXTURE_MAG_FILTER, gl.LINEAR)
	gl.TexParameteri(gl.TEXTURE_CUBE_MAP, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE)
	gl.TexParameteri(gl.TEXTURE_CUBE_MAP, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE)
	gl.TexParameteri(gl.TEXTURE_CUBE_MAP, gl.TEXTURE_WRAP_R, gl.CLAMP_TO_EDGE)

	c := new(Cubemap)
	c.id = cubemap

	{ 	// Create object
		@(static) vertices: []f32 = {
			-1.0,
			1.0,
			-1.0,
			-1.0,
			-1.0,
			-1.0,
			1.0,
			-1.0,
			-1.0,
			1.0,
			-1.0,
			-1.0,
			1.0,
			1.0,
			-1.0,
			-1.0,
			1.0,
			-1.0,
			-1.0,
			-1.0,
			1.0,
			-1.0,
			-1.0,
			-1.0,
			-1.0,
			1.0,
			-1.0,
			-1.0,
			1.0,
			-1.0,
			-1.0,
			1.0,
			1.0,
			-1.0,
			-1.0,
			1.0,
			1.0,
			-1.0,
			-1.0,
			1.0,
			-1.0,
			1.0,
			1.0,
			1.0,
			1.0,
			1.0,
			1.0,
			1.0,
			1.0,
			1.0,
			-1.0,
			1.0,
			-1.0,
			-1.0,
			-1.0,
			-1.0,
			1.0,
			-1.0,
			1.0,
			1.0,
			1.0,
			1.0,
			1.0,
			1.0,
			1.0,
			1.0,
			1.0,
			-1.0,
			1.0,
			-1.0,
			-1.0,
			1.0,
			-1.0,
			1.0,
			-1.0,
			1.0,
			1.0,
			-1.0,
			1.0,
			1.0,
			1.0,
			1.0,
			1.0,
			1.0,
			-1.0,
			1.0,
			1.0,
			-1.0,
			1.0,
			-1.0,
			-1.0,
			-1.0,
			-1.0,
			-1.0,
			-1.0,
			1.0,
			1.0,
			-1.0,
			-1.0,
			1.0,
			-1.0,
			-1.0,
			-1.0,
			-1.0,
			1.0,
			1.0,
			-1.0,
			1.0,
		}

		gl.GenVertexArrays(1, &c._vao)
		gl.GenBuffers(1, &c._vbo)
		gl.BindVertexArray(c._vao)
		gl.BindBuffer(gl.ARRAY_BUFFER, c._vbo)
		gl.BufferData(gl.ARRAY_BUFFER, len(vertices) * size_of(f32), &vertices[0], gl.STATIC_DRAW)
		gl.EnableVertexAttribArray(0)
		gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 3 * size_of(f32), uintptr(0))
	}

	return c, TextureError.NoError
}

cubemap_draw :: proc(self: ^Cubemap) {
	gl.BindVertexArray(self._vao)
	gl.BindTexture(gl.TEXTURE_CUBE_MAP, self.id)
	gl.DrawArrays(gl.TRIANGLES, 0, 36)

}

cubemap_free :: proc(self: ^Cubemap) {
	gl.DeleteVertexArrays(1, &self._vao)
	gl.DeleteBuffers(1, &self._vbo)
	gl.DeleteTextures(1, &self.id)
	free(self)
}
