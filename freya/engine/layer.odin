package engine

Layer :: struct {
	initialize:   proc(),
	shutdown:     proc(),
	update:       proc(delta_time: f64),
	render:       proc(),
	imgui_render: proc(),
	on_event:     proc(event: Event),

	// Vars
	is_active:    bool,
}

LayerStack :: struct {
	layers: [dynamic]Layer,
}

layer_stk_new :: proc() -> ^LayerStack {
	stack := new(LayerStack)
	stack.layers = make([dynamic]Layer)
	return stack
}

layer_stk_free :: proc(stack: ^LayerStack) {
	delete(stack.layers)
	free(stack)
}

layer_stk_push_layer :: proc(stack: ^LayerStack, layer: ^Layer) {
	append(&stack.layers, layer^)
}

layer_stk_pop_layer :: proc(stack: ^LayerStack) -> bool {
	if len(stack.layers) == 0 {
		return false
	}

	top_layer := &stack.layers[len(stack.layers) - 1]

	if top_layer.shutdown != nil {
		top_layer.shutdown()
	}

	top_layer.is_active = false

	pop(&stack.layers)

	return true
}

layer_stk_init_layers :: proc(stack: ^LayerStack) {
	for &layer in stack.layers {
		if layer.initialize != nil {
			layer.initialize()
		}
	}
}

layer_stk_shutdown_layers :: proc(stack: ^LayerStack) {
	for i := len(stack.layers) - 1; i >= 0; i -= 1 {
		layer := &stack.layers[i]
		if layer.shutdown != nil {
			layer.shutdown()
		}
	}
}

layer_stk_update_layers :: proc(stack: ^LayerStack, delta_time: f64) {
	for &layer in stack.layers {
		if layer.is_active && layer.update != nil {
			layer.update(delta_time)
		}
	}
}

layer_stk_render_layers :: proc(stack: ^LayerStack) {
	for &layer in stack.layers {
		if layer.is_active && layer.render != nil {
			layer.render()
		}
	}
}

layer_stk_render_imgui_layers :: proc(stack: ^LayerStack) {
	for &layer in stack.layers {
		if layer.is_active && layer.imgui_render != nil {
			layer.imgui_render()
		}
	}
}

layer_stk_propagate_event :: proc(stack: ^LayerStack, event: Event) {
	for i := len(stack.layers) - 1; i >= 0; i -= 1 {
		layer := &stack.layers[i]
		if layer.is_active && layer.on_event != nil {
			layer.on_event(event)
		}
	}
}
