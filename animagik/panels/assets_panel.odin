package panel

import renderer "../../freya/renderer"

import im "../../freya/vendor/odin-imgui"


AssetsPanel :: struct {
	manager: ^renderer.ResourceManager,
}

assets_panel_new :: proc(resource_manager: ^renderer.ResourceManager) -> ^AssetsPanel {
	panel := new(AssetsPanel)
	panel.manager = resource_manager
	return panel
}

assets_panel_destroy :: proc(panel: ^AssetsPanel) {
	free(panel)
}

assets_panel_render :: proc(panel: ^AssetsPanel) {
	im.Begin("Textures")
	for _, texture in panel.manager.textures {
		im.Image(im.TextureID(uintptr(texture.id)), im.Vec2{100, 100})
	}
	im.End()
}
