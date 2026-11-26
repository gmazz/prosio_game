package game

import "core:math"

// Text with a dark edge all round, a pixel of the font wide, so it reads on
// any background.
label :: proc(text: cstring, x, y, size: f32, color: Color = UI_WHITE) {
	o := font_scale(size) // one pixel of the font
	for d in ([4][2]f32{{-1, 0}, {1, 0}, {0, -1}, {0, 1}}) {
		ui_text(text, x + d.x * o, y + d.y * o, size, UI_DARK)
	}
	ui_text(text, x + o, y + o, size, UI_DARK)
	ui_text(text, x, y, size, color)
}

label_centred :: proc(text: cstring, cx, y, size: f32, color: Color = UI_WHITE) {
	label(text, cx - ui_text_width(text, size) / 2, y, size, color)
}

// The size, at most this one, at which a text fits a width: smaller if it
// must be, but no smaller than FIT_SMALLEST of it (or than the letters go).
fit_size :: proc(text: cstring, size, width: f32) -> f32 {
	sz := size
	for sz - 1 >= size * FIT_SMALLEST && ui_text_width(text, sz) > width {
		sz -= 1
	}
	return sz
}

// A line centred in a given width (the help along the bottom of a menu):
// smaller if it would not fit (see fit_size), and past that on two lines,
// broken where its parts are spaced apart (or else at a space) so the two
// are as even as can be. y is where the line's top would be; two lines sit
// either side of it.
label_fitted :: proc(text: cstring, cx, y, size, width: f32, color: Color = UI_WHITE) {
	sz := fit_size(text, size, width)
	at, after := split_point(text, sz)
	if ui_text_width(text, sz) <= width || at < 0 {
		label_centred(text, cx, y, sz, color)
		return
	}
	line := text_height(sz)
	label_centred(text_part(text, 0, at), cx, y - line / 2, sz, color)
	label_centred(text_part(text, after, len(text)), cx, y + line / 2, sz, color)
}

// Where to break a line in two: at the gap of two spaces or more that
// halves it best, or, with no such gap, at the space that does. The first
// part ends at at, the second starts at after; at is -1 with no space.
split_point :: proc(text: cstring, size: f32) -> (at, after: int) {
	s := string(text)
	at, after = -1, -1
	best := f32(1e9)
	for wide in ([]bool{true, false}) {
		for i := 1; i < len(s); i += 1 {
			if s[i] != ' ' || s[i - 1] == ' ' || (wide && (i + 1 >= len(s) || s[i + 1] != ' ')) {
				continue
			}
			end := i
			for end < len(s) && s[end] == ' ' {
				end += 1
			}
			worse := max(ui_text_width(text_part(text, 0, i), size), ui_text_width(text_part(text, end, len(s)), size))
			if worse < best {
				at, after, best = i, end, worse
			}
		}
		if at >= 0 {
			break
		}
	}
	return
}

// A text in lines no wider than width, broken at spaces. Returns how tall
// they are together.
label_wrapped :: proc(text: cstring, x, y, size, width: f32, color: Color = UI_WHITE) -> f32 {
	s := string(text)
	line := text_height(size)
	ly := y
	start := 0
	for start < len(s) {
		// The most words, from start, that fit (at least one).
		end, i := -1, start
		for {
			for i < len(s) && s[i] != ' ' {
				i += 1
			}
			if end >= 0 && ui_text_width(text_part(text, start, i), size) > width {
				break
			}
			end = i
			if i >= len(s) {
				break
			}
			i += 1
		}
		label(text_part(text, start, end), x, ly, size, color)
		ly += line
		start = end
		for start < len(s) && s[start] == ' ' {
			start += 1
		}
	}
	return ly - y
}

// A label floating above a place in the world.
world_label :: proc(text: cstring, pos: Vec3, size: f32, color: Color = UI_WHITE) {
	s := world_to_screen(pos)
	label_centred(text, s.x, s.y, size, color)
}

