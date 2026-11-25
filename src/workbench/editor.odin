package workbench

// The built-in editor: a panel over the right half of the window (F2 shows
// and hides it), several files open at once as tabs, on Odin's own
// core:text/edit (the cursor, selection, undo and redo, cut, copy and paste)
// and core:odin/tokenizer (colouring). Saving a file (Cmd+S) is what sets off
// a rebuild, as with any editor.
//
// Keys (Cmd on a Mac, Ctrl elsewhere): S save, Z undo, Shift+Z redo, X C V,
// A select all, F find in the file, Shift+F find across the project, L go to
// a line, P open a file by name, W close the tab, [ and ] the tab before and
// after. Arrows (Option: by word; Cmd: to the line's ends, or the file's),
// Shift to select, Page Up and Down. Esc gives the keyboard back to the game;
// a click on the panel takes it again.

import game "../game"
import "core:fmt"
import "core:odin/tokenizer"
import "core:os"
import "core:slice"
import "core:strconv"
import "core:strings"
import "core:text/edit"
import "core:unicode/utf8"
import rl "vendor:raylib"

EDITOR_FONT_SIZE :: 16 // in points
TAB_WIDTH :: 4
// The editor's font: Iosevka Fixed (SIL Open Font License, its licence beside
// it); if that file is missing, a monospace font macOS already has (never
// copied into the project).
EDITOR_FONTS :: [?]cstring {
	"assets/fonts/IosevkaFixed-Regular.ttf",
	"/System/Applications/Utilities/Terminal.app/Contents/Resources/Fonts/SF-Mono-Regular.otf",
}
SEARCHED :: [?]string{"src", "data", "tools", "docs"}
SEARCHED_EXTENSIONS :: [?]string{".odin", ".json", ".sh", ".md", ".vert", ".frag", ".txt"}
MOST_FOUND :: 300

Tab :: struct {
	path:    string,
	text:    strings.Builder,
	state:   edit.State,
	scroll:  int, // the first line shown
	dirty:   bool,
	starts:  [dynamic]int, // where each line starts
	counted: int, // the length of the text when starts was made (-1: make it again)
}

Prompt :: enum {
	None,
	Open, // a file by name
	Find, // in this file
	Find_All, // across the project
	Line, // go to a line
}

Found :: struct {
	path: string,
	line: int, // 0: the file itself
	text: string,
}

Build_Error :: struct {
	path:      string,
	line, col: int,
	message:   string,
}

Editor :: struct {
	visible, focused: bool,
	tabs:             [dynamic]^Tab,
	current:          int,
	prompt:           Prompt,
	query:            [dynamic]u8,
	found:            [dynamic]Found,
	found_sel:        int,
	font:             rl.Font,
	has_font:         bool,
	cell, line_h:     f32,
	dragging:         bool,
	errors:           [dynamic]Build_Error,
}

editor: Editor

editor_load_font :: proc() {
	codepoints: [dynamic]rune
	defer delete(codepoints)
	for r in rune(32) ..< 0x250 {append(&codepoints, r)}
	for r in ([]rune{'—', '–', '·', '•', '…', '°', '→', '←', '≤', '≥', '’', '“', '”'}) {append(&codepoints, r)}
	for path in EDITOR_FONTS {
		if os.exists(string(path)) {
			editor.font = rl.LoadFontEx(path, EDITOR_FONT_SIZE * 2, raw_data(codepoints), i32(len(codepoints)))
			editor.has_font = editor.font.texture.id != 0
			if editor.has_font {
				rl.SetTextureFilter(editor.font.texture, .BILINEAR)
				break
			}
		}
	}
	if !editor.has_font {
		editor.font = rl.GetFontDefault()
	}
	editor.cell = rl.MeasureTextEx(editor.font, "M", EDITOR_FONT_SIZE, 0).x
	editor.line_h = EDITOR_FONT_SIZE * 1.3
}

editor_unload_font :: proc() {
	if editor.has_font {
		rl.UnloadFont(editor.font)
		editor.has_font = false
	}
}

current_tab :: proc() -> ^Tab {
	if editor.current < 0 || editor.current >= len(editor.tabs) {
		return nil
	}
	return editor.tabs[editor.current]
}

