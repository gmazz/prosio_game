package workbench

// The panes: a panel for each mechanic of the game, with the things to try it
// with, the live numbers, and the numbers of its formulas to turn. Shift+6
// (keys.txt) or the menu's "pane attacks" opens one; again, or "pane off",
// closes it. It sits on the right, or left of the editor while that is open.
//
// Each number of a formula (marked "tune" in data/tuning/*.json, listed in
// src/game/gen_tune.odin) has a slider and a box to type into, and acts in
// the running game at once: in the workbench's build those numbers are
// variables, and the pane sets them where they are. Nothing is written until
// Save, which writes every changed one into its file (only the number
// changes; the file then rebuilds, as any saved file does); Reset puts them
// back as the files have them. Changed but unsaved, a number is marked.
// Before each Save the files as they were are backed up, every one, into
// tuning_backups/tuning_DDMMYY_HHMMSS/ (commands/tuning.odin); "Load
// parameters" lists those sets, newest first, and puts one into the running
// game to try, unsaved.
// Pointing at one shows its "about" at the foot of the pane.
//
// The Attacks pane (the only one so far; more, such as mixing and cooking,
// the body and the day's budget, or the animals, go in Pane) has Prosio's
// weight, muscle and jump, things to hand (pebbles, spears, a stone or rock
// of any weight), a stand of any height (the workbench's own: the game has
// none), a target animal at any distance (standing still or as usual,
// mending or not, made whole again), every blow that lands in numbers, and
// the blows table (tools/check.sh blows) for him as he is set.

import cmd "commands"
import game "../game"
import "core:fmt"
import "core:math"
import "core:os"
import "core:path/filepath"
import "core:strconv"
import "core:strings"
import rl "vendor:raylib"

Pane :: enum {
	None,
	Attacks,
	Mixing,
}

PANE_W :: 580
PANE_LINE :: 22 // a row, in points
PANE_ABOUT_LINES :: 7 // the foot, where what is pointed at is said
LABEL_COLS :: 22 // the width of a number's name, in characters
BOX_W :: 96 // the box a number is typed into

AMBER :: rl.Color{250, 210, 90, 255}
CHANGED :: rl.Color{255, 150, 80, 255}
PANE_BACK :: rl.Color{22, 24, 30, 240}

Pane_State :: struct {
	open:         Pane,
	last:         Pane, // the pane last open (Shift+6 opens it again)
	scroll:       f32,
	content_h:    f32,
	rect:         rl.Rectangle,
	// The box being typed into, and a number typed and ready for it.
	loaded:       string, // the backed-up set loaded, while unsaved
	show_sets:    bool, // the list of backed-up sets is open
	typing:       bool,
	typing_id:    string,
	text:         [dynamic]u8,
	typed_ready:  bool,
	typed_id:     string,
	typed:        f32,
	drag_id:      string, // the slider being dragged
	about_name:   string,
	about:        string,
	pinned_name:  string, // a number whose about stays at the foot (its name clicked)
	pinned:       string,
	// The Attacks pane's choices.
	rock_kg:      f32,
	distance:     f32,
	stand_h:      f32,
	kind:         game.Enemy_Kind,
	target:       int, // the animal it put (-1: none)
	press:        bit_set[game.Button], // pressed for him on the next frame
	hold:         bit_set[game.Button], // held for him,
	hold_t:       f32, // for so many more seconds
	said:         string,
}

pane := Pane_State {
	rock_kg  = 2,
	distance = 4,
	stand_h  = 2,
	target   = -1,
}

// ---- The numbers of the formulas. ----

// What the files hold for each, as this library was built (it is rebuilt,
// and so read again, after a save).
tune_default: [dynamic]f32
tune_taken: bool

tune_list :: proc() -> []game.Tunable {
	list := game.tunables()
	if !tune_taken {
		resize(&tune_default, len(list))
		for t, i in list {tune_default[i] = t.value^}
		tune_taken = true
	}
	return list
}

tune_name :: proc(t: game.Tunable) -> string {
	return t.key == "" ? t.name : fmt.tprintf("%s %s", t.name, t.key)
}

tune_changed :: proc(i: int) -> bool {
	list := tune_list()
	return list[i].value^ != tune_default[i]
}

tune_changes :: proc() -> int {
	n := 0
	for _, i in tune_list() {
		if tune_changed(i) {n += 1}
	}
	return n
}

// One set by name: "ENEMY_TOUGH goat" or "ENEMY_TOUGH.goat" or "BLOW_TAKES".
tune_set :: proc(name: string, value: f32) -> bool {
	want := strings.to_upper(strings.trim_space(name), context.temp_allocator)
	want, _ = strings.replace_all(want, ".", " ", context.temp_allocator)
	for t in tune_list() {
		if strings.to_upper(tune_name(t), context.temp_allocator) == want {
			t.value^ = value
			return true
		}
	}
	return false
}

tune_reset :: proc() -> string {
	n := tune_changes()
	for t, i in tune_list() {t.value^ = tune_default[i]}
	delete(pane.loaded)
	pane.loaded = ""
	return fmt.tprintf("%d numbers back as the files have them", n)
}