// What the action buttons would do right now, as the line at the bottom of
// the screen says it; nil when there is nothing to say.
prompt_text :: proc() -> cstring {
	p := &g.prosio
	if p.fail != .None {
		return nil
	}
	action: cstring = nil
	if gate, at_gate := gate_in_reach(); at_gate && p.lift_t <= 0 {
		open := gate_state(gate) == GATE_OPEN
		switch {
		case p.carry == .Enemy:
			action = open ? TEXT.gate_shut_drag : TEXT.gate_open_bring
		case open:
			action = TEXT.gate_shut_take
		case:
			action = TEXT.gate_open_take
		}
	} else if p.carry != .Nothing {
		// What F will do with an animal: throw it, or, too heavy or too
		// tired for that, put it down.
		too_heavy := p.carry_kg > p.kg * LIFT_LIMIT * strength()
		let_go: cstring = too_heavy ? TEXT.let_go : (p.stamina < throw_cost() ? TEXT.put_down_tired : TEXT.put_down_or_throw)
		at_fence := false
		if p.carry == .Enemy && p.lift_t <= 0 {
			what, _, _ := built_in_reach()
			at_fence = what == .Fence
		}
		switch {
		case at_fence && ENEMY_KG[g.enemies[p.carry_index].kind] <= hoist_most():
			action = TEXT.lift_over_fence
		case at_fence:
			action = TEXT.too_heavy_over_fence 
		case p.carry == .Enemy && g.enemies[p.carry_index].ko && MEAT_FROM[g.enemies[p.carry_index].kind]:
			// A body: it wants chopping up, at the block by the fire.
			if _, at_fire := fire_in_reach(p.pos, prosio_radius(p.kg) + 1.2); at_fire {
				action = fill(TEXT.chop_it, {"then", let_go})
			} else if g.camp_up {
				action = fill(too_heavy ? TEXT.drag_to_fire : TEXT.drag_to_fire_or_bash, {"then", let_go})
			} else {
				action = fill(too_heavy ? TEXT.drag_to_pond : TEXT.drag_to_pond_or_bash, {"then", let_go})
			}
		case p.carry == .Enemy && too_heavy:
			action = TEXT.too_heavy_swing
		case p.carry == .Enemy && g.enemies[p.carry_index].kind == .Goat:
			action = fill(TEXT.milk_or_bash, {"then", let_go})
		case p.carry == .Enemy:
			action = fill(TEXT.bash_with_it, {"then", let_go})
		case p.lift_t > 0:
			action = TEXT.lifting
		case:
			action = TEXT.put_down_or_throw
		}
	} else if goat := licking_goat(); goat != nil && goat.milk_t <= 0 {
		action = goat.licking ? TEXT.milk_goat_licking : TEXT.milk_goat
	} else if food := food_in_reach(p.pos, prosio_radius(p.kg) + 0.75); food != nil && food.kind == .Wood {
		action = TEXT.pick_branch
	} else if food != nil && food.kind == .Spear {
		action = TEXT.pick_spear
	} else if food != nil {
		// What it is worth now: less if it has not finished growing.
		action = fill(food.grow < 0.95 && !food.fallen ? TEXT.pick_growing : TEXT.pick, {"kcal", int(i32(food_kcal(food)))})
	} else if bush := bush_in_reach(p.pos, prosio_radius(p.kg) + 0.6); bush != nil {
		if bush.kind == .Hive {
			action = TEXT.take_honey
		} else if bush.kind == .Salt_Rock {
			action = TEXT.break_salt
		} else if bush.kind == .Pebbles {
			action = TEXT.pick_pebbles
		} else {
			action = fill(bush.ripe < 0.95 ? TEXT.pick_berries_ripening : TEXT.pick_berries, {"kcal", int(i32(bush_kcal(bush)))})
		}
	} else if l := larder_first(); l >= 0 {
		action = larder_empty(&g.larders[l]) ? TEXT.open_larder_take : TEXT.open_larder
	} else if at, near := station_near(p.pos, prosio_radius(p.kg)); near {
		o := g.stations[at]
		switch at {
		case .Oven:
			action = o.ready ? TEXT.oven_take : (o.baking ? TEXT.oven_wait : TEXT.oven_bake)
		case .Fire:
			action = o.ready ? TEXT.fire_take : (o.baking ? TEXT.fire_wait : TEXT.fire_cook)
		case .Camp:
			action = o.ready ? TEXT.fire_take : (o.baking ? TEXT.fire_wait : TEXT.camp_cook)
		case .Churn:
			action = o.ready ? TEXT.churn_take : (o.baking ? TEXT.churn_wait : TEXT.churn_churn)
		case .Bench:
			action = o.ready ? TEXT.bench_take : (o.baking ? TEXT.bench_wait : TEXT.bench_build)
		}
	} else if mill_in_reach(p.pos, prosio_radius(p.kg)) {
		switch {
		case g.mill.ready > 0:
			action = TEXT.mill_take
		case g.mill.grinding > 0:
			action = TEXT.mill_wait
		case p.sack[.Wheat] > 0:
			action = TEXT.mill_grind
		case:
			action = TEXT.mill_about
		}
	} else if pond_in_reach(p.pos, prosio_radius(p.kg)) {
		if rod_chosen() {
			action = fish_in_reach() ? TEXT.pond_cast_near : TEXT.pond_cast
		} else {
			action = fish_in_reach() ? TEXT.pond_grab_near : TEXT.pond_grab
		}
	} else if _, in_reach := grab_target(); !in_reach && throwable_chosen() {
		action = p.winding ? TEXT.winding : (p.sack_sel == .Spear ? TEXT.hold_throw_spear : TEXT.hold_throw_pebble)
	} else if target, found := grab_target(); found {
		if target.kind == .Rock {
			action = TEXT.lift_rock
		} else if e := &g.enemies[target.index]; e.state == .Dead {
			action = TEXT.take_by_leg
		} else {
			action = TEXT.grab_animal[e.kind]
		}
	} else if (p.sack_sel == .Fence || p.sack_sel == .Gate) && p.sack[p.sack_sel] > 0 {
		// Q puts a piece up where the mark on the ground is; F takes one down.
		ok, _ := fence_fits(fence_ahead())
		what, _, _ := built_in_reach()
		put: cstring = p.sack_sel == .Gate ? TEXT.put_gate : TEXT.put_fence
		switch {
		case ok && what == .Fence:
			action = fill(TEXT.put_or_take_down, {"put", put})
		case ok:
			action = put
		case what == .Fence:
			action = TEXT.take_fence_down
		case what == .Scarecrow:
			action = TEXT.take_scarecrow_down
		}
	} else if p.sack_sel == .Scarecrow && p.sack[.Scarecrow] > 0 {
		action = TEXT.put_scarecrow
	} else if p.sack_sel == .Larder && p.sack[.Larder] > 0 && larder_in_reach() < 0 {
		action = TEXT.put_larder
	} else if p.sack_sel == .Campfire && p.sack[.Campfire] > 0 && !g.camp_up {
		action = TEXT.put_campfire
	} else if what, _, which := built_in_reach(); what != .Nothing {
		switch {
		case what == .Larder:
			action = larder_empty(&g.larders[which]) ? TEXT.open_larder_take : TEXT.open_larder
		case what == .Scarecrow:
			action = TEXT.take_scarecrow_down
		case can_clear_fence():
			action = TEXT.jump_fence
		case g.prosio.carry == .Enemy:
			action = TEXT.throw_over_fence
		case:
			action = TEXT.too_heavy_jump_fence
		}
	}
	if action == nil && p.carry == .Nothing {
		if _, at_tree := tree_in_front(facing_dir(p.facing)); at_tree {
			action = TEXT.shake_tree
		}
	}
	return action
}