// Opens a file at a line (from 1; 0 keeps where it was), in its tab if it
// is open already.
editor_open :: proc(path: string, line := 0, col := 0) -> bool {
	clean := project_path(path)
	editor.visible, editor.focused = true, true
	for t, i in editor.tabs {
		if t.path == clean {
			editor.current = i
			if line > 0 {go_to_line(t, line, col)}
			return true
		}
	}
	data, err := os.read_entire_file(clean, context.allocator)
	if err != nil {
		say(fmt.tprintf("cannot open %s", clean))
		return false
	}
	t := new(Tab)
	t.path = strings.clone(clean)
	t.text = strings.builder_make()
	strings.write_bytes(&t.text, data)
	delete(data)
	t.counted = -1
	tab_setup(t)
	append(&editor.tabs, t)
	editor.current = len(editor.tabs) - 1
	if line > 0 {go_to_line(t, line, col)} else {t.state.selection = {0, 0}}
	return true
}

tab_setup :: proc(t: ^Tab) {
	edit.init(&t.state, context.allocator, context.allocator)
	edit.setup_once(&t.state, &t.text)
	t.state.set_clipboard = proc(_: rawptr, text: string) -> bool {
		rl.SetClipboardText(strings.clone_to_cstring(text, context.temp_allocator))
		return true
	}
	t.state.get_clipboard = proc(_: rawptr) -> (string, bool) {
		c := rl.GetClipboardText()
		return string(c), c != nil
	}
}

editor_close :: proc(i: int) {
	t := editor.tabs[i]
	if t.dirty {
		say(fmt.tprintf("%s has unsaved changes: Cmd+S saves it, Cmd+W again closes it anyway", t.path))
		t.dirty = false // (a second Cmd+W closes it)
		return
	}
	edit.destroy(&t.state)
	strings.builder_destroy(&t.text)
	delete(t.starts)
	ordered_remove(&editor.tabs, i)
	editor.current = clamp(editor.current, 0, len(editor.tabs) - 1)
}

editor_save :: proc(t: ^Tab) {
	if err := os.write_entire_file(t.path, t.text.buf[:]); err != nil {
		say(fmt.tprintf("cannot save %s (%v)", t.path, err))
		return
	}
	t.dirty = false
	say(fmt.tprintf("saved %s", t.path))
}

text_of :: proc(t: ^Tab) -> string {
	return string(t.text.buf[:])
}

// Where each line starts, made again when the text has changed.
line_starts :: proc(t: ^Tab) -> []int {
	if t.counted != len(t.text.buf) || len(t.starts) == 0 {
		clear(&t.starts)
		append(&t.starts, 0)
		for b, i in t.text.buf {
			if b == '\n' {append(&t.starts, i + 1)}
		}
		t.counted = len(t.text.buf)
	}
	return t.starts[:]
}

line_of :: proc(t: ^Tab, at: int) -> int {
	starts := line_starts(t)
	i, _ := slice.binary_search(starts, at)
	if i >= len(starts) || starts[i] != at {i -= 1}
	return clamp(i, 0, len(starts) - 1)
}

line_end :: proc(t: ^Tab, line: int) -> int {
	starts := line_starts(t)
	if line + 1 < len(starts) {return starts[line + 1] - 1}
	return len(t.text.buf)
}

// The column on the screen of a place in a line (tabs counted out).
column_of :: proc(t: ^Tab, line, at: int) -> int {
	col := 0
	for i in line_starts(t)[line] ..< at {
		col = t.text.buf[i] == '\t' ? (col / TAB_WIDTH + 1) * TAB_WIDTH : col + 1
	}
	return col
}

// The place in a line at a column on the screen.
at_column :: proc(t: ^Tab, line, want: int) -> int {
	col := 0
	i := line_starts(t)[line]
	end := line_end(t, line)
	for i < end {
		next := t.text.buf[i] == '\t' ? (col / TAB_WIDTH + 1) * TAB_WIDTH : col + 1
		if next > want {break}
		col = next
		i += 1
	}
	return i
}

go_to_line :: proc(t: ^Tab, line: int, col := 0) {
	starts := line_starts(t)
	l := clamp(line - 1, 0, len(starts) - 1)
	at := min(starts[l] + max(col - 1, 0), line_end(t, l))
	t.state.selection = {at, at}
	t.scroll = max(l - visible_lines() / 3, 0)
}

visible_lines :: proc() -> int {
	h := f32(rl.GetScreenHeight())
	return max(int((h - 2 * editor.line_h - 34) / editor.line_h), 1)
}

