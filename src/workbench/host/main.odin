package workbench_host

// The workbench's host: a small program that is never reloaded. It opens the
// window (through the game library), watches the game's source, data,
// shaders and models (assets: a GLB saved from Blender is packed by
// tools/pack_assets first) for saved files, rebuilds the game as a library under a new name,
// and swaps it in, handing the game's state across. If the build fails,
// nothing is swapped: the old game runs on and shows the compiler's errors.
//
//   tools/workbench.sh
//
// Commands can be given from outside, a line at a time, by writing them to
// build/workbench/command.txt; the answers are added to
// build/workbench/answer.txt (see COMMANDS below).

import "core:dynlib"
import "core:fmt"
import "core:os"
import "core:strings"
import "core:time"

OUT :: "build/workbench"
LIB_DIR :: OUT + "/lib"
LOG :: OUT + "/build.log"
COMMAND_FILE :: OUT + "/command.txt"
ANSWER_FILE :: OUT + "/answer.txt"
// What is watched, and how often.
WATCHED :: [?]string{"src/game", "src/workbench", "data", "assets"}
WATCH_EXTENSIONS :: [?]string{".odin", ".json", ".vert", ".frag", ".glb"}
SCAN_EVERY :: 250 * time.Millisecond

// Mirrors Status in ../lib.odin (handed across as it is).
Phase :: enum {
	Running,
	Building,
	Failed,
}
Status :: struct {
	phase:   Phase,
	text:    string,
	build_s: f32,
	swap_ms: f32,
	swaps:   int,
	fresh:   bool,
}

// The library's procedures, found by name (wb_ and the field's name).
Api :: struct {
	lib:             dynlib.Library,
	open_window:     proc() -> bool,
	load_graphics:   proc(),
	unload_graphics: proc(),
	start:           proc(),
	frame:           proc() -> bool,
	state:           proc() -> (g, kept: rawptr, g_size, kept_size: int),
	take_state:      proc(g, kept: rawptr),
	layout:          proc() -> u64,
	set_status:      proc(s: Status),
	command:         proc(line: string) -> string,
	setup:           proc() -> string,
	run_setup:       proc(text: string) -> string,
	workbench:       proc() -> string,
	take_workbench:  proc(text: string),
	host_request:    proc() -> string,
	release:         proc(),
	shutdown:        proc(),
}

Build :: struct {
	running:  bool,
	process:  os.Process,
	started:  time.Time,
	saved:    time.Time, // when the file that set it off was saved
	path:     string, // the library it makes
	why:      string,
}

// When no window can be opened (on a Mac, the screen asleep), so there is
// nothing to draw with: the workbench stops. (As src/main_desktop says it.)
NO_DISPLAY :: "workbench: no display: the window could not be opened, so there is nothing to draw with (on a Mac, is the screen asleep? caffeinate -u -t 5 wakes it)"

api: Api
status: Status
// Build switches (-define), set by the workbench's commands (skin on) or by
// --skin when it starts.
defines: map[string]string
build: Build
libraries: int
seen: map[string]time.Time

main :: proc() {
	for arg in os.args[1:] {
		if arg == "--skin" {
			defines["PROSIO_BASE"] = "true"
		}
	}
	os.make_directory_all(LIB_DIR)
	_ = os.write_entire_file(EXPORTS, "_wb_*\n")
	clear_old_libraries()
	scan(&seen)
	path := next_library_path()
	fmt.println("workbench: building the game...")
	start := time.now()
	if !build_now(path) {
		text, _ := os.read_entire_file(LOG, context.allocator)
		fmt.eprintln(string(text))
		fmt.eprintln("workbench: the game does not build; fix it and start again")
		os.exit(1)
	}
	fmt.printfln("workbench: built in %.2f s", time.duration_seconds(time.since(start)))
	if !load(path, &api) {
		os.exit(1)
	}
	if !api.open_window() {
		// Said on the console and in the answers, for whoever drives the
		// workbench from a shell (an agent at night reads it there).
		fmt.eprintln(NO_DISPLAY)
		append_line(ANSWER_FILE, NO_DISPLAY)
		os.exit(1)
	}
	api.load_graphics()
	api.start()
	api.set_status(status)
	last_scan := time.now()
	for {
		if !api.frame() {
			break
		}
		free_all(context.temp_allocator)
		if build.running {
			poll_build()
		} else if time.since(last_scan) > SCAN_EVERY {
			last_scan = time.now()
			if changed, newest, saved := scan(&seen); changed {
				start_build(newest, saved)
			}
		}
		run_commands()
		if request := api.host_request(); request != "" {
			handle_request(request)
		}
	}
	api.shutdown()
}

