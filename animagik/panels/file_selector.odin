package panel

import "core:os"
import "core:strings"

import im "../../freya/vendor/odin-imgui"

FileSelector :: struct {
	parent_dir:         string,
	selected_file_path: string,
	show_file_selector: bool,
}

FileInfo :: struct {
	name:   string,
	is_dir: bool,
}

file_selector_new :: proc() -> ^FileSelector {
	selector := new(FileSelector)
	selector.show_file_selector = false
	selector.parent_dir = "."
	return selector
}

file_selector_free :: proc(self: ^FileSelector) {
	free(self)
}

file_selector_reset :: proc(selector: ^FileSelector) {
	selector.parent_dir = "."
	selector.selected_file_path = ""
	selector.show_file_selector = false
}

file_selector_panel :: proc(selector: ^FileSelector) -> string {
	if im.Begin("File Selector") {
		im.Text("Choose a file:")
		file_infos: [dynamic]FileInfo = make([dynamic]FileInfo, 10)
		get_file_paths(selector.parent_dir, &file_infos)
		for info in file_infos {
			if info.name == "" {
				continue
			}

			name: string = ""
			if info.is_dir {
				// name = info.name + "/"
				name = strings.concatenate({info.name, "/"})
			} else {
				name = info.name
			}
			if im.Selectable(strings.unsafe_string_to_cstring(name)) {
				if info.is_dir {
					selector.parent_dir = strings.concatenate(
						{selector.parent_dir, "/", info.name},
					)
					im.End()
					return ""
				} else {
					selector.selected_file_path = strings.concatenate(
						{selector.parent_dir, "/", info.name},
					)
					im.End()
					return selector.selected_file_path
				}
			}
		}
	}
	im.End()
	return selector.selected_file_path
}

@(private)
get_file_paths :: proc(parent: string, file_paths: ^[dynamic]FileInfo) {
	fd, error := os.open(parent)
	if error != os.ERROR_NONE {
		return
	}

	infos, err := os.read_dir(fd, 0)
	if err != os.ERROR_NONE {
		return
	}
	for info in infos {
		append(file_paths, FileInfo{info.name, info.is_dir})
	}
}