// The keys, each frame, while the editor has them.
editor_keys :: proc() {
	t := current_tab()
	mod := rl.IsKeyDown(.LEFT_SUPER) || rl.IsKeyDown(.RIGHT_SUPER) || rl.IsKeyDown(.LEFT_CONTROL) || rl.IsKeyDown(.RIGHT_CONTROL)
	shift := rl.IsKeyDown(.LEFT_SHIFT) || rl.IsKeyDown(.RIGHT_SHIFT)
	alt := rl.IsKeyDown(.LEFT_ALT) || rl.IsKeyDown(.RIGHT_ALT)
	hit :: proc(k: rl.KeyboardKey) -> bool {return rl.IsKeyPressed(k) || rl.IsKeyPressedRepeat(k)}

	if editor.prompt != .None {
		prompt_keys()
		return
	}
	if rl.IsKeyPressed(.ESCAPE) {
		editor.focused = false
		return
	}
	if mod {
		switch {
		case rl.IsKeyPressed(.P): open_prompt(.Open)
		case rl.IsKeyPressed(.F): open_prompt(shift ? .Find_All : .Find)
		case rl.IsKeyPressed(.L) || rl.IsKeyPressed(.G): open_prompt(.Line)
		case rl.IsKeyPressed(.LEFT_BRACKET): if len(editor.tabs) > 0 {editor.current = (editor.current + len(editor.tabs) - 1) % len(editor.tabs)}
		case rl.IsKeyPressed(.RIGHT_BRACKET): if len(editor.tabs) > 0 {editor.current = (editor.current + 1) % len(editor.tabs)}
		}
	}
	if t == nil {
		return
	}
	s := &t.state
	s.builder = &t.text
	edit.update_time(s)
	line := line_of(t, s.selection[0])
	s.line_start = line_starts(t)[line]
	s.line_end = line_end(t, line)
	col := column_of(t, line, s.selection[0])
	s.up_index = line > 0 ? at_column(t, line - 1, col) : 0
	s.down_index = line + 1 < len(line_starts(t)) ? at_column(t, line + 1, col) : len(t.text.buf)
	before := len(t.text.buf)
	changed := false
	do_ :: proc(s: ^edit.State, c: edit.Command) {edit.perform_command(s, c)}
	if mod {
		switch {
		case rl.IsKeyPressed(.S): editor_save(t)
		case hit(.Z): do_(s, shift ? .Redo : .Undo); changed = true
		case hit(.Y): do_(s, .Redo); changed = true
		case rl.IsKeyPressed(.X): do_(s, .Cut); changed = true
		case rl.IsKeyPressed(.C): do_(s, .Copy)
		case rl.IsKeyPressed(.V): do_(s, .Paste); changed = true
		case rl.IsKeyPressed(.A): do_(s, .Select_All)
		case rl.IsKeyPressed(.W): editor_close(editor.current); return
		case hit(.LEFT): do_(s, shift ? .Select_Line_Start : .Line_Start)
		case hit(.RIGHT): do_(s, shift ? .Select_Line_End : .Line_End)
		case hit(.UP): do_(s, shift ? .Select_Start : .Start)
		case hit(.DOWN): do_(s, shift ? .Select_End : .End)
		case hit(.BACKSPACE): edit.delete_to(s, .Soft_Line_Start); changed = true
		}
	} else {
		for {
			r := rl.GetCharPressed()
			if r == 0 {break}
			edit.input_rune(s, r)
			changed = true
		}
		switch {
		case hit(.ENTER):
			// A new line, indented as the one it leaves.
			indent := line_starts(t)[line]
			for indent < len(t.text.buf) && (t.text.buf[indent] == '\t' || t.text.buf[indent] == ' ') {indent += 1}
			lead := strings.clone(string(t.text.buf[line_starts(t)[line]:indent]), context.temp_allocator)
			edit.input_text(s, "\n")
			edit.input_text(s, lead)
			changed = true
		case hit(.TAB): edit.input_text(s, "\t"); changed = true
		case hit(.BACKSPACE): do_(s, alt ? .Delete_Word_Left : .Backspace); changed = true
		case hit(.DELETE): do_(s, alt ? .Delete_Word_Right : .Delete); changed = true
		case hit(.LEFT): do_(s, alt ? (shift ? .Select_Word_Left : .Word_Left) : (shift ? .Select_Left : .Left))
		case hit(.RIGHT): do_(s, alt ? (shift ? .Select_Word_Right : .Word_Right) : (shift ? .Select_Right : .Right))
		case hit(.UP): do_(s, shift ? .Select_Up : .Up)
		case hit(.DOWN): do_(s, shift ? .Select_Down : .Down)
		case hit(.HOME): do_(s, shift ? .Select_Line_Start : .Line_Start)
		case hit(.END): do_(s, shift ? .Select_Line_End : .Line_End)
		case hit(.PAGE_UP), hit(.PAGE_DOWN):
			n := visible_lines() * (rl.IsKeyDown(.PAGE_UP) ? -1 : 1)
			target := clamp(line + n, 0, len(line_starts(t)) - 1)
			s.selection[0] = at_column(t, target, col)
			if !shift {s.selection[1] = s.selection[0]}
			t.scroll = clamp(t.scroll + n, 0, max(len(line_starts(t)) - 1, 0))
		}
	}
	if changed || len(t.text.buf) != before {
		t.dirty = true
		t.counted = -1
	}
	keep_in_view(t)
}