// Rebuilds the game in the background, so it keeps running meanwhile.
start_build :: proc(file: string, saved: time.Time) {
	build = {running = true, started = time.now(), saved = saved, path = next_library_path(), why = strings.clone(file)}
	status.phase = .Building
	api.set_status(status)
	// A data file: gen_data first. A model (a GLB, or the JSON beside one in
	// assets): the packer first, which writes what the game loads from it.
	cmd := strings.concatenate({
		strings.has_prefix(file, "data/") ? "build/tools/gen_data . > /dev/null && " : "",
		strings.has_prefix(file, "assets/") ? "build/tools/pack_assets . > /dev/null && " : "",
		lib_command(build.path), " > ", LOG, " 2>&1",
	}, context.temp_allocator)
	p, err := os.process_start({command = {"sh", "-c", cmd}})
	if err != nil {
		build.running = false
		status.phase = .Failed
		status.text = fmt.tprintf("could not start the build: %v", err)
		api.set_status(status)
		return
	}
	build.process = p
	fmt.printfln("workbench: %s changed: building", file)
}

poll_build :: proc() {
	state, err := os.process_wait(build.process, 0)
	if err != nil || !state.exited {
		return
	}
	build.running = false
	scan(&seen) // what the build itself wrote (gen_*.odin) does not set off another
	if state.exit_code != 0 {
		text, _ := os.read_entire_file(LOG, context.temp_allocator)
		status.phase = .Failed
		status.text = string(text)
		api.set_status(status)
		fmt.printfln("workbench: the build failed:\n%s", string(text))
		log_event(fmt.tprintf("build failed (%s)", build.why))
		return
	}
	build_s := f32(time.duration_seconds(time.since(build.started)))
	next: Api
	if !load(build.path, &next) {
		status.phase = .Failed
		status.text = "the new library could not be loaded"
		api.set_status(status)
		return
	}
	g, kept, g_size, kept_size := api.state()
	same := next.layout() == api.layout()
	setup := strings.clone(api.setup(), context.temp_allocator)
	workbench := strings.clone(api.workbench(), context.temp_allocator)
	api.unload_graphics()
	next.load_graphics()
	if same {
		next.take_state(g, kept)
		next.take_workbench(workbench)
	} else {
		// The old state does not fit the new code: a fresh scene, and the
		// set-up that made the old one, again.
		next.start()
		fmt.printfln("workbench: %s", next.run_setup(setup))
		next.take_workbench(workbench) // (the time and camera; the set-up is what was just replayed)
	}
	_, _ = g_size, kept_size
	// The old library stays loaded (see ../lib.odin), but what its own copy
	// of Odin's runtime keeps aside is freed now that everything has been
	// handed across: about 11 MB a swap otherwise.
	api.release()
	api = next
	status.phase = .Running
	status.text = ""
	status.swaps += 1
	status.build_s = build_s
	status.fresh = !same
	api.set_status(status)
	// The first frame of the new code, on the screen: how long after the save.
	running := api.frame()
	status.swap_ms = f32(time.duration_milliseconds(time.since(build.saved)))
	api.set_status(status)
	msg := fmt.tprintf("swap %d (%s): built in %.2f s, on screen %.2f s after the save%s",
		status.swaps, build.why, build_s, status.swap_ms / 1000, same ? "" : ", a fresh scene (the state changed shape)")
	fmt.printfln("workbench: %s", msg)
	log_event(msg)
	if !running {
		os.exit(0)
	}
}

// The library exports only its wb_ procedures. Anything else it exported
// that the host or an earlier library also has (some of Odin's runtime is
// weak, and macOS merges weak symbols across everything loaded) would be
// shared between them: the runtime's eight thread-local slots, for one, which
// fill up after seven swaps.
EXPORTS :: OUT + "/exports.txt"

lib_command :: proc(path: string) -> string {
	link := ODIN_OS == .Darwin ? fmt.tprintf(" -extra-linker-flags:\"-Wl,-exported_symbols_list,%s\"", EXPORTS) : ""
	extra := os.get_env("WORKBENCH_FLAGS", context.temp_allocator) // more build flags, for trying (say -o:speed)
	for name, value in defines {
		extra = fmt.tprintf("%s -define:%s=%s", extra, name, value)
	}
	return fmt.tprintf("odin build src/workbench -build-mode:dll -out:%s -define:WORKBENCH=true -define:RAYLIB_SHARED=true -vet%s %s", path, link, extra)
}

