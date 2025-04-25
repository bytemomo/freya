package renderer

import "core:log"

import gl "vendor:OpenGL"

FrameBuffer :: struct {
	id:            u32,
	attachments:   []FrameBufferAttachment,
	width, height: i32,
	texture:       ^Texture,
	rbo:           u32,
}

FrameBufferAttachment :: enum {
	Color,
	DepthStencil,
}

framebuffer_new :: proc(width, height: i32, types: []FrameBufferAttachment) -> ^FrameBuffer {
	fbo := new(FrameBuffer)

	fbo.width = width
	fbo.height = height
	fbo.attachments = types

	id: u32 = 0
	gl.GenFramebuffers(1, &id)
	gl.BindFramebuffer(gl.FRAMEBUFFER, id)

	fbo.id = id
	_framebuffer_add_attachment(fbo)

	if gl.CheckFramebufferStatus(gl.FRAMEBUFFER) != gl.FRAMEBUFFER_COMPLETE {
		panic("Framebuffer is not complete")
	}

	gl.BindFramebuffer(gl.FRAMEBUFFER, 0)
	gl.BindTexture(gl.TEXTURE_2D, 0)
	gl.BindRenderbuffer(gl.RENDERBUFFER, 0)
	return fbo
}

framebuffer_rescale :: proc(fbo: ^FrameBuffer, width, height: i32) {
	fbo.width = width
	fbo.height = height

	gl.BindFramebuffer(gl.FRAMEBUFFER, fbo.id)

	gl.BindTexture(gl.TEXTURE_2D, fbo.texture.id)
	gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA, width, height, 0, gl.RGBA, gl.UNSIGNED_BYTE, nil)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)
	gl.FramebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, fbo.texture.id, 0)

	gl.BindRenderbuffer(gl.RENDERBUFFER, fbo.rbo)
	gl.RenderbufferStorage(gl.RENDERBUFFER, gl.DEPTH24_STENCIL8, width, height)
	gl.FramebufferRenderbuffer(
		gl.FRAMEBUFFER,
		gl.DEPTH_STENCIL_ATTACHMENT,
		gl.RENDERBUFFER,
		fbo.rbo,
	)

	gl.BindFramebuffer(gl.FRAMEBUFFER, 0)
	gl.BindTexture(gl.TEXTURE_2D, 0)
	gl.BindRenderbuffer(gl.RENDERBUFFER, 0)
}

framebuffer_bind :: proc(fbo: ^FrameBuffer) {
	gl.BindFramebuffer(gl.FRAMEBUFFER, fbo.id)
	gl.Viewport(0, 0, fbo.width, fbo.height)
}

framebuffer_unbind :: proc() {
	gl.BindFramebuffer(gl.FRAMEBUFFER, 0)
}

framebuffer_free :: proc(fbo: ^FrameBuffer) {
	gl.DeleteFramebuffers(1, &fbo.id)

	texture_free(fbo.texture)
	free(fbo)
}

_framebuffer_add_attachment :: proc(fbo: ^FrameBuffer) {
	for t in fbo.attachments {
		switch t {
		case FrameBufferAttachment.Color:
			tex, err := texture_new_empty(fbo.width, fbo.height)
			if err != TextureError.NoError {
				log.fatal("Failed to create texture for framebuffer")
			}
			fbo.texture = tex
			gl.FramebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, tex.id, 0)
		case FrameBufferAttachment.DepthStencil:
			rbo: u32 = 0
			gl.GenRenderbuffers(1, &rbo)
			gl.BindRenderbuffer(gl.RENDERBUFFER, rbo)
			gl.RenderbufferStorage(gl.RENDERBUFFER, gl.DEPTH24_STENCIL8, fbo.width, fbo.height)
			gl.FramebufferRenderbuffer(
				gl.FRAMEBUFFER,
				gl.DEPTH_STENCIL_ATTACHMENT,
				gl.RENDERBUFFER,
				rbo,
			)
			fbo.rbo = rbo
		}
	}
}