// Every changed number written into its file; the files then rebuild.
tune_save :: proc() -> string {
	list := tune_list()
	files: [dynamic]string
	files.allocator = context.temp_allocator
	for t, i in list {
		if tune_changed(i) && !slice_has(files[:], t.file) {append(&files, t.file)}
	}
	if len(files) == 0 {
		return "nothing changed to save"
	}
	// First, the files as they were last saved, every one, backed up.
	backup, backed := cmd.backup_tuning()
	if !backed {
		return fmt.tprintf("nothing saved: the backup failed (%s)", backup)
	}
	saved, failed := 0, ""
	for file in files {
		path := fmt.tprintf("data/tuning/%s.json", file)
		data, err := os.read_entire_file(path, context.temp_allocator)
		if err != nil {
			failed = path
			continue
		}
		text := string(data)
		for t, i in list {
			if t.file != file || !tune_changed(i) {continue}
			out, ok := cmd.json_set_value(text, t.name, t.key, t.value^)
			if !ok {
				failed = fmt.tprintf("%s in %s", tune_name(t), path)
				continue
			}
			text = out
			tune_default[i] = t.value^
			saved += 1
		}
		if os.write_entire_file(path, transmute([]byte)text) != nil {
			failed = path
		}
	}
	if failed != "" {
		return fmt.tprintf("saved %d; could not write %s", saved, failed)
	}
	delete(pane.loaded)
	pane.loaded = ""
	return fmt.tprintf("saved %d numbers into %s (the files before: %s/%s): rebuilding", saved, strings.join(files[:], ", ", context.temp_allocator), cmd.TUNING_BACKUPS, backup)
}

slice_has :: proc(list: []string, s: string) -> bool {
	for x in list {
		if x == s {return true}
	}
	return false
}

// A backed-up set of parameters put into the running game, to try: every
// number a pane can turn takes the value it has there, marked as not saved
// (Save makes it the files', Reset goes back to them). A number the set has
// not got (made before it existed), or wrote as a sum, keeps the file's
// value, and is said; so is anything else in the set that differs from the
// files, which only a number a pane can turn can show while the game runs.
tune_load :: proc(name: string) -> string {
	if _, ok := cmd.tuning_backup_time(name); !ok {
		return fmt.tprintf("no set called %s", name)
	}
	dir := fmt.tprintf("%s/%s", cmd.TUNING_BACKUPS, name)
	if !os.exists(dir) {
		return fmt.tprintf("no set %s", dir)
	}
	changed, missing, sums := 0, 0, 0
	first_missing := ""
	for t, i in tune_list() {
		data, err := os.read_entire_file(fmt.tprintf("%s/%s.json", dir, t.file), context.temp_allocator)
		text, found := cmd.json_get_value(string(data), t.name, t.key)
		v, number := strconv.parse_f32(text)
		switch {
		case err != nil || !found:
			t.value^ = tune_default[i]
			missing += 1
			if first_missing == "" {first_missing = tune_name(t)}
		case !number:
			t.value^ = tune_default[i]
			sums += 1
		case:
			t.value^ = v
			if v != tune_default[i] {changed += 1}
		}
	}
	// Anything else that differs: the set's files with the pane's numbers
	// as the files have them, against the files.
	others: [dynamic]string
	others.allocator = context.temp_allocator
	files, _ := filepath.glob(cmd.TUNING_DIR + "/*.json", context.temp_allocator)
	for f in files {
		now, _ := os.read_entire_file(f, context.temp_allocator)
		then, err := os.read_entire_file(fmt.tprintf("%s/%s", dir, filepath.base(f)), context.temp_allocator)
		if err != nil {continue}
		text := string(then)
		for t in tune_list() {
			if fmt.tprintf("%s.json", t.file) != filepath.base(f) {continue}
			start, stop, in_now := cmd.json_value_span(string(now), t.name, t.key)
			a, b, in_then := cmd.json_value_span(text, t.name, t.key)
			if in_now && in_then {
				text = strings.concatenate({text[:a], string(now)[start:stop], text[b:]}, context.temp_allocator)
			}
		}
		if text != string(now) {append(&others, filepath.base(f))}
	}
	delete(pane.loaded)
	pane.loaded = strings.clone(name)
	b := strings.builder_make(context.temp_allocator)
	fmt.sbprintf(&b, "%s loaded: %d numbers differ from the files (not saved)", name, changed)
	if missing > 0 {fmt.sbprintf(&b, "; %d not in it (made before they were: %s...), kept as the files have them", missing, first_missing)}
	if sums > 0 {fmt.sbprintf(&b, "; %d written there as sums, kept as the files have them", sums)}
	if len(others) > 0 {fmt.sbprintf(&b, "; other values differ in %s, which only a rebuild could show: not loaded", strings.join(others[:], ", ", context.temp_allocator))}
	return strings.to_string(b)
}

// What crosses a swap: the changed numbers (still unsaved), the pane and its
// choices, and the test rig in the game.
panes_text :: proc() -> string {
	b := strings.builder_make(context.temp_allocator)
	for t, i in tune_list() {
		if tune_changed(i) {fmt.sbprintf(&b, "#tune %s %s %v\n", t.name, t.key == "" ? "-" : t.key, t.value^)}
	}
	strings.write_string(&b, mixing_text())
	r := game.bench
	fmt.sbprintf(&b, "#pane %d %v %v %v %v %v %v %v %v %v %v %v %d %d\n", int(pane.open), pane.rock_kg, pane.distance, pane.stand_h, r.no_mend, r.jump, r.stand, r.stand_at.x, r.stand_at.y, r.stand_r, r.stand_h, pane.scroll, int(pane.kind), r.still)
	return strings.to_string(b)
}

take_panes_text :: proc(text: string) {
	for line in strings.split_lines(text, context.temp_allocator) {
		w := strings.fields(line, context.temp_allocator)
		if len(w) > 0 && w[0] == "#mix" {
			take_mixing_text(line)
			continue
		}
		if len(w) == 4 && w[0] == "#tune" {
			v, _ := strconv.parse_f32(w[3])
			tune_set(w[2] == "-" ? w[1] : fmt.tprintf("%s %s", w[1], w[2]), v)
		} else if len(w) == 15 && w[0] == "#pane" {
			f :: proc(s: string) -> f32 {v, _ := strconv.parse_f32(s); return v}
			n :: proc(s: string) -> int {v, _ := strconv.parse_int(s); return v}
			pane.open = Pane(clamp(n(w[1]), 0, len(Pane) - 1))
			pane.rock_kg, pane.distance, pane.stand_h = f(w[2]), f(w[3]), f(w[4])
			r := &game.bench
			r.no_mend, r.jump, r.stand = w[5] == "true", f(w[6]), w[7] == "true"
			r.stand_at, r.stand_r, r.stand_h = {f(w[8]), f(w[9])}, f(w[10]), f(w[11])
			pane.scroll = f(w[12])
			pane.kind = game.Enemy_Kind(clamp(n(w[13]), 0, len(game.Enemy_Kind) - 1))
			r.still = n(w[14])
			pane.target = r.still
		}
	}
}

