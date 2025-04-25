package engine

import "vendor:glfw"

import im "../vendor/odin-imgui"
import guizmo "../vendor/odin-imguizmo"

import "../vendor/odin-imgui/imgui_impl_glfw"
import "../vendor/odin-imgui/imgui_impl_opengl3"

DISABLE_DOCKING :: #config(DISABLE_DOCKING, false)

init_imgui :: proc() {
	im.CHECKVERSION()
	im.CreateContext()
	imgui_io := im.GetIO()
	imgui_io.ConfigFlags += {.NavEnableKeyboard}
	when !DISABLE_DOCKING {
		imgui_io.ConfigFlags += {.DockingEnable, .ViewportsEnable}

		style := im.GetStyle()
		style.WindowRounding = 0
		style.Colors[im.Col.WindowBg].w = 1
	}

	// im.StyleColorsDark()
	im.StyleColorsLight()
	setup_custom_theme()

	imgui_impl_glfw.InitForOpenGL(WINDOW.glfw_window, true)
	imgui_impl_opengl3.Init()
}

shutdown_imgui :: proc() {
	imgui_impl_opengl3.Shutdown()
	imgui_impl_glfw.Shutdown()
	im.DestroyContext()
}

begin_imgui :: proc() {
	imgui_impl_opengl3.NewFrame()
	imgui_impl_glfw.NewFrame()
	im.NewFrame()
	guizmo.begin_frame()
}

end_imgui :: proc() {
	im.Render()
	imgui_impl_opengl3.RenderDrawData(im.GetDrawData())

	backup_current_window := glfw.GetCurrentContext()
	im.UpdatePlatformWindows()
	im.RenderPlatformWindowsDefault()
	glfw.MakeContextCurrent(backup_current_window)

}


setup_custom_theme :: proc() {

	style: ^im.Style = im.GetStyle()
	colors := style.Colors

	// General window settings
	style.WindowRounding = 5.0
	style.FrameRounding = 5.0
	style.ScrollbarRounding = 5.0
	style.GrabRounding = 5.0
	style.TabRounding = 5.0
	style.WindowBorderSize = 1.0
	style.FrameBorderSize = 1.0
	style.PopupBorderSize = 1.0
	style.PopupRounding = 5.0

	// Setting the colors (Light version)
	colors[im.Col.Text] = im.Vec4{0.10, 0.10, 0.10, 1.00}
	colors[im.Col.TextDisabled] = im.Vec4{0.60, 0.60, 0.60, 1.00}
	colors[im.Col.WindowBg] = im.Vec4{0.95, 0.95, 0.95, 1.00}
	colors[im.Col.ChildBg] = im.Vec4{0.90, 0.90, 0.90, 1.00}
	colors[im.Col.PopupBg] = im.Vec4{0.98, 0.98, 0.98, 1.00}
	colors[im.Col.Border] = im.Vec4{0.70, 0.70, 0.70, 1.00}
	colors[im.Col.BorderShadow] = im.Vec4{0.00, 0.00, 0.00, 0.00}
	colors[im.Col.FrameBg] = im.Vec4{0.85, 0.85, 0.85, 1.00}
	colors[im.Col.FrameBgHovered] = im.Vec4{0.80, 0.80, 0.80, 1.00}
	colors[im.Col.FrameBgActive] = im.Vec4{0.75, 0.75, 0.75, 1.00}
	colors[im.Col.TitleBg] = im.Vec4{0.90, 0.90, 0.90, 1.00}
	colors[im.Col.TitleBgActive] = im.Vec4{0.85, 0.85, 0.85, 1.00}
	colors[im.Col.TitleBgCollapsed] = im.Vec4{0.90, 0.90, 0.90, 1.00}
	colors[im.Col.MenuBarBg] = im.Vec4{0.95, 0.95, 0.95, 1.00}
	colors[im.Col.ScrollbarBg] = im.Vec4{0.90, 0.90, 0.90, 1.00}
	colors[im.Col.ScrollbarGrab] = im.Vec4{0.80, 0.80, 0.80, 1.00}
	colors[im.Col.ScrollbarGrabHovered] = im.Vec4{0.75, 0.75, 0.75, 1.00}
	colors[im.Col.ScrollbarGrabActive] = im.Vec4{0.70, 0.70, 0.70, 1.00}

	// Accent colors with a soft pastel gray-green
	colors[im.Col.CheckMark] = im.Vec4{0.55, 0.65, 0.55, 1.00}
	colors[im.Col.SliderGrab] = im.Vec4{0.55, 0.65, 0.55, 1.00}
	colors[im.Col.SliderGrabActive] = im.Vec4{0.60, 0.70, 0.60, 1.00}
	colors[im.Col.Button] = im.Vec4{0.85, 0.85, 0.85, 1.00}
	colors[im.Col.ButtonHovered] = im.Vec4{0.80, 0.80, 0.80, 1.00}
	colors[im.Col.ButtonActive] = im.Vec4{0.75, 0.75, 0.75, 1.00}
	colors[im.Col.Header] = im.Vec4{0.75, 0.75, 0.75, 1.00}
	colors[im.Col.HeaderHovered] = im.Vec4{0.70, 0.70, 0.70, 1.00}
	colors[im.Col.HeaderActive] = im.Vec4{0.65, 0.65, 0.65, 1.00}

	// Additional styles
	style.FramePadding = im.Vec2{8.0, 4.0}
	style.ItemSpacing = im.Vec2{8.0, 4.0}
	style.IndentSpacing = 20.0
	style.ScrollbarSize = 16.0
}
