package main

import engn "engine"
import rndr "renderer"

import "core:log"

SHOULD_RUN: bool = true

Game :: struct {
	layer_stack: ^engn.LayerStack,
}

GAME: Game

event_callback :: proc(ev: engn.Event) {
	#partial switch e in ev {
	case engn.WindowResizeEvent:
		{
			rndr.on_window_resize(e.width, e.height)
		}
	}

	engn.layer_stk_propagate_event(GAME.layer_stack, ev)
}


start_engine :: proc(game: Game) {
	GAME = game

	when ODIN_DEBUG {
		log.info("Running in debug mode")
		logger := log.create_console_logger(log.Level.Debug)
	} else {
		logger := log.create_console_logger(log.Level.Warning)
	}
	context.logger = logger
	defer log.destroy_console_logger(logger)

	engn.WINDOW = engn.window_create(800, 600, "Freya Engine", event_callback)
	defer engn.window_destroy(&engn.WINDOW)

	rndr.initialize_context()

	rndr.resource_manager_new()
	defer rndr.resource_manager_free()

	rndr.renderer_initialize()
	defer rndr.renderer_shutdown()

	engn.layer_stk_init_layers(GAME.layer_stack)

	engn.init_imgui()

	last_frame: f64 = 0.0
	for !engn.window_should_close(&engn.WINDOW) && SHOULD_RUN {
		now := engn.window_get_time()
		delta_time := now - last_frame
		last_frame = now

		engn.window_poll_events()

		engn.layer_stk_update_layers(GAME.layer_stack, delta_time)
		engn.layer_stk_render_layers(GAME.layer_stack)

		engn.begin_imgui()
		engn.layer_stk_render_imgui_layers(GAME.layer_stack)
		engn.end_imgui()

		engn.window_swapbuffers(&engn.WINDOW)
	}

	engn.layer_stk_shutdown_layers(GAME.layer_stack)
	engn.layer_stk_free(GAME.layer_stack)
	engn.shutdown_imgui()
}