keep_in_view :: proc(t: ^Tab) {
	line := line_of(t, t.state.selection[0])
	n := visible_lines()
	if line < t.scroll {t.scroll = line}
	if line >= t.scroll + n {t.scroll = line - n + 1}
}

open_prompt :: proc(p: Prompt) {
	editor.prompt = p
	clear(&editor.query)
	clear(&editor.found)
	editor.found_sel = 0
	if p == .Open {search_files("")}
}

prompt_keys :: proc() {
	changed := false
	for {
		r := rl.GetCharPressed()
		if r == 0 {break}
		if r < 128 {
			append(&editor.query, u8(r))
			changed = true
		}
	}
	switch {
	case rl.IsKeyPressed(.ESCAPE):
		editor.prompt = .None
		return
	case rl.IsKeyPressed(.BACKSPACE) || rl.IsKeyPressedRepeat(.BACKSPACE):
		if len(editor.query) > 0 {
			pop(&editor.query)
			changed = true
		}
	case rl.IsKeyPressed(.DOWN):
		editor.found_sel = min(editor.found_sel + 1, max(len(editor.found) - 1, 0))
	case rl.IsKeyPressed(.UP):
		editor.found_sel = max(editor.found_sel - 1, 0)
	case rl.IsKeyPressed(.ENTER):
		prompt_enter()
		return
	}
	if changed {
		q := string(editor.query[:])
		editor.found_sel = 0
		#partial switch editor.prompt {
		case .Open: search_files(q)
		case .Find_All: if len(q) >= 2 {search_project(q)}
		}
	}
}

prompt_enter :: proc() {
	q := string(editor.query[:])
	t := current_tab()
	switch editor.prompt {
	case .None:
	case .Open, .Find_All:
		if editor.found_sel < len(editor.found) {
			f := editor.found[editor.found_sel]
			editor.prompt = .None
			editor_open(f.path, f.line)
		}
	case .Line:
		if t != nil {
			n, _ := strconv.parse_int(q)
			go_to_line(t, n)
		}
		editor.prompt = .None
	case .Find:
		// The next place after the cursor (round to the start), the prompt
		// left open for the one after.
		if t != nil && q != "" {
			text := text_of(t)
			from := max(t.state.selection[0], t.state.selection[1])
			i := strings.index(text[from:], q)
			if i >= 0 {
				i += from
			} else {
				i = strings.index(text, q)
			}
			if i >= 0 {
				t.state.selection = {i + len(q), i}
				keep_in_view(t)
			} else {
				say(fmt.tprintf("%q is not in this file", q))
			}
		}
	}
}

// Every file a person might open: the project's source, data, tools and docs.
project_files :: proc() -> []string {
	files: [dynamic]string
	files.allocator = context.temp_allocator
	walk :: proc(dir: string, files: ^[dynamic]string) {
		entries, err := os.read_all_directory_by_path(dir, context.temp_allocator)
		if err != nil {return}
		for e in entries {
			path := fmt.tprintf("%s/%s", dir, e.name)
			if e.type == .Directory {
				walk(path, files)
			} else {
				for ext in SEARCHED_EXTENSIONS {
					if strings.has_suffix(e.name, ext) {
						append(files, path)
						break
					}
				}
			}
		}
	}
	for dir in SEARCHED {walk(dir, &files)}
	append(&files, "README.md", "AGENTS.md")
	slice.sort(files[:])
	return files[:]
}