// ---- Keys and the mouse. ----

pane_typing :: proc() -> bool {
	return pane.open != .None && pane.typing
}

pane_over :: proc(m: rl.Vector2) -> bool {
	return pane.open != .None && rl.CheckCollisionPointRec(m, pane.rect)
}

pane_keys :: proc() {
	for {
		c := rl.GetCharPressed()
		if c == 0 {break}
		if (c >= '0' && c <= '9') || c == '.' || c == '-' || c == 'e' {append(&pane.text, u8(c))}
	}
	switch {
	case rl.IsKeyPressed(.ESCAPE):
		pane.typing = false
	case rl.IsKeyPressed(.BACKSPACE) || rl.IsKeyPressedRepeat(.BACKSPACE):
		if len(pane.text) > 0 {pop(&pane.text)}
	case rl.IsKeyPressed(.ENTER) || rl.IsKeyPressed(.KP_ENTER):
		if v, ok := strconv.parse_f32(string(pane.text[:])); ok {
			pane.typed_ready, pane.typed_id, pane.typed = true, pane.typing_id, v
		}
		pane.typing = false
	}
}

// Before the game moves on: a button pressed for him.
pane_before_update :: proc() {
	game.forced_pressed += pane.press
	if pane.hold_t > 0 {game.forced_down += pane.hold}
}

pane_after_update :: proc() {
	game.forced_pressed -= pane.press
	pane.press = {}
	game.forced_down -= pane.hold
	pane.hold_t -= rl.GetFrameTime()
	if pane.hold_t <= 0 {pane.hold = {}}
}

// ---- Drawing, a row at a time. ----

Row :: struct {
	x, y, w: f32,
	m:       rl.Vector2,
	click:   bool,
	down:    bool,
	clip:    rl.Rectangle, // what of the pane shows (rows outside take no clicks)
}

row: Row

// Whether the row being drawn is in sight (rows out of it are only counted).
row_shown :: proc() -> bool {
	return row.y + PANE_LINE + 4 >= row.clip.y && row.y <= row.clip.y + row.clip.height
}

row_live :: proc(r: rl.Rectangle) -> bool {
	return rl.CheckCollisionPointRec(row.m, r) && rl.CheckCollisionPointRec(row.m, row.clip)
}

text_at :: proc(s: string, x, y: f32, color: rl.Color, cols := 1 << 30) {
	draw_mono(s, x, y + 2, color, cols)
}

pane_text :: proc(s: string, color := INK) {
	if !row_shown() {
		row.y += PANE_LINE
		return
	}
	text_at(s, row.x + 10, row.y, color, int((row.w - 20) / editor.cell))
	row.y += PANE_LINE
}

pane_heading :: proc(s: string) {
	row.y += 6
	rl.DrawRectangleRec({row.x + 8, row.y, row.w - 16, 1}, DIM)
	row.y += 4
	text_at(s, row.x + 10, row.y, AMBER)
	row.y += PANE_LINE
}

// A row of buttons; the one clicked, or -1. `lit` shows which are on.
pane_buttons :: proc(labels: []string, lit: []bool = nil, about := "") -> int {
	x := row.x + 10
	clicked := -1
	for label, i in labels {
		w := f32(len(label)) * editor.cell + 16
		if x + w > row.x + row.w - 8 {
			x = row.x + 10
			row.y += PANE_LINE + 4
		}
		r := rl.Rectangle{x, row.y, w, PANE_LINE}
		over := row_live(r)
		on := lit != nil && i < len(lit) && lit[i]
		rl.DrawRectangleRec(r, on ? rl.Color{90, 76, 34, 255} : over ? rl.Color{60, 64, 76, 255} : rl.Color{38, 41, 50, 255})
		rl.DrawRectangleLinesEx(r, 1, on ? AMBER : DIM)
		text_at(label, x + 8, row.y, on ? AMBER : INK)
		if over && about != "" {pane.about_name, pane.about = labels[i], about}
		if over && row.click {clicked = i}
		x += w + 6
	}
	row.y += PANE_LINE + 4
	return clicked
}

