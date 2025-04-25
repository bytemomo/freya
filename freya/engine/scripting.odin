package engine

import "base:runtime"
import "core:c"
import "core:strings"
import lua "vendor:lua/5.4"

Script :: struct {
	state: ^lua.State,
	path:  cstring,
}

script_new :: proc(path: string) -> ^Script {
	s := new(Script)
	s.path = strings.clone_to_cstring(path)

	_context := context
	s.state = lua.newstate(lua_context_allocator, &_context)
	return s
}

script_update :: proc(self: ^Script) {
	lua.L_dofile(self.state, self.path)
}

script_change :: proc(self: ^Script, path: string) {
	delete_cstring(self.path)
	self.path = strings.clone_to_cstring(path)
}

script_free :: proc(self: ^Script) {
	lua.close(self.state)
	delete_cstring(self.path)
	free(self)
}


@(private)
lua_context_allocator :: proc "c" (
	ud: rawptr,
	ptr: rawptr,
	osize, nsize: c.size_t,
) -> (
	buf: rawptr,
) {
	old_size := int(osize)
	new_size := int(nsize)
	context = (^runtime.Context)(ud)^

	if ptr == nil {
		data, err := runtime.mem_alloc(new_size)
		return raw_data(data) if err == .None else nil
	} else {
		if nsize > 0 {
			data, err := runtime.mem_resize(ptr, old_size, new_size)
			return raw_data(data) if err == .None else nil
		} else {
			runtime.mem_free(ptr)
			return
		}
	}
}