search_files :: proc(q: string) {
	clear(&editor.found)
	lower := strings.to_lower(q, context.temp_allocator)
	for path in project_files() {
		if strings.contains(strings.to_lower(path, context.temp_allocator), lower) {
			append(&editor.found, Found{strings.clone(path), 0, ""})
			if len(editor.found) >= MOST_FOUND {break}
		}
	}
}

search_project :: proc(q: string) {
	clear(&editor.found)
	lower := strings.to_lower(q, context.temp_allocator)
	for path in project_files() {
		data, err := os.read_entire_file(path, context.temp_allocator)
		if err != nil {continue}
		for line, i in strings.split_lines(string(data), context.temp_allocator) {
			if strings.contains(strings.to_lower(line, context.temp_allocator), lower) {
				append(&editor.found, Found{strings.clone(path), i + 1, strings.clone(strings.trim_space(line))})
				if len(editor.found) >= MOST_FOUND {return}
			}
		}
	}
}

// The compiler's errors, from the build's log: "path(line:col) message".
parse_errors :: proc(log: string) {
	clear(&editor.errors)
	for line in strings.split_lines(log, context.temp_allocator) {
		open := strings.index_byte(line, '(')
		close := strings.index_byte(line, ')')
		if open <= 0 || close <= open {continue}
		where_ := strings.split(line[open + 1:close], ":", context.temp_allocator)
		if len(where_) != 2 {continue}
		l, ok1 := strconv.parse_int(where_[0])
		c, ok2 := strconv.parse_int(where_[1])
		if !ok1 || !ok2 {continue}
		path := project_path(line[:open])
		append(&editor.errors, Build_Error{strings.clone(path), l, c, strings.clone(strings.trim_space(line[close + 1:]))})
	}
}

// The mouse on the panel: a click takes the keyboard, places the cursor or
// chooses a tab; dragging selects; the wheel scrolls.
editor_mouse :: proc() {
	if !editor.visible {return}
	m := rl.GetMousePosition()
	x0 := f32(rl.GetScreenWidth()) / 2
	inside := m.x >= x0
	if rl.IsMouseButtonPressed(.LEFT) {
		editor.focused = inside
		if !inside {return}
	}
	if !inside {return}
	t := current_tab()
	if wheel := rl.GetMouseWheelMove(); wheel != 0 && t != nil {
		t.scroll = clamp(t.scroll - int(wheel * 3), 0, max(len(line_starts(t)) - 1, 0))
	}
	top := f32(28)
	if rl.IsMouseButtonPressed(.LEFT) && m.y < top {
		x := x0 + 6
		for tab, i in editor.tabs {
			w := f32(len(tab_name(tab))) * editor.cell + 24
			if m.x >= x && m.x < x + w {editor.current = i}
			x += w + 4
		}
		return
	}
	if t == nil {return}
	gutter := 6 * editor.cell
	line := clamp(t.scroll + int((m.y - top - 4) / editor.line_h), 0, len(line_starts(t)) - 1)
	at := at_column(t, line, int((m.x - x0 - gutter - 8) / editor.cell + 0.5))
	if rl.IsMouseButtonPressed(.LEFT) {
		shift := rl.IsKeyDown(.LEFT_SHIFT) || rl.IsKeyDown(.RIGHT_SHIFT)
		t.state.selection[0] = at
		if !shift {t.state.selection[1] = at}
		editor.dragging = true
	} else if editor.dragging && rl.IsMouseButtonDown(.LEFT) {
		t.state.selection[0] = at
	}
	if !rl.IsMouseButtonDown(.LEFT) {editor.dragging = false}
}

tab_name :: proc(t: ^Tab) -> string {
	i := strings.last_index_byte(t.path, '/')
	return fmt.tprintf("%s%s", t.path[i + 1:], t.dirty ? " *" : "")
}

// Colours.
INK :: rl.Color{220, 222, 214, 255}
DIM :: rl.Color{120, 126, 140, 255}
KEYWORD :: rl.Color{240, 150, 90, 255}
STRING :: rl.Color{150, 210, 120, 255}
NUMBER :: rl.Color{190, 150, 240, 255}
COMMENT :: rl.Color{110, 130, 120, 255}
TYPE :: rl.Color{110, 200, 210, 255}
DIRECTIVE :: rl.Color{120, 170, 250, 255}
PANEL :: rl.Color{22, 24, 30, 255}