// A number with a slider and a box. True when it was changed (dragged, or a
// number typed into its box and Enter pressed).
pane_number :: proc(id, label: string, value: ^f32, lo, hi: f32, changed := false, about := "", unit := "") -> bool {
	moved := false
	if pane.typed_ready && pane.typed_id == id {
		value^ = pane.typed
		pane.typed_ready = false
		moved = true
	}
	if !row_shown() {
		row.y += PANE_LINE + 2
		return moved
	}
	y := row.y
	whole := rl.Rectangle{row.x + 4, y, row.w - 8, PANE_LINE}
	if row_live(whole) {
		rl.DrawRectangleRec(whole, {34, 37, 46, 255})
		if about != "" {pane.about_name, pane.about = label, about}
		if about != "" && row.click && row.m.x < row.x + 16 + f32(LABEL_COLS + 2) * editor.cell {
			delete(pane.pinned_name)
			delete(pane.pinned)
			pane.pinned_name, pane.pinned = strings.clone(label), strings.clone(about)
		}
	}
	name := changed ? fmt.tprintf("• %s", label) : fmt.tprintf("  %s", label)
	text_at(name, row.x + 6, y, changed ? CHANGED : INK, LABEL_COLS + 2)
	// The slider, over a span that takes in the value whatever it is.
	a, b := min(lo, value^), max(hi, value^)
	x0 := row.x + 16 + f32(LABEL_COLS + 2) * editor.cell
	x1 := row.x + row.w - BOX_W - 18
	track := rl.Rectangle{x0, y + PANE_LINE / 2 - 2, x1 - x0, 4}
	rl.DrawRectangleRec(track, {70, 74, 86, 255})
	share := b > a ? (value^ - a) / (b - a) : 0
	knob := rl.Rectangle{x0 + share * (x1 - x0) - 4, y + 3, 8, PANE_LINE - 6}
	hit := rl.Rectangle{x0 - 6, y, x1 - x0 + 12, PANE_LINE}
	if row_live(hit) && row.click {
		pane.drag_id = id
	}
	if pane.drag_id == id {
		if row.down {
			v := a + clamp((row.m.x - x0) / (x1 - x0), 0, 1) * (b - a)
			if v != value^ {
				value^ = nice(v, b - a)
				moved = true
			}
		} else {
			pane.drag_id = ""
		}
	}
	rl.DrawRectangleRec(knob, pane.drag_id == id ? AMBER : changed ? CHANGED : INK)
	// The box.
	box := rl.Rectangle{row.x + row.w - BOX_W - 8, y + 1, BOX_W, PANE_LINE - 2}
	editing := pane.typing && pane.typing_id == id
	rl.DrawRectangleRec(box, editing ? rl.Color{60, 54, 30, 255} : rl.Color{30, 32, 40, 255})
	rl.DrawRectangleLinesEx(box, 1, editing ? AMBER : DIM)
	shown := editing ? fmt.tprintf("%s_", string(pane.text[:])) : fmt.tprintf("%s%s", short_number(value^), unit)
	text_at(shown, box.x + 5, y, editing ? AMBER : TYPE, int((BOX_W - 8) / editor.cell))
	if row_live(box) && row.click {
		pane.typing, pane.typing_id = true, id
		clear(&pane.text)
		append(&pane.text, cmd.number_text(value^))
	}
	row.y += PANE_LINE + 2
	return moved
}

// A number as a box shows it: four figures that mean something.
short_number :: proc(v: f32) -> string {
	r, _ := strconv.parse_f64(fmt.tprintf("%.4g", v))
	return cmd.number_text(f32(r))
}

// A dragged number, rounded to what the slider can tell apart.
nice :: proc(v, span: f32) -> f32 {
	if span <= 0 {return v}
	step := math.pow(10, math.floor(math.log10(span)) - 2)
	return math.round(v / step) * step
}

// Wrapped to so many characters a line.
wrap :: proc(text: string, cols: int) -> []string {
	out: [dynamic]string
	out.allocator = context.temp_allocator
	line := strings.builder_make(context.temp_allocator)
	for word in strings.fields(text, context.temp_allocator) {
		if strings.builder_len(line) > 0 && strings.builder_len(line) + 1 + len(word) > cols {
			append(&out, strings.clone(strings.to_string(line), context.temp_allocator))
			strings.builder_reset(&line)
		}
		if strings.builder_len(line) > 0 {strings.write_byte(&line, ' ')}
		strings.write_string(&line, word)
	}
	if strings.builder_len(line) > 0 {append(&out, strings.to_string(line))}
	return out[:]
}

draw_pane :: proc() {
	if pane.open == .None {return}
	pane.last = pane.open
	w := f32(rl.GetScreenWidth())
	h := f32(rl.GetScreenHeight())
	x := editor.visible ? w / 2 - PANE_W - 8 : w - PANE_W - 8
	y := f32(36)
	ph := h - y - 44
	pane.rect = {x, y, PANE_W, ph}
	rl.DrawRectangleRec(pane.rect, PANE_BACK)
	rl.DrawRectangleLinesEx(pane.rect, 1, AMBER)
	m := rl.GetMousePosition()
	over := rl.CheckCollisionPointRec(m, pane.rect)
	if over {
		if wheel := rl.GetMouseWheelMove(); wheel != 0 {pane.scroll -= wheel * 40}
	}
	foot := f32(PANE_ABOUT_LINES) * (PANE_LINE - 4) + 14
	head := f32(PANE_LINE) * 4 + 16
	body := rl.Rectangle{x, y + head, PANE_W, ph - head - foot}
	pane.scroll = clamp(pane.scroll, 0, max(pane.content_h - body.height, 0))
	pane.about_name, pane.about = "", ""
	row = {x = x, y = y + 6, w = PANE_W, m = m, click = rl.IsMouseButtonPressed(.LEFT) && !menu.open, down = rl.IsMouseButtonDown(.LEFT), clip = pane.rect}
	if row.click && pane.typing {
		pane.typing = false // a click elsewhere leaves the box
	}

	// The head: which pane, and the numbers changed.
	n := tune_changes()
	title := fmt.tprintf("%v", pane.open)
	text_at(strings.to_upper(title, context.temp_allocator), x + 10, row.y, AMBER)
	text_at(n > 0 ? fmt.tprintf("%d changed, not saved", n) : "as the files have them", x + 10 + f32(len(title) + 2) * editor.cell, row.y, n > 0 ? CHANGED : DIM)
	row.y += PANE_LINE + 2
	switch pane_buttons({"Save", "Reset", "Load parameters", "Close"}, {false, false, pane.show_sets, false}, "Save: write the changed numbers into their files (they rebuild), after backing up the files as they were. Reset: back to what the files have. Load parameters: a backed-up set, to try. Close: the pane (Shift+6 opens it again)") {
	case 0: say(tune_save())
	case 1: say(tune_reset())
	case 2: pane.show_sets = !pane.show_sets
	case 3: pane.open = .None
	}
	switch pane_buttons({"Attacks", "Mixing and cooking"}, {pane.open == .Attacks, pane.open == .Mixing}, "the panes: one for each mechanic") {
	case 0: pane.open = .Attacks
	case 1: pane.open = .Mixing
	}
	if pane.loaded != "" {
		text_at(fmt.tprintf("trying %s: not saved", pane.loaded), x + 10, row.y, CHANGED)
	}
	row.y += PANE_LINE

	// The body, scrolled.
	row.clip = body
	rl.BeginScissorMode(i32(body.x), i32(body.y), i32(body.width), i32(body.height))
	row.y = body.y + 4 - pane.scroll
	top := row.y
	if pane.show_sets {
		draw_sets()
	}
	switch pane.open {
	case .None:
	case .Attacks: draw_attacks()
	case .Mixing: draw_mixing()
	}
	pane.content_h = row.y - top + 8
	rl.EndScissorMode()
	row.clip = pane.rect

	// The foot: what is pointed at.
	fy := y + ph - foot
	rl.DrawRectangleRec({x + 1, fy, PANE_W - 2, foot - 1}, {16, 17, 22, 255})
	rl.DrawRectangleRec({x + 8, fy, PANE_W - 16, 1}, DIM)
	if pane.about == "" && pane.pinned != "" {
		pane.about_name, pane.about = pane.pinned_name, pane.pinned
	}
	if pane.about != "" {
		cols := int((PANE_W - 20) / editor.cell)
		lines := wrap(fmt.tprintf("%s: %s", pane.about_name, pane.about), cols)
		for l, i in lines[:min(len(lines), PANE_ABOUT_LINES)] {
			text_at(l, x + 10, fy + 6 + f32(i) * (PANE_LINE - 4), i == 0 ? AMBER : INK, cols)
		}
	} else {
		text_at("point at a number to see what it is (click its name to keep it here)", x + 10, fy + 6, DIM)
	}
}

