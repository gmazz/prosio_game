package workbench

// The command menu: Shift+1 (!) opens a list of every command (commands/commands.odin);
// typing narrows it, the arrows choose, Enter runs (or, for a command that
// needs more, puts it on the line to finish), Esc closes. While it is open
// the game has no keyboard.
//
// Keys that work without it, while the game has the keys (as keys.txt sets
// them; see keys.odin): Shift+2 shows and hides the editor (editor.odin),
// Shift+3 replays the current set-up, Shift+4 pauses and goes on, Shift+5
// steps a frame while paused, Shift+6 opens and closes the pane (panes.odin). With the free camera on, the arrows move the
// camera.

import cmd "commands"
import game "../game"
import "core:fmt"
import "core:os"
import "core:strconv"
import "core:text/edit"
import "core:strings"
import rl "vendor:raylib"

MENU_TEXT :: 20
MENU_ROWS :: 14
FREE_CAMERA_SPEED :: 14 // metres a second

Menu :: struct {
	open:     bool,
	input:    [dynamic]u8,
	selected: int,
	answer:   string,
	answer_t: f64,
}

menu: Menu

// Keys for the workbench, each frame, before the game moves on.
workbench_keys :: proc(dt: f32) {
	if program_driven {
		game.keyboard_enabled = false
		for rl.GetCharPressed() != 0 {}
		return
	}
	keys_follow_file()
	// The workbench's own keys act only while the game has the keys (see
	// keys.odin); wherever you are typing they type themselves.
	typing := menu.open || inspector_edit.active || (editor.visible && editor.focused) || pane_typing()
	action, acted := bench_key_pressed()
	acted &&= !typing
	if acted {
		for rl.GetCharPressed() != 0 {} // (the character it typed goes nowhere)
		switch action {
		case .Menu:
			menu.open = true
			clear(&menu.input)
			menu.selected = 0
		case .Editor:
			editor.visible = !editor.visible
			editor.focused = editor.visible
		case .Replay: say(cmd.replay())
		case .Pause: say(run_line("pause"))
		case .Step: say(run_line("step"))
		case .Panes: say(run_line("pane"))
		}
	}
	if !menu.open {
		editor_mouse()
		inspect_mouse()
	}
	switch {
	case acted: // (nothing else this frame)
	case menu.open: menu_keys()
	case inspector_edit.active: inspector_keys()
	case pane_typing(): pane_keys()
	case editor.visible && editor.focused: editor_keys()
	case cmd.view.free:
		move: game.Vec2
		if rl.IsKeyDown(.LEFT) {move.x -= 1}
		if rl.IsKeyDown(.RIGHT) {move.x += 1}
		if rl.IsKeyDown(.UP) {move.y -= 1}
		if rl.IsKeyDown(.DOWN) {move.y += 1}
		cmd.view.at += move * FREE_CAMERA_SPEED * dt
	}
	// The game has the keys when nothing of the workbench's does, and not on
	// the frame a workbench key acts (Shift+1 would also set the pixel size)
	// or the workbench was typing (Esc leaving the editor would also pause).
	game.keyboard_enabled = !acted && !typing && !menu.open && !cmd.view.free && !(editor.visible && editor.focused) && !inspector_edit.active && !pane_typing()
}

menu_keys :: proc() {
	for {
		c := rl.GetCharPressed()
		if c == 0 {
			break
		}
		if c >= 32 && c < 127 && rune(c) != '`' {
			append(&menu.input, u8(c))
			menu.selected = 0
		}
	}
	matches := menu_matches()
	switch {
	case rl.IsKeyPressed(.ESCAPE):
		menu.open = false
	case rl.IsKeyPressed(.BACKSPACE) || rl.IsKeyPressedRepeat(.BACKSPACE):
		if len(menu.input) > 0 {pop(&menu.input)}
		menu.selected = 0
	case rl.IsKeyPressed(.DOWN):
		menu.selected = min(menu.selected + 1, max(len(matches) - 1, 0))
	case rl.IsKeyPressed(.UP):
		menu.selected = max(menu.selected - 1, 0)
	case rl.IsKeyPressed(.TAB):
		if len(matches) > 0 {complete(matches[menu.selected])}
	case rl.IsKeyPressed(.ENTER):
		line := strings.trim_space(string(menu.input[:]))
		// A command chosen from the list that needs more goes on the line to
		// be finished; one that needs nothing more runs.
		if len(matches) > 0 && !strings.has_prefix(line, matches[menu.selected].name) {
			c := matches[menu.selected]
			if c.args != "" {
				complete(c)
				break
			}
			line = c.name
		}
		if line != "" {
			say(run_line(line))
			clear(&menu.input)
			menu.selected = 0
		}
	}
}

