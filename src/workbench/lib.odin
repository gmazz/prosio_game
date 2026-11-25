package workbench

// The workbench: the game, built as a library the host (host/main.odin)
// rebuilds and swaps in on every save, with the workbench's own panels drawn
// over it. Built only by tools/workbench.sh, with -define:WORKBENCH=true; the
// game the players get contains none of this.
//
// The host calls the procedures exported here (all named wb_*). It keeps every
// library it has loaded until it closes: the game's state holds texts that
// live inside the library that made them.

import cmd "commands"
import game "../game"
import "base:runtime"
import "core:fmt"
import "core:math"
import "core:mem"
import "core:strings"
import "core:time"
import rl "vendor:raylib"

// What the host has told us about the latest build (see wb_set_status).
Phase :: enum {
	Running, // nothing being built
	Building,
	Failed, // the last build failed: its errors are in status.text
}

Status :: struct {
	phase:      Phase,
	text:       string, // the compiler's errors when Failed
	build_s:    f32, // how long the last good build took
	swap_ms:    f32, // from the save to the first frame of the new code
	swaps:      int,
	fresh:      bool, // the last swap started the scene afresh (the state's shape had changed)
}

status: Status
kept_copy: game.Kept

// Frame times, for the panel and the "frame-time" command.
FRAME_SAMPLES :: 120
// How far to the right the camera looks while the editor is open (metres,
// times the zoom): a quarter of the window's width.
EDITOR_CAMERA_SHIFT :: 4.1
frame_ms: [FRAME_SAMPLES]f32
frame_next: int
frame_tick: time.Tick
// The work in a frame: from its start until its drawing is handed over (before
// waiting for the screen, which vsync holds to 60 a second).
work_ms: [FRAME_SAMPLES]f32
work_start: time.Tick
draw_start: time.Tick // (the game's drawing is timed up to where the workbench's own begins)

@(export, link_name = "wb_open_window")
wb_open_window :: proc() {
	game.open_window("Prosio — workbench", 1280, 720)
	// Keeps running when the window is hidden or minimised (raylib otherwise
	// waits for the window to come back), so it goes on building and taking
	// commands.
	rl.SetWindowState({.WINDOW_ALWAYS_RUN})
}

@(export, link_name = "wb_load_graphics")
wb_load_graphics :: proc() {
	game.load_graphics()
	game.set_ground_layout()
	editor_load_font()
	game.workbench_after_update = after_update
	game.workbench_after_draw = after_draw
	frame_tick = time.tick_now()
}

@(export, link_name = "wb_unload_graphics")
wb_unload_graphics :: proc() {
	editor_unload_font()
	game.unload_graphics()
}

// A fresh meadow and a fresh Prosio, straight into the game. Nothing is read
// from or written to the saved game or the controls file.
@(export, link_name = "wb_start")
wb_start :: proc() {
	game.g.opts = {no_save = true}
	game.keyboard_enabled = true
	game.continue_game()
	game.set_ground_layout()
	game.scene = .Playing
}

// A frame: the workbench's keys, then the game moved on (or not: paused,
// slowed, sped up; see commands.View), the camera as the commands want it,
// and the drawing (with the workbench's panels over it).
@(export, link_name = "wb_frame")
wb_frame :: proc() -> bool {
	work_start = time.tick_now()
	dt := min(game.frame_time(), 1.0 / 20)
	workbench_keys(dt)
	v := &cmd.view
	total := dt * v.speed
	runs := clamp(int(math.ceil(total * 60)), 1, 8)
	if v.paused {
		total, runs = 1.0 / 60, v.steps > 0 ? 1 : 0
		v.steps = max(v.steps - 1, 0)
	}
	update_start := time.tick_now()
	for _ in 0 ..< runs {
		game.g.frame += 1
		game.update_frame(total / f32(runs))
	}
	update_ms = f32(time.duration_milliseconds(time.tick_since(update_start)))
	cmd.apply_view(dt)
	after_update()
	draw_shifted(nil)
	return game.running()
}

// The frame drawn (and saved to a file, with a path), the camera looking a
// little to the right while the editor is open over the right half, so that
// he stays in sight on the left.
draw_shifted :: proc(path: cstring) {
	draw_start = time.tick_now()
	shift: f32 = editor.visible ? EDITOR_CAMERA_SHIFT * game.g.camera_zoom : 0
	game.g.camera.x += shift
	game.draw_frame(path)
	game.g.camera.x -= shift
}

// The current set-up (commands.odin), to be replayed after a fresh start.
@(export, link_name = "wb_setup")
wb_setup :: proc() -> string {
	return cmd.setup_text()
}

@(export, link_name = "wb_run_setup")
wb_run_setup :: proc(text: string) -> string {
	done, failed := cmd.run_setup(text)
	return fmt.tprintf("set-up replayed: %d commands, %d did nothing", done, failed)
}

// The workbench's own state (the set-up, time and camera), handed to the next
// library on a swap.
@(export, link_name = "wb_workbench")
wb_workbench :: proc() -> string {
	return fmt.tprintf("%s%s%s", cmd.workbench_text(), selection_text(), editor_text())
}

@(export, link_name = "wb_take_workbench")
wb_take_workbench :: proc(text: string) {
	commands := text
	if i := strings.index(text, "#editor "); i >= 0 {
		commands = text[:i]
		take_editor_text(text[i:])
	}
	if i := strings.index(commands, "#select "); i >= 0 {
		end := strings.index_byte(commands[i:], '\n')
		take_selection_text(commands[i:][:end if end >= 0 else len(commands) - i])
		commands = strings.concatenate({commands[:i], commands[i:][end + 1 if end >= 0 else len(commands) - i:]}, context.temp_allocator)
	}
	cmd.take_workbench_text(commands)
}