// The backed-up sets of parameters, newest first: a click loads one.
draw_sets :: proc() {
	pane_heading("Saved parameter sets (tuning_backups), newest first")
	sets := cmd.list_tuning_backups()
	if len(sets) == 0 {
		pane_text("none yet: Save backs up the files before it writes", DIM)
	}
	for name in sets {
		c, _ := cmd.tuning_backup_time(name)
		label := fmt.tprintf("%02d/%02d/%04d %02d:%02d:%02d", c.day, c.month, c.year, c.hour, c.minute, c.second)
		if pane_buttons({label}, {name == pane.loaded}, "the parameters as they were saved then: a click puts them into the running game, to try (not saved: Save makes them the files', Reset goes back)") == 0 {
			say(tune_load(name))
			pane.show_sets = false
		}
	}
}

// ---- The Attacks pane. ----

KIND_NAMES := [game.Enemy_Kind]string{.Turkey = "Turkey", .Goat = "Goat", .Billy = "Billy goat", .Fox = "Fox"}

draw_attacks :: proc() {
	g := &game.g
	p := &g.prosio

	pane_heading("Prosio")
	kg := p.kg
	if pane_number("kg", "weight", &kg, 30, 200, false, "his weight in kg, his fat making up the difference (as the menu's kg)", " kg") {
		game.set_weight(max(kg, 20))
	}
	arms := p.trait[.Arms]
	if pane_number("arms", "arm muscle", &arms, -1, 1, false, "his arm muscle, -1 (wasted away) to 1 (the strongest); 0 is the pig he starts as. It sets how heavy a rock he can lift and how hard he throws") {
		p.trait[.Arms] = clamp(arms, -1, 1)
		game.set_weight(p.kg)
	}
	legs := p.trait[.Legs]
	if pane_number("legs", "leg muscle", &legs, -1, 1, false, "his leg muscle, -1 to 1: it sets how high he jumps") {
		p.trait[.Legs] = clamp(legs, -1, 1)
		game.set_weight(p.kg)
	}
	made := game.jump_height(game.total_kg())
	jump := game.jump_set(made)
	if pane_number("jump", game.bench.jump > 0 ? "jump (set by hand)" : "jump", &jump, 0, 3, game.bench.jump > 0, "how high he jumps, in metres: as his legs and weight make it, or set here by hand (then \"as his legs make it\" puts it back)", " m") {
		game.bench.jump = max(jump, 0.01)
	}
	if game.bench.jump > 0 {
		if pane_buttons({"as his legs make it"}) == 0 {game.bench.jump = 0}
	}
	pane_text(fmt.tprintf("arm muscle %.1f kg, legs %.1f kg; his legs make a %.2f m jump", game.muscle_kg(.Arms), game.muscle_kg(.Legs), made), DIM)
	pane_text(fmt.tprintf("lifts up to %.0f kg; a stone leaves at %.1f m/s, a %.0f kg rock at %.1f", game.lift_most(), game.stone_speed(2), pane.rock_kg, game.stone_speed(pane.rock_kg)), DIM)
	pane_text(fmt.tprintf("a stomp from the top of his jump, where he stands: %.0f J, pins %.1f s", game.stomp_energy(jump + game.floor_at(p.pos)), game.stomp_pin(jump)), DIM)

	pane_heading("To hand")
	switch pane_buttons({"5 pebbles", "3 spears", "a 2 kg stone", "the heaviest rock he lifts"}, nil, "pebbles and spears into his sack (choose them with Z and C, throw with F); the stone and rock buttons set the weight below") {
	case 0: say(run_line("sack pebble 5"))
	case 1: say(run_line("sack spear 3"))
	case 2: pane.rock_kg = 2
	case 3: pane.rock_kg = math.floor(game.lift_most())
	}
	pane_number("rock", "stone or rock", &pane.rock_kg, 0.5, 120, false, "the weight of the stone or rock the buttons below put down, in kg", " kg")
	switch pane_buttons({"put it in front", "in his hooves", "drop it on the target"}, nil, "a stone or rock of that weight: in front of him, picked up for him (F throws it), or let fall on the target from the stand's height (or from as high as he holds a rock)") {
	case 0: say(put_rock(false))
	case 1: say(put_rock(true))
	case 2: say(drop_rock())
	}

	pane_heading("Height")
	if pane_number("stand", "stand height", &pane.stand_h, 0.2, 8, false, "the stand: the workbench's own (the game has none), to stomp from or throw and drop from. Walking off it he falls; walking onto it puts him on it", " m") && game.bench.stand {
		game.bench.stand_h = pane.stand_h
		p.height = max(p.height, pane.stand_h)
	}
	lit := []bool{game.bench.stand, false}
	switch pane_buttons({"a stand under him", "take it away"}, lit) {
	case 0:
		game.bench.stand, game.bench.stand_at, game.bench.stand_r, game.bench.stand_h = true, p.pos, 0.9, pane.stand_h
		p.height, p.vy, p.airborne = pane.stand_h, 0, false
	case 1:
		game.bench.stand = false
	}

	pane_heading("Target")
	kinds := []string{KIND_NAMES[.Turkey], KIND_NAMES[.Goat], KIND_NAMES[.Billy], KIND_NAMES[.Fox]}
	kind_lit := []bool{pane.kind == .Turkey, pane.kind == .Goat, pane.kind == .Billy, pane.kind == .Fox}
	if k := pane_buttons(kinds, kind_lit); k >= 0 {pane.kind = game.Enemy_Kind(k)}
	pane_number("distance", "distance", &pane.distance, 0, 20, false, "how far in front of him the target is put, in metres (0: right under him, for a stomp from the stand)", " m")
	still := game.bench.still >= 0 && game.bench.still == pane.target
	switch pane_buttons({"put it there", "whole again", still ? "standing still" : "as usual", game.bench.no_mend ? "not mending" : "mending", "clear the others"}, {false, false, still, false, false}, "put: a new one of that kind, there; whole again: its health back, up again if it was dead; standing still or doing as it would; mending or not; clear the others: every other animal gone") {
	case 0: say(put_target())
	case 1: say(target_whole())
	case 2:
		game.bench.still = still ? -1 : pane.target
	case 3: game.bench.no_mend = !game.bench.no_mend
	case 4: say(clear_others())
	}
	if e := target(); e != nil {
		rate := e.state == .Chase && !e.ko && game.mends() ? game.mend_rate(e^) : 0
		pane_text(fmt.tprintf("%s %d: health %.1f of %.0f, mending %.2f a second (hurt %.1f s ago), %v%s", KIND_NAMES[e.kind], pane.target, e.health, game.ENEMY_HEALTH, rate, e.hurt_t, e.state, e.ko ? ", knocked out" : ""), TYPE)
		pane_text(fmt.tprintf("%.1f m from him", game.length2(e.pos - p.pos)), DIM)
	} else {
		pane_text("no target: put one", DIM)
	}

	pane_heading("Blows that landed")
	shown := 0
	for b in game.bench_blows[:min(game.bench_blow_count, len(game.bench_blows))] {
		factor := game.BLOW_FACTOR[b.how] * (b.how == .Sharp ? game.ENEMY_HIDE[b.kind] : 1)
		pane_text(fmt.tprintf("%.0fs %v on %s %d: %.1f kg at %.1f m/s", b.time, b.how, KIND_NAMES[b.kind], b.enemy, b.kg, b.speed), INK)
		pane_text(fmt.tprintf("   %.0f J, momentum %.0f kg m/s, factor %.2f: took %.1f, left %.1f", b.joules, b.kg * b.speed, factor, b.harm, b.health), TYPE)
		shown += 1
	}
	if shown == 0 {pane_text("none yet", DIM)}

	pane_heading(fmt.tprintf("Blows table: %.0f kg, arm muscle %.1f kg, legs %.1f kg, jump %.2f m", p.kg, game.muscle_kg(.Arms), game.muscle_kg(.Legs), jump))
	cell_w := f32(14) * editor.cell
	text_at("% taken, blows", row.x + 10, row.y, DIM)
	for kind, i in game.Enemy_Kind {
		text_at(KIND_NAMES[kind], row.x + 10 + 15 * editor.cell + f32(i) * cell_w, row.y, DIM)
	}
	row.y += PANE_LINE
	for blow in game.Test_Blow {
		name := fmt.tprintf("%v", blow)
		#partial switch blow {
		case .Stone: name = "Stone 2 kg"
		case .Rock: name = fmt.tprintf("Rock %.0f kg", game.lift_most())
		}
		text_at(name, row.x + 10, row.y, INK)
		for kind, i in game.Enemy_Kind {
			harm := game.test_blow(blow, kind)
			n := game.blows_needed(harm)
			text_at(fmt.tprintf("%5.1f %s", harm, n > 0 ? fmt.tprintf("%d", n) : "-"), row.x + 10 + 15 * editor.cell + f32(i) * cell_w, row.y, TYPE)
		}
		row.y += PANE_LINE
	}

	draw_formulas("attacks")
}