build_now :: proc(path: string) -> bool {
	cmd := fmt.tprintf("sh tools/gen_data.sh && sh tools/pack_assets.sh > /dev/null && %s > %s 2>&1", lib_command(path), LOG)
	state, _, _, err := os.process_exec({command = {"sh", "-c", cmd}}, context.temp_allocator)
	return err == nil && state.exit_code == 0
}

load :: proc(path: string, into: ^Api) -> bool {
	count, ok := dynlib.initialize_symbols(into, path, "wb_", "lib")
	if !ok {
		fmt.eprintfln("workbench: cannot load %s: %s (%d procedures found)", path, dynlib.last_error(), count)
		return false
	}
	return true
}

next_library_path :: proc() -> string {
	libraries += 1
	return fmt.aprintf("%s/game_%d.%s", LIB_DIR, libraries, dynlib.LIBRARY_FILE_EXTENSION)
}

clear_old_libraries :: proc() {
	entries, err := os.read_all_directory_by_path(LIB_DIR, context.temp_allocator)
	if err != nil {
		return
	}
	for e in entries {
		_ = os.remove(e.fullpath)
	}
}

// Notes the times of the watched files. changed: one is new or newer than
// when last seen; newest and saved: which, and when.
scan :: proc(seen: ^map[string]time.Time) -> (changed: bool, newest: string, saved: time.Time) {
	walk :: proc(dir: string, seen: ^map[string]time.Time, changed: ^bool, newest: ^string, saved: ^time.Time) {
		entries, err := os.read_all_directory_by_path(dir, context.temp_allocator)
		if err != nil {
			return
		}
		for e in entries {
			path := fmt.tprintf("%s/%s", dir, e.name)
			if e.type == .Directory {
				if e.name != "host" {
					walk(path, seen, changed, newest, saved)
				}
				continue
			}
			watched := false
			for ext in WATCH_EXTENSIONS {
				watched ||= strings.has_suffix(e.name, ext)
			}
			if !watched {
				continue
			}
			before, known := seen[path]
			if !known || time.diff(before, e.modification_time) > 0 {
				if known {
					changed^ = true
					if time.diff(saved^, e.modification_time) > 0 {
						delete(newest^)
						newest^ = strings.clone(path)
						saved^ = e.modification_time
					}
				}
				if !known {
					seen[strings.clone(path)] = e.modification_time
				} else {
					seen[path] = e.modification_time
				}
			}
		}
	}
	for dir in WATCHED {
		walk(dir, seen, &changed, &newest, &saved)
	}
	return
}

// Commands from outside: each line written to COMMAND_FILE runs once, and its
// answer is added to ANSWER_FILE. Besides the library's own commands (see
// wb_command), "quit" closes the workbench and "status" says how the last
// build went.
run_commands :: proc() {
	if !os.exists(COMMAND_FILE) {
		return
	}
	text, err := os.read_entire_file(COMMAND_FILE, context.temp_allocator)
	_ = os.remove(COMMAND_FILE)
	if err != nil {
		return
	}
	for line in strings.split_lines(string(text), context.temp_allocator) {
		if strings.trim_space(line) == "" {
			continue
		}
		answer: string
		switch strings.trim_space(line) {
		case "quit":
			api.shutdown()
			os.exit(0)
		case "status":
			answer = fmt.tprintf("%v, swaps %d, last build %.2f s, last swap %.2f s after the save, fresh %v%s", status.phase, status.swaps, status.build_s, status.swap_ms / 1000, status.fresh, build.running ? " (building)" : "")
		case:
			answer = api.command(line)
		}
		append_line(ANSWER_FILE, fmt.tprintf("%s -> %s", line, answer))
	}
}

log_event :: proc(msg: string) {
	append_line(OUT + "/events.txt", fmt.tprintf("%v %s", time.now(), msg))
}

append_line :: proc(path, line: string) {
	f, err := os.open(path, {.Write, .Create, .Append})
	if err != nil {
		return
	}
	defer os.close(f)
	_, _ = os.write_string(f, line)
	_, _ = os.write_string(f, "\n")
}

// What the workbench asks of the host: "define NAME=VALUE" changes a build
// switch and rebuilds.
handle_request :: proc(request: string) {
	if strings.has_prefix(request, "define ") {
		kv := strings.split_n(request[len("define "):], "=", 2, context.temp_allocator)
		if len(kv) == 2 {
			defines[strings.clone(kv[0])] = strings.clone(kv[1])
			if !build.running {
				start_build(fmt.tprintf("(%s)", request), time.now())
			}
		}
	}
}