draw_editor :: proc() {
	if !editor.visible {return}
	w := f32(rl.GetScreenWidth())
	h := f32(rl.GetScreenHeight())
	x0 := w / 2
	rl.DrawRectangleRec({x0, 0, w - x0, h}, PANEL)
	if editor.focused {rl.DrawRectangleRec({x0, 0, 2, h}, {250, 210, 90, 255})}
	// Tabs.
	x := x0 + 6
	for t, i in editor.tabs {
		name := tab_name(t)
		tw := f32(len(name)) * editor.cell + 24
		rl.DrawRectangleRec({x, 3, tw, 24}, i == editor.current ? rl.Color{60, 64, 76, 255} : rl.Color{34, 36, 44, 255})
		draw_mono(name, x + 12, 7, i == editor.current ? INK : DIM)
		x += tw + 4
	}
	t := current_tab()
	top := f32(28)
	bottom := h - 34
	if t == nil {
		draw_mono("No file open. Cmd+P opens one by name; a compile error, clicked, opens at its line.", x0 + 14, top + 20, DIM)
	} else {
		draw_tab(t, x0, top, bottom)
	}
	// The line along the bottom: where the cursor is, or the prompt.
	rl.DrawRectangleRec({x0, bottom, w - x0, 34}, {34, 36, 44, 255})
	if editor.prompt != .None {
		label := [Prompt]string{.None = "", .Open = "open", .Find = "find", .Find_All = "find in the project", .Line = "line"}
		draw_mono(fmt.tprintf("%s: %s_", label[editor.prompt], string(editor.query[:])), x0 + 10, bottom + 8, {250, 210, 90, 255})
		draw_found(x0, w, bottom)
	} else if t != nil {
		line := line_of(t, t.state.selection[0])
		col := column_of(t, line, t.state.selection[0]) + 1
		draw_mono(fmt.tprintf("%s  %d:%d%s   F2 hides · Esc gives the keys back · Cmd+P open · Cmd+F find · Cmd+S save", t.path, line + 1, col, t.dirty ? "  (unsaved)" : ""), x0 + 10, bottom + 8, DIM)
	}
}

draw_found :: proc(x0, w, bottom: f32) {
	if editor.prompt != .Open && editor.prompt != .Find_All {return}
	rows := min(len(editor.found), 18)
	first := clamp(editor.found_sel - rows + 1, 0, max(len(editor.found) - rows, 0))
	y := bottom - f32(rows) * editor.line_h - 8
	rl.DrawRectangleRec({x0, y - 4, w - x0, f32(rows) * editor.line_h + 8}, {30, 32, 40, 250})
	for i in 0 ..< rows {
		f := editor.found[first + i]
		ry := y + f32(i) * editor.line_h
		if first + i == editor.found_sel {
			rl.DrawRectangleRec({x0, ry - 2, w - x0, editor.line_h}, {70, 64, 40, 255})
		}
		text := f.line > 0 ? fmt.tprintf("%s:%d  %s", f.path, f.line, f.text) : f.path
		draw_mono(text, x0 + 10, ry, INK, int((w - x0 - 20) / editor.cell))
	}
}