draw_ui :: proc() {
	sw, sh := screen_size()
	s := min(sw / 1280, sh / 720)
	p := &g.prosio

	// With too few vitamins his sight dims: the dark closes in from the edges.
	if lacks(.Vitamins) {
		ui_vignette(205, 2)
	} else {
		ui_vignette(35)
	}

	// Signs in the world.
	for o, at in g.stations {
		if !station_standing(at) || !on_screen(o.pos, 4) {
			continue
		}
		top := Vec3{o.pos.x, at == .Oven ? 2.9 : 2.5, o.pos.y}
		switch {
		case o.ready:
			pulse := 1 + 0.08 * math.sin(g.time * 6)
			world_label(TEXT.ready, top, 22 * s * pulse, UI_GREEN)
		case o.baking:
			world_label(fill(TEXT.station_busy[at], {"seconds", int(i32(math.ceil(o.bake_t)))}), top, 18 * s, UI_ORANGE)
		case:
			world_label(TEXT.station_label[at], top, 16 * s, UI_YELLOW)
		}
	}
	mill_top := Vec3{g.mill.pos.x, 4.6, g.mill.pos.y}
	switch {
	case g.mill.ready > 0 && g.mill.grinding == 0:
		pulse := 1 + 0.08 * math.sin(g.time * 6)
		world_label(TEXT.flour_ready_label, mill_top, 20 * s * pulse, UI_GREEN)
	case g.mill.grinding > 0:
		world_label(fill(TEXT.mill_busy, {"count", int(i32(g.mill.grinding))}), mill_top, 18 * s, UI_ORANGE)
	case:
		world_label(TEXT.mill, mill_top, 16 * s, UI_YELLOW)
	}

	// Speech bubble.
	if p.bubble_t > 0 && p.fail == .None {
		// It sits a little above the top of him, whatever is on his head,
		// with a thin grey edge.
		size := 20 * s
		top := world_to_screen({p.pos.x, p.height + (HEAD_HEIGHT + prosio_base_head_lift() + head_top()) * PROSIO_SIZE, p.pos.y})
		w := ui_text_width(p.bubble, size) + 22 * s
		h := size + 13 * s
		x, y := top.x - w / 2, top.y - BUBBLE_GAP * s - h
		edge := BUBBLE_EDGE * s
		ui_round_rect(x - edge, y - edge, w + 2 * edge, h + 2 * edge, BUBBLE_EDGE_COLOR, 0.5)
		ui_round_rect(x, y, w, h, UI_WHITE)
		ui_text(p.bubble, x + 11 * s, y + 6.5 * s, size, UI_DARK)
	}

	// What he is made of, and beside it the sack.
	x, y := 18 * s, 14 * s
	panel_w, _ := draw_body_panel(x, y, s)
	draw_sack(x + panel_w + 12 * s, 14 * s - 9 * s + 2 * s, s)

	// Where he is: the part of the meadow, and, for a few seconds after he
	// gets there, what is found there.
	if g.in_region {
		fade := clamp(g.region_t * 2, 0, 1)
		name_color := UI_YELLOW
		name_color.a = u8(255 * fade)
		about_color := UI_WHITE
		about_color.a = u8(255 * fade * clamp(REGION_ABOUT_TIME - g.region_t, 0, 1))
		name, about := TEXT.region_name[g.region], TEXT.region_about[g.region]
		label(name, sw - ui_text_width(name, 22 * s) - 20 * s, 16 * s, 22 * s, name_color)
		label(about, sw - ui_text_width(about, 16 * s) - 20 * s, 44 * s, 16 * s, about_color)
	}

	// What the action buttons do right now.
	if action := prompt_text(); action != nil {
		label_centred(action, sw / 2, sh - 46 * s, 20 * s, UI_YELLOW)
	}

	if p.fail != .None && p.fail_t > 0.8 {
		ui_rect(0, 0, sw, sh, {0, 0, 0, 110})
		title: cstring = TEXT.fainted
		line: cstring = TEXT.fainted_line
		if p.fail == .Heart_Attack {
			title = TEXT.heart_attack
			line = TEXT.heart_attack_line
		}
		if p.fail == .Diet {
			title, line = ending().title, ending().line
		}
		if p.fail == .Beaten {
			title = TEXT.knocked_out
			line = TEXT.knocked_out_line
		}
		label_centred(title, sw / 2, sh * 0.56, 64 * s, UI_RED)
		label_centred(line, sw / 2, sh * 0.56 + 76 * s, 28 * s)
		label_centred(TEXT.wake_up, sw / 2, sh * 0.56 + 124 * s, 26 * s, UI_YELLOW)
		label_centred(TEXT.wake_up_note, sw / 2, sh * 0.56 + 160 * s, 18 * s)
	}
}