// What the workbench asks of the host (a build switch changed, say): taken
// once, then cleared.
host_request: string

@(export, link_name = "wb_host_request")
wb_host_request :: proc() -> string {
	r := host_request
	host_request = ""
	return r
}

// The game's state, for the next library: g and what is kept beside it.
@(export, link_name = "wb_state")
wb_state :: proc() -> (g, kept: rawptr, g_size, kept_size: int) {
	kept_copy = game.kept()
	return &game.g, &kept_copy, size_of(game.Game), size_of(game.Kept)
}

@(export, link_name = "wb_take_state")
wb_take_state :: proc(g, kept: rawptr) {
	mem.copy(&game.g, g, size_of(game.Game))
	game.restore_kept((^game.Kept)(kept)^)
	game.set_ground_layout()
}

// A fingerprint of the shape of the state: every field's name, place and
// type, all the way down. When it changes, the old state cannot be copied
// into the new code, and the host starts the scene afresh instead.
@(export, link_name = "wb_layout")
wb_layout :: proc() -> u64 {
	h: u64 = 14695981039346656037
	seen: map[^runtime.Type_Info]bool
	defer delete(seen)
	layout_walk(&h, type_info_of(game.Game), &seen)
	layout_walk(&h, type_info_of(game.Kept), &seen)
	return h
}

layout_mix :: proc(h: ^u64, data: []byte) {
	for b in data {
		h^ = (h^ ~ u64(b)) * 1099511628211
	}
}

layout_walk :: proc(h: ^u64, ti: ^runtime.Type_Info, seen: ^map[^runtime.Type_Info]bool) {
	if ti == nil {
		return
	}
	n := [2]int{ti.size, ti.align}
	layout_mix(h, mem.ptr_to_bytes(&n))
	if ti in seen {
		return
	}
	seen[ti] = true
	#partial switch v in ti.variant {
	case runtime.Type_Info_Named:
		layout_mix(h, transmute([]byte)v.name)
		layout_walk(h, v.base, seen)
	case runtime.Type_Info_Struct:
		for i in 0 ..< int(v.field_count) {
			layout_mix(h, transmute([]byte)v.names[i])
			off := v.offsets[i]
			layout_mix(h, mem.ptr_to_bytes(&off))
			layout_walk(h, v.types[i], seen)
		}
	case runtime.Type_Info_Array:
		c := v.count
		layout_mix(h, mem.ptr_to_bytes(&c))
		layout_walk(h, v.elem, seen)
	case runtime.Type_Info_Enumerated_Array:
		c := v.count
		layout_mix(h, mem.ptr_to_bytes(&c))
		layout_walk(h, v.elem, seen)
		layout_walk(h, v.index, seen)
	case runtime.Type_Info_Enum:
		for name in v.names {layout_mix(h, transmute([]byte)name)}
		layout_walk(h, v.base, seen)
	case runtime.Type_Info_Bit_Set:
		r := [2]i64{v.lower, v.upper}
		layout_mix(h, mem.ptr_to_bytes(&r))
		layout_walk(h, v.elem, seen)
	case runtime.Type_Info_Union:
		for variant in v.variants {layout_walk(h, variant, seen)}
	case runtime.Type_Info_Matrix:
		layout_walk(h, v.elem, seen)
	}
}

@(export, link_name = "wb_set_status")
wb_set_status :: proc(s: Status) {
	delete(status.text)
	status = s
	status.text = strings.clone(s.text)
	parse_errors(status.phase == .Failed ? status.text : "")
}

// A command from the host (see host/main.odin): the answer is its reply.
@(export, link_name = "wb_command")
wb_command :: proc(line: string) -> string {
	words := strings.fields(line, context.temp_allocator)
	if len(words) == 0 {
		return ""
	}
	switch words[0] {
	case "pad":
		// Whether the game can read a controller now, and what is held on it.
		when ODIN_OS == .Darwin {
			down, stick, ok := game.system_pad_read()
			return fmt.tprintf("controller seen: %v, held: %v, stick (%.2f, %.2f), library %d", ok, down, stick.x, stick.y, status.swaps)
		}
	case "shot":
		if len(words) > 1 {
			path := strings.clone_to_cstring(words[1], context.temp_allocator)
			draw_shifted(path)
			return fmt.tprintf("saved %s", words[1])
		}
	case "frame-time":
		avg, most: f32
		for ms in frame_ms {
			avg += ms / FRAME_SAMPLES
			most = max(most, ms)
		}
		work, work_most: f32
		for ms in work_ms {
			work += ms / FRAME_SAMPLES
			work_most = max(work_most, ms)
		}
		return fmt.tprintf("frame time: %.2f ms on average, %.2f at most; work in a frame %.2f ms on average, %.2f at most; over the last %d frames, %d animals", avg, most, work, work_most, FRAME_SAMPLES, game.g.enemy_count)
	}
	return run_line(line)
}

@(export, link_name = "wb_shutdown")
wb_shutdown :: proc() {
	game.unload_graphics()
	game.close_window()
}

after_update :: proc() {
	now := time.tick_now()
	frame_ms[frame_next] = f32(time.duration_milliseconds(time.tick_diff(frame_tick, now)))
	frame_next = (frame_next + 1) % FRAME_SAMPLES
	frame_tick = now
}

after_draw :: proc() {
	draw_ms = f32(time.duration_milliseconds(time.tick_since(draw_start)))
	work_ms[frame_next] = f32(time.duration_milliseconds(time.tick_since(work_start)))
	draw_overlays()
	draw_status()
	draw_inspector()
	draw_editor()
	draw_menu()
}