draw_tab :: proc(t: ^Tab, x0, top, bottom: f32) {
	starts := line_starts(t)
	n := visible_lines()
	t.scroll = clamp(t.scroll, 0, max(len(starts) - 1, 0))
	last := min(t.scroll + n, len(starts))
	gutter := 6 * editor.cell
	tx := x0 + gutter + 8
	cursor := t.state.selection[0]
	lo, hi := edit.sorted_selection(&t.state)
	cursor_line := line_of(t, cursor)
	max_cols := int((f32(rl.GetScreenWidth()) - tx - 6) / editor.cell)
	for l in t.scroll ..< last {
		y := top + 4 + f32(l - t.scroll) * editor.line_h
		if l == cursor_line {
			rl.DrawRectangleRec({x0, y - 2, f32(rl.GetScreenWidth()) - x0, editor.line_h}, {40, 43, 52, 255})
		}
		marked := false
		for e in editor.errors {
			if e.path == t.path && e.line == l + 1 {marked = true}
		}
		if marked {rl.DrawRectangleRec({x0, y - 2, 5, editor.line_h}, {240, 90, 80, 255})}
		number := fmt.tprintf("%5d", l + 1)
		draw_mono(number, x0 + 2, y, marked ? rl.Color{240, 120, 110, 255} : DIM)
		// The selection on this line.
		ls, le := starts[l], line_end(t, l)
		if hi > ls && lo <= le && lo != hi {
			a := column_of(t, l, max(lo, ls))
			b := column_of(t, l, min(hi, le)) + (hi > le ? 1 : 0)
			rl.DrawRectangleRec({tx + f32(a) * editor.cell, y - 2, f32(b - a) * editor.cell, editor.line_h}, {60, 80, 120, 255})
		}
	}
	// The text, coloured.
	from := starts[t.scroll]
	to := last < len(starts) ? starts[last] : len(t.text.buf)
	if strings.has_suffix(t.path, ".odin") {
		draw_odin(t, from, to, tx, top, max_cols)
	} else {
		draw_plain(t, from, to, tx, top, max_cols, strings.has_suffix(t.path, ".json"))
	}
	// The cursor.
	if cursor_line >= t.scroll && cursor_line < last && (int(rl.GetTime() * 2) % 2 == 0 || !editor.focused) {
		cx := tx + f32(column_of(t, cursor_line, cursor)) * editor.cell
		cy := top + 4 + f32(cursor_line - t.scroll) * editor.line_h
		rl.DrawRectangleRec({cx - 1, cy - 2, 2, editor.line_h}, {250, 210, 90, 255})
	}
}

// Draws text from a place, each character in its cell, with tabs counted
// out; up to max_cols columns of each line.
draw_run :: proc(t: ^Tab, from, to: int, tx, top: f32, max_cols: int, color: rl.Color) {
	line := line_of(t, from)
	col := column_of(t, line, from)
	for i := from; i < to; {
		b := t.text.buf[i]
		if b == '\n' {
			line += 1
			col = 0
			i += 1
			continue
		}
		if b == '\t' {
			col = (col / TAB_WIDTH + 1) * TAB_WIDTH
			i += 1
			continue
		}
		r, size := utf8_rune(t.text.buf[i:])
		if col < max_cols && line >= t.scroll && r != ' ' {
			y := top + 4 + f32(line - t.scroll) * editor.line_h
			rl.DrawTextCodepoint(editor.font, r, {tx + f32(col) * editor.cell, y}, EDITOR_FONT_SIZE, color)
		}
		col += 1
		i += size
	}
}

utf8_rune :: proc(b: []u8) -> (rune, int) {
	if len(b) == 0 {return 0, 1}
	if b[0] < 0x80 {return rune(b[0]), 1}
	r, size := utf8.decode_rune(b)
	return r, max(size, 1)
}

draw_odin :: proc(t: ^Tab, from, to: int, tx, top: f32, max_cols: int) {
	src := string(t.text.buf[from:to])
	tk: tokenizer.Tokenizer
	tokenizer.init(&tk, src, t.path, proc(pos: tokenizer.Pos, msg: string, args: ..any) {})
	last := 0
	prev: tokenizer.Token_Kind
	for {
		tok := tokenizer.scan(&tk)
		if tok.kind == .EOF {break}
		start := tok.pos.offset
		if start < last {continue}
		end := start + len(tok.text)
		if tok.kind == .Semicolon && tok.text == "\n" {continue}
		color := INK
		switch {
		case tok.kind == .Comment: color = COMMENT
		case tok.kind == .String || tok.kind == .Rune: color = STRING
		case tok.kind == .Integer || tok.kind == .Float || tok.kind == .Imag: color = NUMBER
		case tokenizer.is_keyword(tok.kind): color = KEYWORD
		case tok.kind == .Ident && (prev == .Hash || prev == .At): color = DIRECTIVE
		case tok.kind == .Hash || tok.kind == .At: color = DIRECTIVE
		case tok.kind == .Ident && len(tok.text) > 0 && tok.text[0] >= 'A' && tok.text[0] <= 'Z': color = TYPE
		case tok.kind != .Ident: color = DIM
		}
		draw_run(t, from + start, from + min(end, len(src)), tx, top, max_cols, color)
		last = end
		prev = tok.kind
	}
}