// Every number marked for this pane, by file, each with its slider and box.
draw_formulas :: proc(which: string) {
	pane_heading("Formulas")
	file := ""
	for t, i in tune_list() {
		if !slice_has(strings.fields(t.panes, context.temp_allocator), which) {continue}
		if t.file != file {
			file = t.file
			text_at(fmt.tprintf("%s.json", file), row.x + 10, row.y, DIM)
			row.y += PANE_LINE
		}
		d := tune_default[i]
		lo, hi := t.range.x, t.range.y
		if !t.has_range {
			lo, hi = d >= 0 ? 0 : 3 * d, d > 0 ? 3 * d : d < 0 ? 0 : 1
		}
		pane_number(tune_name(t), tune_name(t), t.value, lo, hi, tune_changed(i), fmt.tprintf("%s (in %s.json: %s)", t.about, t.file, cmd.number_text(d)))
	}
}

// The target, if it is still there.
target :: proc() -> ^game.Enemy {
	g := &game.g
	if pane.target < 0 || pane.target >= g.enemy_count || g.enemies[pane.target].state == .Gone {
		return nil
	}
	return &g.enemies[pane.target]
}

put_target :: proc() -> string {
	g := &game.g
	if g.enemy_count >= game.MAX_ENEMIES {
		return "no room for another animal: clear the others"
	}
	p := &g.prosio
	at := p.pos + game.facing_dir(p.facing) * pane.distance
	game.add_enemy(pane.kind, at)
	was_still := target() != nil && game.bench.still == pane.target
	pane.target = g.enemy_count - 1
	e := &g.enemies[pane.target]
	e.facing = math.atan2(p.pos.x - at.x, p.pos.y - at.y)
	if was_still || game.bench.still >= 0 {game.bench.still = pane.target}
	return fmt.tprintf("a %s, %.1f m in front of him", KIND_NAMES[pane.kind], pane.distance)
}

