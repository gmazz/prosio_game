package workbench

// Selecting and inspecting: a click on the game picks the thing nearest the
// mouse on the screen (clicking again in the same place cycles through what
// is there), and a panel shows every number of it, live, with what moves,
// draws, tunes and makes it (the index, commands/index.odin). A click on an
// entry opens the editor at that procedure or file (a model is shown in the
// file browser instead).

import cmd "commands"
import game "../game"
import "base:runtime"
import "core:fmt"
import "core:os"
import "core:reflect"
import "core:strconv"
import "core:strings"
import rl "vendor:raylib"

PICK_RADIUS :: 40 // points on the screen
INSPECT_TEXT :: 16
INSPECT_W :: 470

Selection :: struct {
	active: bool,
	thing:  cmd.Thing,
	index:  int,
	scroll: int,
	at:     rl.Vector2, // where the last click was (to cycle)
	cycle:  int,
}

selection: Selection
inspector_rect: rl.Rectangle

Candidate :: struct {
	thing: cmd.Thing,
	index: int,
	pos:   rl.Vector3,
}

// Everything that can be selected, where it is.
candidates :: proc() -> []Candidate {
	g := &game.g
	out: [dynamic]Candidate
	out.allocator = context.temp_allocator
	p := g.prosio
	append(&out, Candidate{cmd.Other.Prosio, 0, {p.pos.x, p.height + 1, p.pos.y}})
	for e, i in g.enemies[:g.enemy_count] {
		if e.state != .Gone {append(&out, Candidate{e.kind, i, {e.pos.x, e.y + 0.5, e.pos.y}})}
	}
	for r, i in g.rounds[:g.round_count] {append(&out, Candidate{r.kind, i, {r.pos.x, 0.5, r.pos.y}})}
	for f, i in g.foods[:g.food_count] {
		if !f.gone {append(&out, Candidate{f.kind, i, {f.pos.x, f.y + 0.2, f.pos.y}})}
	}
	for f, i in g.fields[:g.field_count] {
		c := (f.lo + f.hi) / 2
		append(&out, Candidate{cmd.Other.Field, i, {c.x, 0, c.y}})
	}
	for f, i in g.fish {append(&out, Candidate{cmd.Other.Fish, i, {f.pos.x, 0, f.pos.y}})}
	for pst, i in g.pests {
		if pst.state != .Away {append(&out, Candidate{pst.kind, i, {pst.pos.x, pst.y + 0.3, pst.pos.y}})}
	}
	for t, i in g.thrown {
		if t.active {append(&out, Candidate{cmd.Other.Thrown_Rock, i, {t.pos.x, t.y, t.pos.y}})}
	}
	return out[:]
}

// The camera as the workbench draws the game (draw_frame's, with the editor's
// shift), for finding things on the screen.
view_camera :: proc() -> rl.Camera3D {
	g := &game.g
	shift: f32 = editor.visible ? EDITOR_CAMERA_SHIFT * g.camera_zoom : 0
	target := rl.Vector3{g.camera.x + shift, 0.8, g.camera.y}
	return {position = target + game.CAMERA_OFFSET * g.camera_zoom, target = target, up = {0, 1, 0}, fovy = CAMERA_FOV, projection = .PERSPECTIVE}
}

// A click in the game: the thing nearest the mouse (the next one, if the
// click is where the last was).
select_at :: proc(m: rl.Vector2) {
	cam := view_camera()
	Near :: struct {
		c: Candidate,
		d: f32,
	}
	near: [dynamic]Near
	near.allocator = context.temp_allocator
	for c in candidates() {
		s := rl.GetWorldToScreen(c.pos, cam)
		if d := rl.Vector2Distance(s, m); d < PICK_RADIUS {append(&near, Near{c, d})}
	}
	if len(near) == 0 {
		selection.active = false
		return
	}
	for i in 1 ..< len(near) {
		for j := i; j > 0 && near[j].d < near[j - 1].d; j -= 1 {near[j], near[j - 1] = near[j - 1], near[j]}
	}
	again := rl.Vector2Distance(m, selection.at) < 6
	selection.cycle = again ? (selection.cycle + 1) % len(near) : 0
	c := near[selection.cycle].c
	selection = {active = true, thing = c.thing, index = c.index, at = m, cycle = selection.cycle}
}

select_thing :: proc(t: cmd.Thing, index: int) {
	selection = {active = true, thing = t, index = index}
}