complete :: proc(c: cmd.Command) {
	clear(&menu.input)
	append(&menu.input, c.name)
	append(&menu.input, ' ')
}

// The commands that go with what is typed: the first word as the start of a
// command, or anything typed found in its group, name or what it does.
menu_matches :: proc() -> []cmd.Command {
	typed := strings.to_lower(strings.trim_space(string(menu.input[:])), context.temp_allocator)
	out: [dynamic]cmd.Command
	out.allocator = context.temp_allocator
	first := typed
	if i := strings.index_byte(typed, ' '); i >= 0 {
		first = typed[:i]
	}
	for c in cmd.COMMANDS {
		hay := strings.to_lower(strings.concatenate({c.group, " ", c.name, " ", c.help}, context.temp_allocator), context.temp_allocator)
		if typed == "" || strings.has_prefix(c.name, first) || strings.contains(hay, typed) {
			append(&out, c)
		}
	}
	return out[:]
}

say :: proc(answer: string) {
	delete(menu.answer)
	menu.answer = strings.clone(answer)
	menu.answer_t = rl.GetTime()
}

// A command from the menu, the keys or outside: the workbench's own first
// (those that need the window), then the game's (commands.odin).
run_line :: proc(line: string) -> string {
	words := strings.fields(strings.to_lower(line, context.temp_allocator), context.temp_allocator)
	if len(words) >= 2 && words[0] == "go" && words[1] == "mouse" {
		at, ok := mouse_on_ground()
		if !ok {
			return "the mouse is not over the ground"
		}
		answer, _ := cmd.run(fmt.tprintf("go %.2f %.2f", at.x, at.y))
		return answer
	}
	// (For trying the editor from outside: typing at the cursor, undo, save.)
	if len(words) >= 2 && (words[0] == "editor-files" || words[0] == "editor-search") {
		q := strings.trim_space(line[len(words[0]):])
		if words[0] == "editor-files" {search_files(q)} else {search_project(q)}
		if len(editor.found) == 0 {return "nothing found"}
		f := editor.found[0]
		return fmt.tprintf("%d found; the first %s:%d %s", len(editor.found), f.path, f.line, f.text)
	}
	if len(words) >= 1 && strings.has_prefix(words[0], "editor-") {
		t := current_tab()
		if t == nil {return "no file open"}
		t.state.builder = &t.text
		edit.update_time(&t.state)
		// (Closing: the x or Cmd+W, Cmd+Shift+W, and the answers to its question.)
		switch words[0] {
		case "editor-close":
			editor_close(editor.current, len(words) > 1 && words[1] == "discard")
			if tt := current_tab(); tt != nil && tt.asking {return fmt.tprintf("%s asks: unsaved: S save, D discard, Esc stay", tt.path)}
			return fmt.tprintf("%d tabs open, the editor %s", len(editor.tabs), editor.focused ? "has the keys" : "gave the keys back")
		case "editor-answer":
			if !t.asking {return "the tab is not asking"}
			switch len(words) > 1 ? words[1] : "" {
			case "s": editor_answer(t, .Save)
			case "d": editor_answer(t, .Discard)
			case: editor_answer(t, .Stay)
			}
			return fmt.tprintf("%d tabs open, the editor %s", len(editor.tabs), editor.focused ? "has the keys" : "gave the keys back")
		}
		switch words[0] {
		case "editor-type":
			text, _ := strings.replace_all(strings.trim_space(line[len("editor-type"):]), "\\n", "\n", context.temp_allocator)
			if text != "" {
				edit.input_text(&t.state, text)
				t.dirty, t.counted = true, -1
			}
		case "editor-undo":
			edit.perform_command(&t.state, .Undo)
			t.dirty, t.counted = true, -1
		case "editor-save":
			editor_save(t)
		case "editor-revert":
			if data, err := os.read_entire_file(t.path, context.temp_allocator); err == nil {
				strings.builder_reset(&t.text)
				strings.write_bytes(&t.text, data)
				t.dirty, t.counted = false, -1
				t.state.selection = {0, 0}
			}
		}
		line := line_of(t, t.state.selection[0])
		return fmt.tprintf("%s %d:%d%s: %q", t.path, line + 1, column_of(t, line, t.state.selection[0]) + 1, t.dirty ? " (unsaved)" : "", string(t.text.buf[line_starts(t)[line]:line_end(t, line)]))
	}
	if len(words) >= 1 && words[0] == "select" {
		// select prosio | nearest | KIND (the nearest of it) | none
		what := len(words) > 1 ? words[1] : "nearest"
		p := game.g.prosio.pos
		best, best_d := -1, f32(1e9)
		cands := candidates()
		for c, i in cands {
			if i == 0 && what != "prosio" {continue}
			if what != "nearest" && what != "prosio" && !strings.equal_fold(strings.trim_prefix(fmt.tprintf("%v", c.thing), "game."), what) {continue}
			if d := game.length2({c.pos.x, c.pos.z} - p); d < best_d {best, best_d = i, d}
			if what == "prosio" {break}
		}
		if what == "none" || best < 0 {
			selection.active = false
			return "nothing selected"
		}
		select_thing(cands[best].thing, cands[best].index)
		return inspect_text()
	}
	if len(words) >= 3 && words[0] == "click" {
		// click X Y: as a click of the mouse there (points from the top left).
		x, _ := strconv.parse_f32(words[1])
		y, _ := strconv.parse_f32(words[2])
		select_at({x, y})
		return inspect_text()
	}
	if len(words) >= 1 && words[0] == "where" {
		// Where Prosio is on the screen (points), for clicking him.
		p := game.g.prosio
		s := rl.GetWorldToScreen({p.pos.x, p.height + 1, p.pos.y}, view_camera())
		return fmt.tprintf("%.0f %.0f", s.x, s.y)
	}
	if len(words) >= 2 && words[0] == "show" {return show(words[1])}
	if len(words) >= 3 && words[0] == "set" {
		rest := strings.trim_space(line[strings.index(line, words[1]) + len(words[1]):])
		return set_field(words[1], rest)
	}
	if len(words) >= 1 && (words[0] == "pane" || words[0] == "tune" || words[0] == "tune-save" || words[0] == "tune-reset" || words[0] == "tune-list" || words[0] == "tune-sets" || words[0] == "tune-load" || words[0] == "bench" || words[0] == "mixing") {
		return pane_command(line)
	}
	if len(words) >= 1 && words[0] == "inspect" {return inspect_text()}
	if len(words) >= 2 && words[0] == "open-entry" {
		n, _ := strconv.parse_int(words[1])
		entries := cmd.index_of(selection.thing)
		if !selection.active || n < 0 || n >= len(entries) {return "no such entry"}
		return open_entry(entries[n])
	}
	if len(words) >= 1 && words[0] == "edit" {
		editor.visible = !editor.visible
		editor.focused = editor.visible
		return editor.visible ? "the editor" : "the editor hidden"
	}
	if len(words) >= 2 && words[0] == "open" {
		// open PATH or PATH:LINE (as the compiler writes it, or with a line number)
		spec := strings.trim_space(line[strings.index(line, words[1]):])
		path, at := spec, 0
		if i := strings.last_index_byte(spec, ':'); i > 0 {
			if n, ok := strconv.parse_int(spec[i + 1:]); ok {path, at = spec[:i], n}
		}
		return editor_open(path, at) ? fmt.tprintf("open: %s", path) : fmt.tprintf("no file %s", path)
	}
	if len(words) >= 1 && words[0] == "menu-close" {
		menu.open = false
		return "menu closed"
	}
	if len(words) >= 1 && words[0] == "menu-open" {
		// The menu open with this typed (for looking at it from outside).
		menu.open = true
		clear(&menu.input)
		if i := strings.index_byte(line, ' '); i >= 0 {append(&menu.input, strings.trim_space(line[i:]))}
		menu.selected = 0
		return "menu open"
	}
	if len(words) >= 2 && words[0] == "skin" {
		host_request = fmt.aprintf("define PROSIO_BASE=%v", words[1] == "on")
		return fmt.tprintf("skin %s: rebuilding", words[1])
	}
	answer, _ := cmd.run(line)
	return answer
}