target_whole :: proc() -> string {
	e := target()
	if e == nil {return "no target"}
	e.health, e.ko, e.hurt_t = game.ENEMY_HEALTH, false, 0
	if e.state == .Dead || e.state == .Dizzy || e.state == .Flying {
		e.state, e.y, e.vy, e.timer, e.body_t, e.cut, e.chop_t = .Chase, 0, 0, 0, 0, 0, 0
		e.impact = {}
	}
	return fmt.tprintf("%s %d whole again", KIND_NAMES[e.kind], pane.target)
}

clear_others :: proc() -> string {
	g := &game.g
	e := target()
	if e == nil {
		cmd.run("clear animals")
		return "no animals"
	}
	keep := e^
	g.enemies[0] = keep
	g.enemy_count = 1
	pane.target = 0
	if game.bench.still >= 0 {game.bench.still = 0}
	return "only the target left"
}

// A stone or a rock of the chosen weight, in front of him (and picked up for
// him: the Grab button pressed on the next frame).
put_rock :: proc(hooves: bool) -> string {
	g := &game.g
	p := &g.prosio
	if p.carry != .Nothing {return "his hooves are full"}
	r := math.cbrt(pane.rock_kg / game.ROCK_DENSITY)
	at := p.pos + game.facing_dir(p.facing) * (game.prosio_radius(p.kg) + r + 0.1)
	if game.add_round(at, r, .Rock) < 0 {
		return "no room for another rock"
	}
	if hooves {
		pane.press += {.Grab}
		if pane.rock_kg > game.lift_most() {
			return fmt.tprintf("a %.1f kg rock: more than he can lift (%.0f kg)", pane.rock_kg, game.lift_most())
		}
	}
	return fmt.tprintf("a %.1f kg %s, radius %.2f m", pane.rock_kg, pane.rock_kg < game.LIGHT_STONE * 2 ? "stone" : "rock", r)
}

// The chosen stone or rock let fall on the target from the stand (or from as
// high as he would hold it).
drop_rock :: proc() -> string {
	g := &game.g
	e := target()
	if e == nil {return "no target"}
	height := (game.bench.stand ? game.bench.stand_h : 0) + 1.1 * game.PROSIO_SIZE
	for &t in g.thrown {
		if t.active {continue}
		t = {active = true, round = -1, r = math.cbrt(pane.rock_kg / game.ROCK_DENSITY), kg = pane.rock_kg, pos = e.pos, y = height}
		return fmt.tprintf("a %.1f kg rock let fall from %.2f m", pane.rock_kg, height)
	}
	return "too many things in the air"
}

// The test rig drawn in the world: the stand.
draw_rig :: proc() {
	r := game.bench
	if !r.stand {return}
	rl.BeginMode3D(view_camera())
	defer rl.EndMode3D()
	c := rl.Vector3{r.stand_at.x, r.stand_h / 2, r.stand_at.y}
	rl.DrawCubeWires(c, r.stand_r * 2, r.stand_h, r.stand_r * 2, AMBER)
	rl.DrawCubeWires(c, r.stand_r * 2 - 0.05, r.stand_h - 0.05, r.stand_r * 2 - 0.05, {250, 210, 90, 120})
}

// ---- From the menu, or from outside. ----