Menu_Item :: enum {
	Play,
	Resume,
	Look,
	Language,
	Load,
	Restart,
	Exit_To_Menu,
	Quit,
}


look_text :: proc() -> cstring {
	return fill(TEXT.pixels, {"level", int(i32(pixel_level + 1))}, {"levels", PIXEL_LEVELS})
}

language_text :: proc() -> cstring {
	return fill(TEXT.language_line, {"name", LANGUAGE_NAME[language]})
}

// What a choice on the main or pause menu says.
menu_item_text :: proc(item: Menu_Item) -> cstring {
	#partial switch item {
	case .Look:
		return look_text()
	case .Language:
		return language_text()
	case .Play:
		if has_save {
			return TEXT.continue_game
		}
	}
	return TEXT.menu_text[item]
}

// With a saved Prosio, the main menu carries on with him, or starts over
// with a new one. (The browser has nothing to quit to.)
// The language can be changed there too, when the game has more than one.
// LOAD shows only when there is a backup to load (saves.odin).
MENU_MAIN := [?]Menu_Item{.Play, .Look, .Language, .Load, .Restart, .Quit}
MENU_PAUSE := [?]Menu_Item{.Resume, .Look, .Language, .Load, .Restart, .Exit_To_Menu}

menu_items :: proc() -> []Menu_Item {
	@(static) list: [max(len(MENU_MAIN), len(MENU_PAUSE))]Menu_Item
	n := 0
	for item in (scene == .Paused ? MENU_PAUSE[:] : MENU_MAIN[:]) {
		if (item == .Restart && !has_save && scene != .Paused) || (item == .Quit && IS_WEB) || (item == .Load && backup_count == 0) || (item == .Language && len(Language) < 2) {
			continue
		}
		list[n] = item
		n += 1
	}
	return list[:n]
}