// The selected thing, as Odin sees it: its record, for its fields.
selected_value :: proc() -> (any, string) {
	g := &game.g
	i := selection.index
	switch k in selection.thing {
	case cmd.Other:
		switch k {
		case .Prosio: return g.prosio, "Prosio"
		case .Field: if i < g.field_count {return g.fields[i], fmt.tprintf("a field (%d)", i)}
		case .Fish: if i < len(g.fish) {return g.fish[i], fmt.tprintf("a fish (%d)", i)}
		case .Fence: return nil, "a piece of fence"
		case .Thrown_Rock: if i < len(g.thrown) {return g.thrown[i], fmt.tprintf("a thrown rock (%d)", i)}
		}
	case game.Enemy_Kind: if i < g.enemy_count {return g.enemies[i], fmt.tprintf("a %v (animal %d)", k, i)}
	case game.Round_Kind: if i < g.round_count {return g.rounds[i], fmt.tprintf("a %v (round thing %d)", k, i)}
	case game.Food_Kind: if i < g.food_count {return g.foods[i], fmt.tprintf("a %v (food %d)", k, i)}
	case game.Pest_Kind: if i < len(g.pests) {return g.pests[i], fmt.tprintf("a %v (%d)", k, i)}
	case game.Decor_Kind: return nil, fmt.tprintf("a %v", k)
	}
	return nil, "gone"
}

// Every field of a record and its value, a line each (long values cut).
field_lines :: proc(v: any, width: int) -> []string {
	out: [dynamic]string
	out.allocator = context.temp_allocator
	if v == nil {return out[:]}
	ti := runtime.type_info_base(type_info_of(v.id))
	if _, is_struct := ti.variant.(runtime.Type_Info_Struct); !is_struct {
		append(&out, fmt.tprintf("%v", v))
		return out[:]
	}
	for name in reflect.struct_field_names(v.id) {
		value := reflect.struct_field_value_by_name(v, name)
		text := fmt.tprintf("%s: %v", name, value)
		if len(text) > width {text = fmt.tprintf("%s…", text[:width - 1])}
		append(&out, text)
	}
	return out[:]
}

// Opens an entry of the index: a procedure or a file in the editor at its
// line, a model in the file browser.
open_entry :: proc(e: cmd.Entry) -> string {
	if e.file == "" {
		editor_open(e.at.file_path, int(e.at.line))
		return fmt.tprintf("%s:%d", e.at.file_path, e.at.line)
	}
	if strings.has_suffix(e.file, ".glb") {
		reveal(e.file)
		return fmt.tprintf("shown in the file browser: %s", e.file)
	}
	line := 0
	if e.find != "" {
		if data, err := os.read_entire_file(e.file, context.temp_allocator); err == nil {
			for l, i in strings.split_lines(string(data), context.temp_allocator) {
				if strings.contains(l, e.find) {
					line = i + 1
					break
				}
			}
		}
	}
	editor_open(e.file, line)
	return fmt.tprintf("%s:%d", e.file, line)
}

// Shows a file in the system's file browser.
reveal :: proc(path: string) {
	when ODIN_OS == .Darwin {
		_, _ = os.process_start({command = {"open", "-R", path}})
	} else when ODIN_OS == .Windows {
		_, _ = os.process_start({command = {"explorer", "/select,", path}})
	} else {
		_, _ = os.process_start({command = {"xdg-open", path}})
	}
}

// The mouse on the game (not on a panel): a click selects; on the inspector,
// a click on an entry opens it and the wheel scrolls.
inspect_mouse :: proc() {
	m := rl.GetMousePosition()
	on_editor := editor.visible && m.x >= f32(rl.GetScreenWidth()) / 2
	on_inspector := selection.active && rl.CheckCollisionPointRec(m, inspector_rect)
	if on_inspector {
		if wheel := rl.GetMouseWheelMove(); wheel != 0 {selection.scroll = max(selection.scroll - int(wheel * 3), 0)}
		return
	}
	if rl.IsMouseButtonPressed(.LEFT) && !on_editor && !menu.open {
		select_at(m)
	}
}

