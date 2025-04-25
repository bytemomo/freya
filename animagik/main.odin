package animagik

import freya "../freya"
import engine "../freya/engine"

import "core:fmt"
import "core:mem"

import "core:strings"

main :: proc() {
	when ODIN_DEBUG {
		track: mem.Tracking_Allocator
		mem.tracking_allocator_init(&track, context.allocator)
		context.allocator = mem.tracking_allocator(&track)

		defer {
			if len(track.allocation_map) > 0 {
				fmt.eprintf("=== %v allocations not freed: ===\n", len(track.allocation_map))
				for _, entry in track.allocation_map {
					if !(strings.contains(entry.location.file_path, "vendor") ||
						   strings.contains(entry.location.file_path, "Odin")) {
						fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
					}
				}
			}
			if len(track.bad_free_array) > 0 {
				fmt.eprintf("=== %v incorrect frees: ===\n", len(track.bad_free_array))
				for entry in track.bad_free_array {
					fmt.eprintf("- %p @ %v\n", entry.memory, entry.location)
				}
			}
			mem.tracking_allocator_destroy(&track)
		}
	}

	game := freya.Game{engine.layer_stk_new()}

	// Add layers here
	gui_layer := gui_layer_new()
	engine.layer_stk_push_layer(game.layer_stack, gui_layer)

	freya.start_engine(game)
	free(gui_layer)
}