// Data and other text: strings, numbers and the rest (in JSON, keys apart).
draw_plain :: proc(t: ^Tab, from, to: int, tx, top: f32, max_cols: int, json: bool) {
	i := from
	for i < to {
		b := t.text.buf[i]
		j := i + 1
		color := INK
		switch {
		case json && b == '"':
			for j < to && t.text.buf[j] != '"' && t.text.buf[j] != '\n' {
				if t.text.buf[j] == '\\' {j += 1}
				j += 1
			}
			j = min(j + 1, to)
			k := j
			for k < to && t.text.buf[k] == ' ' {k += 1}
			color = k < to && t.text.buf[k] == ':' ? TYPE : STRING
		case json && ((b >= '0' && b <= '9') || b == '-'):
			for j < to && ((t.text.buf[j] >= '0' && t.text.buf[j] <= '9') || t.text.buf[j] == '.' || t.text.buf[j] == 'e') {j += 1}
			color = NUMBER
		case json && (b == '{' || b == '}' || b == '[' || b == ']' || b == ',' || b == ':'):
			color = DIM
		case:
			for j < to && t.text.buf[j] != '"' && t.text.buf[j] != '\n' && !(json && (t.text.buf[j] == '{' || t.text.buf[j] == '}' || t.text.buf[j] == ',' || t.text.buf[j] == ':')) {j += 1}
		}
		draw_run(t, i, j, tx, top, max_cols, color)
		i = j
	}
}

draw_mono :: proc(text: string, x, y: f32, color: rl.Color, max_cols := 1 << 30) {
	col := 0
	for r in text {
		if col >= max_cols {break}
		if r != ' ' {
			rl.DrawTextCodepoint(editor.font, r, {x + f32(col) * editor.cell, y}, EDITOR_FONT_SIZE, color)
		}
		col += 1
	}
}

// What the editor hands to the next library on a swap: its tabs, where the
// cursor is in each, and the text of any not saved.
editor_text :: proc() -> string {
	b := strings.builder_make(context.temp_allocator)
	fmt.sbprintf(&b, "#editor %v %v %d\n", editor.visible, editor.focused, editor.current)
	for t in editor.tabs {
		fmt.sbprintf(&b, "#tab %v %d %d %d %d %s\n", t.dirty, t.state.selection[0], t.state.selection[1], t.scroll, t.dirty ? len(t.text.buf) : 0, t.path)
		if t.dirty {
			strings.write_bytes(&b, t.text.buf[:])
			strings.write_byte(&b, '\n')
		}
	}
	return strings.to_string(b)
}

take_editor_text :: proc(text: string) {
	rest := text
	next_line :: proc(rest: ^string) -> string {
		i := strings.index_byte(rest^, '\n')
		if i < 0 {
			line := rest^
			rest^ = ""
			return line
		}
		line := rest^[:i]
		rest^ = rest^[i + 1:]
		return line
	}
	for len(rest) > 0 {
		line := next_line(&rest)
		w := strings.fields(line, context.temp_allocator)
		if len(w) == 4 && w[0] == "#editor" {
			editor.visible, editor.focused = w[1] == "true", w[2] == "true"
			editor.current, _ = strconv.parse_int(w[3])
		} else if len(w) >= 7 && w[0] == "#tab" {
			dirty := w[1] == "true"
			sel0, _ := strconv.parse_int(w[2])
			sel1, _ := strconv.parse_int(w[3])
			scroll, _ := strconv.parse_int(w[4])
			size, _ := strconv.parse_int(w[5])
			path := strings.join(w[6:], " ", context.temp_allocator)
			current := editor.current
			if editor_open(path) {
				t := editor.tabs[len(editor.tabs) - 1]
				if dirty && size <= len(rest) {
					strings.builder_reset(&t.text)
					strings.write_string(&t.text, rest[:size])
					rest = rest[min(size + 1, len(rest)):]
					t.dirty = true
					t.counted = -1
				}
				t.state.selection = {clamp(sel0, 0, len(t.text.buf)), clamp(sel1, 0, len(t.text.buf))}
				t.scroll = scroll
			}
			editor.current = current
		}
	}
	editor.current = clamp(editor.current, 0, max(len(editor.tabs) - 1, 0))
	_ = game.g
}

// A path as the project names it (from its folder), whether it came absolute
// (from Odin's #location or the compiler) or not.
project_path :: proc(path: string) -> string {
	wd, _ := os.get_working_directory(context.temp_allocator)
	cwd := strings.trim_right(wd, "/")
	if strings.has_prefix(path, cwd) {
		return strings.trim_left(path[len(cwd):], "/")
	}
	return path
}