// Where on the ground the mouse points: the game's camera made again as
// draw_frame makes it (looking at g.camera from CAMERA_OFFSET times its zoom,
// 38 degrees), over the whole window. (The game keeps its own camera to
// itself; this misses only the fraction of a pixel the pixel art shifts.)
CAMERA_FOV :: 38

mouse_on_ground :: proc() -> (game.Vec2, bool) {
	g := &game.g
	target := rl.Vector3{g.camera.x, 0.8, g.camera.y}
	cam := rl.Camera3D{position = target + game.CAMERA_OFFSET * g.camera_zoom, target = target, up = {0, 1, 0}, fovy = CAMERA_FOV, projection = .PERSPECTIVE}
	ray := rl.GetScreenToWorldRay(rl.GetMousePosition(), cam)
	if ray.direction.y >= -0.0001 {
		return {}, false
	}
	t := -ray.position.y / ray.direction.y
	hit := ray.position + ray.direction * t
	return {hit.x, hit.z}, true
}

draw_menu :: proc() {
	w := rl.GetScreenWidth()
	if menu.answer != "" && rl.GetTime() - menu.answer_t < 4 && !menu.open {
		text := strings.clone_to_cstring(menu.answer, context.temp_allocator)
		tw := rl.MeasureText(text, MENU_TEXT)
		rl.DrawRectangle(w / 2 - tw / 2 - 10, 10, tw + 20, MENU_TEXT + 12, {20, 22, 26, 220})
		rl.DrawText(text, w / 2 - tw / 2, 16, MENU_TEXT, {240, 230, 200, 255})
	}
	if !menu.open {
		return
	}
	pw := min(w - 40, 980)
	x := (w - pw) / 2
	y := i32(40)
	matches := menu_matches()
	rows := min(len(matches), MENU_ROWS)
	first := clamp(menu.selected - MENU_ROWS + 1, 0, max(len(matches) - MENU_ROWS, 0))
	h := i32(rows + 3) * (MENU_TEXT + 8) + 16
	rl.DrawRectangle(x, y, pw, h, {24, 26, 32, 240})
	rl.DrawRectangleLines(x, y, pw, h, {250, 210, 90, 255})
	line := fmt.ctprintf("> %s_", string(menu.input[:]))
	rl.DrawText(line, x + 12, y + 10, MENU_TEXT, {255, 255, 255, 255})
	for i in 0 ..< rows {
		c := matches[first + i]
		ry := y + 14 + i32(i + 1) * (MENU_TEXT + 8)
		if first + i == menu.selected {
			rl.DrawRectangle(x + 6, ry - 3, pw - 12, MENU_TEXT + 6, {70, 64, 40, 255})
		}
		rl.DrawText(strings.clone_to_cstring(c.group, context.temp_allocator), x + 12, ry, MENU_TEXT, {150, 160, 175, 255})
		// (Each column clipped to its width.)
		rl.BeginScissorMode(x + 150, ry - 3, 400, MENU_TEXT + 6)
		rl.DrawText(fmt.ctprintf("%s %s", c.name, c.args), x + 150, ry, MENU_TEXT, {250, 210, 90, 255})
		rl.EndScissorMode()
		rl.DrawText(strings.clone_to_cstring(c.help, context.temp_allocator), x + 560, ry, MENU_TEXT - 2, {210, 210, 200, 255})
	}
	foot := menu.answer != "" ? strings.clone_to_cstring(menu.answer, context.temp_allocator) : "type to narrow, arrows to choose, Enter to run, Tab to finish a command, Esc to close"
	rl.DrawText(foot, x + 12, y + h - MENU_TEXT - 10, MENU_TEXT - 2, {200, 230, 200, 255})
}