draw_inspector :: proc() {
	if !selection.active {return}
	v, name := selected_value()
	entries := cmd.index_of(selection.thing)
	lh := f32(INSPECT_TEXT + 5)
	x := f32(8)
	y := f32(118)
	h := f32(rl.GetScreenHeight()) - y - 44
	inspector_rect = {x, y, INSPECT_W, h}
	rl.DrawRectangleRec(inspector_rect, {22, 24, 30, 235})
	rl.DrawRectangleLinesEx(inspector_rect, 1, {250, 210, 90, 255})
	m := rl.GetMousePosition()
	click := rl.IsMouseButtonPressed(.LEFT)
	ty := y + 8
	draw_mono(name, x + 10, ty, {250, 210, 90, 255})
	ty += lh * 1.3
	for e in entries {
		where_ := e.file != "" ? e.file : fmt.tprintf("%s:%d", short_path(e.at.file_path), e.at.line)
		row := rl.Rectangle{x + 4, ty - 2, INSPECT_W - 8, lh}
		over := rl.CheckCollisionPointRec(m, row)
		if over {rl.DrawRectangleRec(row, {60, 64, 76, 255})}
		if over && click {say(open_entry(e))}
		draw_mono(fmt.tprintf("%s  %s", e.label, where_), x + 10, ty, over ? INK : TYPE, int((INSPECT_W - 20) / editor.cell))
		ty += lh
	}
	ty += lh * 0.4
	rl.DrawRectangleRec({x + 8, ty, INSPECT_W - 16, 1}, DIM)
	ty += lh * 0.4
	// The fields, read where they are in the game. A click on one starts
	// changing it (Enter sets it, Esc leaves it).
	rec := selected_record()
	if rec == nil {rec = v}
	lines := field_lines(rec, int((INSPECT_W - 20) / editor.cell))
	names := rec != nil ? reflect.struct_field_names(rec.id) : nil
	rows := int((y + h - ty - 6) / lh)
	selection.scroll = clamp(selection.scroll, 0, max(len(lines) - rows, 0))
	for i in selection.scroll ..< min(len(lines), selection.scroll + rows) {
		row := rl.Rectangle{x + 4, ty - 2, INSPECT_W - 8, lh}
		name_ := i < len(names) ? names[i] : ""
		editing := inspector_edit.active && inspector_edit.field == name_
		if editing {
			rl.DrawRectangleRec(row, {70, 64, 40, 255})
			draw_mono(fmt.tprintf("%s: %s_", name_, string(inspector_edit.text[:])), x + 10, ty, {250, 210, 90, 255})
		} else {
			if rl.CheckCollisionPointRec(m, row) && click && name_ != "" && rec != nil {
				value := fmt.tprintf("%v", reflect.struct_field_value_by_name(rec, name_))
				value, _ = strings.replace_all(strings.trim(value, "[]"), ",", "", context.temp_allocator)
				start_edit(name_, value)
			}
			draw_mono(lines[i], x + 10, ty, INK)
		}
		ty += lh
	}
}

short_path :: proc(path: string) -> string {
	if i := strings.index(path, "/src/"); i >= 0 {return path[i + 1:]}
	return path
}

// The selection as text (for the "inspect" command).
inspect_text :: proc() -> string {
	if !selection.active {return "nothing selected"}
	v, name := selected_value()
	b := strings.builder_make(context.temp_allocator)
	fmt.sbprintf(&b, "%s; opens:", name)
	for e, i in cmd.index_of(selection.thing) {
		where_ := e.file != "" ? e.file : fmt.tprintf("%s:%d", short_path(e.at.file_path), e.at.line)
		fmt.sbprintf(&b, " [%d] %s %s;", i, e.label, where_)
	}
	lines := field_lines(v, 60)
	fmt.sbprintf(&b, " %d fields, such as %s", len(lines), len(lines) > 0 ? lines[0] : "-")
	return strings.to_string(b)
}

// The selection, handed to the next library on a swap.
selection_text :: proc() -> string {
	if !selection.active {return ""}
	kind := ""
	switch _ in selection.thing {
	case cmd.Other: kind = "other"
	case game.Enemy_Kind: kind = "animal"
	case game.Round_Kind: kind = "round"
	case game.Food_Kind: kind = "food"
	case game.Pest_Kind: kind = "pest"
	case game.Decor_Kind: kind = "decor"
	}
	name := fmt.tprintf("%v", selection.thing)
	if i := strings.last_index_byte(name, '.'); i >= 0 {name = name[i + 1:]}
	return fmt.tprintf("#select %s %s %d %d\n", kind, name, selection.index, selection.scroll)
}

take_selection_text :: proc(line: string) {
	w := strings.fields(line, context.temp_allocator)
	if len(w) != 5 || w[0] != "#select" {return}
	index, _ := strconv.parse_int(w[3])
	scroll, _ := strconv.parse_int(w[4])
	t: cmd.Thing
	ok := false
	switch w[1] {
	case "other": t, ok = enum_thing(cmd.Other, w[2])
	case "animal": t, ok = enum_thing(game.Enemy_Kind, w[2])
	case "round": t, ok = enum_thing(game.Round_Kind, w[2])
	case "food": t, ok = enum_thing(game.Food_Kind, w[2])
	case "pest": t, ok = enum_thing(game.Pest_Kind, w[2])
	case "decor": t, ok = enum_thing(game.Decor_Kind, w[2])
	}
	if ok {
		select_thing(t, index)
		selection.scroll = scroll
	}
}

enum_thing :: proc($E: typeid, name: string) -> (cmd.Thing, bool) {
	v, ok := cmd.enum_named(E, name)
	return v, ok
}