pane_command :: proc(line: string) -> string {
	words := strings.fields(line, context.temp_allocator)
	lower := strings.fields(strings.to_lower(line, context.temp_allocator), context.temp_allocator)
	switch lower[0] {
	case "pane":
		which := len(lower) > 1 ? lower[1] : ""
		switch which {
		case "attacks": pane.open = .Attacks
		case "mixing", "cooking": pane.open = .Mixing
		case "off", "none": pane.open = .None
		case "sets":
			pane.show_sets = !pane.show_sets
			return pane.show_sets ? "the saved parameter sets shown" : "the saved parameter sets hidden"
		case "point":
			want := strings.to_upper(strings.join(words[2:], " ", context.temp_allocator), context.temp_allocator)
			for t, i in tune_list() {
				if strings.to_upper(tune_name(t), context.temp_allocator) == want {
					pane.pinned_name, pane.pinned = strings.clone(tune_name(t)), strings.clone(fmt.tprintf("%s (in %s.json: %s)", t.about, t.file, cmd.number_text(tune_default[i])))
					return fmt.tprintf("%s shown at the foot", tune_name(t))
				}
			}
			return "no such number"
		case "scroll":
			pane.scroll = len(lower) > 2 ? cmd.f32_of(lower, 2, 0) : 0
			return fmt.tprintf("scrolled to %.0f of %.0f", pane.scroll, pane.content_h)
		case "": pane.open = pane.open == .None ? (pane.last != .None ? pane.last : .Attacks) : .None
		case: return "pane attacks | mixing | off"
		}
		return pane.open == .None ? "no pane" : fmt.tprintf("the %v pane", pane.open)
	case "mixing":
		return mixing_command(lower, line)
	case "tune":
		if len(words) < 3 {return "tune NAME [ENTRY] VALUE"}
		v, ok := strconv.parse_f32(words[len(words) - 1])
		if !ok {return "tune NAME [ENTRY] VALUE: the value is a number"}
		name := strings.join(words[1:len(words) - 1], " ", context.temp_allocator)
		if !tune_set(name, v) {return fmt.tprintf("no number %s to tune", name)}
		return fmt.tprintf("%s = %v (unsaved)", name, v)
	case "tune-save":
		return tune_save()
	case "tune-reset":
		return tune_reset()
	case "tune-sets":
		sets := cmd.list_tuning_backups()
		return len(sets) > 0 ? strings.join(sets, ", ", context.temp_allocator) : "no saved sets yet"
	case "tune-load":
		sets := cmd.list_tuning_backups()
		which := len(words) > 1 ? words[1] : "1"
		if n, ok := strconv.parse_int(which); ok && n >= 1 && n <= len(sets) {which = sets[n - 1]}
		return tune_load(which)
	case "tune-list":
		b := strings.builder_make(context.temp_allocator)
		for t, i in tune_list() {
			if tune_changed(i) {fmt.sbprintf(&b, "%s %v (file %v); ", tune_name(t), t.value^, tune_default[i])}
		}
		return strings.builder_len(b) > 0 ? strings.to_string(b) : "nothing changed"
	case "bench":
		if len(lower) < 2 {return "bench jump|stand|target|still|mend|whole|rock|hooves|drop|table|blows ..."}
		num := len(lower) > 2 ? cmd.f32_of(lower, 2, 0) : 0
		switch lower[1] {
		case "jump":
			game.bench.jump = num
			return fmt.tprintf("jump %.2f m", game.jump_set(game.jump_height(game.total_kg())))
		case "stand":
			if len(lower) > 2 && lower[2] == "off" {
				game.bench.stand = false
				return "no stand"
			}
			if num > 0 {pane.stand_h = num}
			p := &game.g.prosio
			game.bench.stand, game.bench.stand_at, game.bench.stand_r, game.bench.stand_h = true, p.pos, 0.9, pane.stand_h
			p.height, p.vy, p.airborne = pane.stand_h, 0, false
			return fmt.tprintf("on a stand %.2f m high", pane.stand_h)
		case "target":
			if len(lower) > 2 {
				if k, ok := cmd.enum_named(game.Enemy_Kind, lower[2]); ok {pane.kind = k}
			}
			if len(lower) > 3 {pane.distance = cmd.f32_of(lower, 3, pane.distance)}
			return put_target()
		case "still":
			game.bench.still = len(lower) > 2 && lower[2] == "off" ? -1 : pane.target
			return game.bench.still >= 0 ? "the target stands still" : "the target as usual"
		case "mend":
			game.bench.no_mend = len(lower) > 2 && lower[2] == "off"
			return game.bench.no_mend ? "no mending" : "mending"
		case "hold":
			if len(words) > 2 {
				if b, ok := cmd.enum_named(game.Button, lower[2]); ok {
					pane.hold, pane.hold_t = {b}, len(lower) > 3 ? cmd.f32_of(lower, 3, 1) : 1
					pane.press += {b}
					return fmt.tprintf("%v held for him %.2f s", b, pane.hold_t)
				}
			}
			return "bench hold grab SECONDS"
		case "press":
			if len(words) > 2 {
				if b, ok := cmd.enum_named(game.Button, lower[2]); ok {
					pane.press += {b}
					return fmt.tprintf("%v pressed for him", b)
				}
			}
			return "bench press jump | grab | action | ..."
		case "whole":
			return target_whole()
		case "clear":
			return clear_others()
		case "rock", "hooves", "drop":
			if num > 0 {pane.rock_kg = num}
			return lower[1] == "drop" ? drop_rock() : put_rock(lower[1] == "hooves")
		case "table":
			b := strings.builder_make(context.temp_allocator)
			p := &game.g.prosio
			fmt.sbprintf(&b, "%.0f kg, arms %.2f, legs %.2f, jump %.2f m:", p.kg, p.trait[.Arms], p.trait[.Legs], game.jump_set(game.jump_height(game.total_kg())))
			for blow in game.Test_Blow {
				fmt.sbprintf(&b, " | %v", blow)
				for kind in game.Enemy_Kind {
					h := game.test_blow(blow, kind)
					fmt.sbprintf(&b, " %v %.1f (%d)", kind, h, game.blows_needed(h))
				}
			}
			return strings.to_string(b)
		case "blows":
			b := strings.builder_make(context.temp_allocator)
			for x in game.bench_blows[:min(game.bench_blow_count, len(game.bench_blows))] {
				fmt.sbprintf(&b, "%v on %v %d: %.1f kg at %.2f m/s, %.0f J, took %.2f, left %.1f; ", x.how, x.kind, x.enemy, x.kg, x.speed, x.joules, x.harm, x.health)
			}
			if e := target(); e != nil {
				fmt.sbprintf(&b, "target health %.1f, mending %.2f/s", e.health, e.state == .Chase && !e.ko && game.mends() ? game.mend_rate(e^) : 0)
			}
			return strings.builder_len(b) > 0 ? strings.to_string(b) : "no blows yet"
		}
	}
	return "?"
}