menu_length :: proc() -> int {
	return len(menu_items())
}

draw_menu :: proc() {
	sw, sh := screen_size()
	s := min(sw / 1280, sh / 720)
	ui_rect(0, 0, sw, sh, {10, 24, 20, scene == .Menu ? 120 : 150})

	title: cstring = scene == .Menu ? TEXT.title : TEXT.paused
	size := (scene == .Menu ? 120 : 72) * s
	top := sh * (scene == .Menu ? 0.12 : 0.2)
	ui_text(title, sw / 2 - ui_text_width(title, size) / 2 + 5 * s, top + 5 * s, size, UI_DARK)
	ui_text(title, sw / 2 - ui_text_width(title, size) / 2, top, size, scene == .Menu ? Color{250, 172, 182, 255} : UI_WHITE)
	if scene == .Menu {
		// The title's letters end three quarters of the way down its line
		// (the rest is room for tails below it); the subtitle keeps a gap
		// under them.
		label_centred(TEXT.subtitle, sw / 2, top + text_height(size) * 0.75 + SUBTITLE_GAP * s, 24 * s, UI_YELLOW)
	}

	y := sh * MENU_TOP
	for i in 0 ..< menu_length() {
		item := menu_items()[i]
		text := menu_item_text(item)
		chosen := i == menu_choice
		text_size := (chosen ? 44 : 36) * s
		w := ui_text_width(text, text_size)
		if chosen {
			ui_round_rect(sw / 2 - w / 2 - 28 * s, y - 8 * s, w + 56 * s, text_size + 16 * s, {250, 172, 182, 235})
			ui_text(text, sw / 2 - w / 2, y, text_size, UI_DARK)
		} else {
			label_centred(text, sw / 2, y, text_size)
		}
		y += MENU_STEP * s
	}

	label_fitted(TEXT.menu_help, sw / 2, sh - 110 * s, 20 * s, sw - 80 * s, UI_YELLOW)
	// What every button does (in the game only the line about what the
	// buttons would do just there shows).
	label_centred(TEXT.controls_line, sw / 2, sh - 70 * s, 13 * s)
}