// The selected thing's record, where it is in the game (so it can be changed).
selected_record :: proc() -> any {
	g := &game.g
	i := selection.index
	switch k in selection.thing {
	case cmd.Other:
		#partial switch k {
		case .Prosio: return any{&g.prosio, typeid_of(game.Prosio)}
		case .Field: if i < g.field_count {return any{&g.fields[i], typeid_of(game.Field)}}
		case .Fish: if i < len(g.fish) {return any{&g.fish[i], typeid_of(game.Fish)}}
		case .Thrown_Rock: if i < len(g.thrown) {return any{&g.thrown[i], typeid_of(game.Thrown_Rock)}}
		}
	case game.Enemy_Kind: if i < g.enemy_count {return any{&g.enemies[i], typeid_of(game.Enemy)}}
	case game.Round_Kind: if i < g.round_count {return any{&g.rounds[i], typeid_of(game.Round)}}
	case game.Food_Kind: if i < g.food_count {return any{&g.foods[i], typeid_of(game.Food)}}
	case game.Pest_Kind: if i < len(g.pests) {return any{&g.pests[i], typeid_of(game.Pest)}}
	case game.Decor_Kind:
	}
	return nil
}

// Changes a field of the selected thing: a number, a flag (true, false), a
// choice (by its name) or a few numbers (a place: "x y").
set_field :: proc(name, text: string) -> string {
	rec := selected_record()
	if rec == nil {return "nothing selected that can be changed"}
	field := reflect.struct_field_by_name(rec.id, name)
	if field.type == nil {return fmt.tprintf("no field %s", name)}
	ptr := rawptr(uintptr(rec.data) + field.offset)
	ti := runtime.type_info_base(field.type)
	words := strings.fields(text, context.temp_allocator)
	if len(words) == 0 {return "set it to what?"}
	#partial switch v in ti.variant {
	case runtime.Type_Info_Float:
		x, ok := strconv.parse_f64(words[0])
		if !ok {return "not a number"}
		switch ti.size {
		case 4: (^f32)(ptr)^ = f32(x)
		case 8: (^f64)(ptr)^ = x
		}
	case runtime.Type_Info_Integer:
		x, ok := strconv.parse_i64(words[0])
		if !ok {return "not a whole number"}
		switch ti.size {
		case 1: (^i8)(ptr)^ = i8(x)
		case 2: (^i16)(ptr)^ = i16(x)
		case 4: (^i32)(ptr)^ = i32(x)
		case 8: (^i64)(ptr)^ = x
		}
	case runtime.Type_Info_Boolean:
		(^bool)(ptr)^ = words[0] == "true" || words[0] == "1" || words[0] == "yes"
	case runtime.Type_Info_Enum:
		found := false
		for n, i in v.names {
			if strings.equal_fold(n, words[0]) {
				value := i64(v.values[i])
				switch ti.size {
				case 1: (^i8)(ptr)^ = i8(value)
				case 2: (^i16)(ptr)^ = i16(value)
				case 4: (^i32)(ptr)^ = i32(value)
				case 8: (^i64)(ptr)^ = value
				}
				found = true
			}
		}
		if !found {return fmt.tprintf("one of %v", v.names)}
	case runtime.Type_Info_Array:
		elem := runtime.type_info_base(v.elem)
		if _, is_float := elem.variant.(runtime.Type_Info_Float); !is_float || elem.size != 4 || len(words) != v.count {
			return fmt.tprintf("give %d numbers", v.count)
		}
		for w, i in words {
			x, ok := strconv.parse_f32(w)
			if !ok {return "not a number"}
			([^]f32)(ptr)[i] = x
		}
	case:
		return fmt.tprintf("%s cannot be changed here (%v)", name, field.type)
	}
	return fmt.tprintf("%s: %v", name, any{ptr, field.type.id})
}

// Editing a field in the inspector: its name, and what is being typed.
Inspector_Edit :: struct {
	active: bool,
	field:  string,
	text:   [dynamic]u8,
}

inspector_edit: Inspector_Edit

inspector_keys :: proc() {
	for {
		r := rl.GetCharPressed()
		if r == 0 {break}
		if r < 128 {append(&inspector_edit.text, u8(r))}
	}
	switch {
	case rl.IsKeyPressed(.ESCAPE):
		inspector_edit.active = false
	case rl.IsKeyPressed(.BACKSPACE) || rl.IsKeyPressedRepeat(.BACKSPACE):
		if len(inspector_edit.text) > 0 {pop(&inspector_edit.text)}
	case rl.IsKeyPressed(.ENTER):
		say(set_field(inspector_edit.field, string(inspector_edit.text[:])))
		inspector_edit.active = false
	}
}

start_edit :: proc(field: string, value: string) {
	inspector_edit.active = true
	delete(inspector_edit.field)
	inspector_edit.field = strings.clone(field)
	clear(&inspector_edit.text)
	append(&inspector_edit.text, value)
}
