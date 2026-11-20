package game

UI_WHITE :: Color{255, 255, 255, 255}
UI_DARK :: Color{30, 34, 40, 255}
UI_PANEL :: Color{20, 30, 24, 150}
UI_RED :: Color{226, 70, 70, 255}
UI_GREEN :: Color{110, 200, 90, 255}
UI_YELLOW :: Color{246, 206, 70, 255}
UI_ORANGE :: Color{244, 150, 60, 255}
UI_BLUE :: Color{80, 170, 240, 255}

// Text with a dark edge so it reads on any background.
label :: proc(text: cstring, x, y, size: f32, color: Color = UI_WHITE) {
	o := max(size / 12, 1)
	ui_text(text, x + o, y + o, size, UI_DARK)
	ui_text(text, x, y, size, color)
}

label_centred :: proc(text: cstring, cx, y, size: f32, color: Color = UI_WHITE) {
	label(text, cx - ui_text_width(text, size) / 2, y, size, color)
}

// A label floating above a place in the world.
world_label :: proc(text: cstring, pos: Vec3, size: f32, color: Color = UI_WHITE) {
	s := world_to_screen(pos)
	label_centred(text, s.x, s.y, size, color)
}

draw_ui :: proc() {
	sw, sh := screen_size()
	s := min(sw / 1280, sh / 720)
	p := &g.prosio

	ui_vignette(35)

	// Signs in the world.
	world_label("SKINNY DOOR", {g.door_pos.x, 2.3, g.door_pos.y}, 18 * s, UI_YELLOW)
	if g.boulder.state == .On_Seesaw {
		world_label(ui_format("%d kg", i32(BOULDER_KG)), {g.boulder.pos.x, g.boulder.y + 1.7, g.boulder.pos.y}, 18 * s, UI_YELLOW)
	}
	lever := g.seesaws[LEVER]
	world_label(ui_format("%d kg", i32(IRON_KG)), {lever.pivot.x - lever.dir * lever.load_arm, 2.3, lever.pivot.y}, 18 * s, UI_YELLOW)
	tower := g.platforms[g.tower]
	if !g.crate_broken && !on_tower(p.pos, p.height) {
		world_label("JUMP FROM HERE", {(tower.lo.x + tower.hi.x) / 2, TOWER_HEIGHT + 0.9, (tower.lo.y + tower.hi.y) / 2}, 18 * s, UI_YELLOW)
	}
	if !g.gates[0].open {
		world_label(ui_format("%d kg", i32(PLATE_KG)), {g.plate_pos.x, 1.2, g.plate_pos.y}, 20 * s, UI_YELLOW)
	}

	// Speech bubble.
	if p.bubble_t > 0 && p.fail == .None {
		size := 22 * s
		pos := world_to_screen({p.pos.x, p.height + 2.6, p.pos.y})
		w := ui_text_width(p.bubble, size) + 24 * s
		ui_round_rect(pos.x - w / 2, pos.y - size, w, size + 14 * s, UI_WHITE)
		ui_text(p.bubble, pos.x - w / 2 + 12 * s, pos.y - size + 7 * s, size, UI_DARK)
	}

	// Weight bar, with its zones.
	x, y := 24 * s, 20 * s
	bar_w, bar_h := 380 * s, 26 * s
	ui_round_rect(x - 10 * s, y - 8 * s, bar_w + 130 * s, 140 * s, UI_PANEL)
	label("WEIGHT", x, y, 20 * s)
	y += 26 * s
	Zone :: struct {
		from, to: f32,
		color:    Color,
	}
	zones := [?]Zone {
		{KG_MIN, KG_MIN + KG_DANGER, UI_RED},
		{KG_MIN + KG_DANGER, KG_LEAN, UI_GREEN},
		{KG_LEAN, KG_HUGE, UI_YELLOW},
		{KG_HUGE, KG_MAX - KG_DANGER, UI_ORANGE},
		{KG_MAX - KG_DANGER, KG_MAX, UI_RED},
	}
	ui_rect(x - 3 * s, y - 3 * s, bar_w + 6 * s, bar_h + 6 * s, UI_DARK)
	for z in zones {
		x0 := x + bar_w * fatness(z.from)
		x1 := x + bar_w * fatness(z.to)
		ui_rect(x0, y, x1 - x0, bar_h, z.color)
	}
	marker := x + bar_w * fatness(p.kg)
	ui_rect(marker - 5 * s, y - 7 * s, 10 * s, bar_h + 14 * s, UI_DARK)
	ui_rect(marker - 2.5 * s, y - 5 * s, 5 * s, bar_h + 10 * s, UI_WHITE)
	label(ui_format("%d kg", i32(p.kg + 0.5)), x + bar_w + 14 * s, y + 2 * s, 24 * s)
	if p.carry == .Rock {
		// What he carries counts as his weight on plates and planks.
		label(ui_format("+%d", i32(p.carry_kg + 0.5)), x + bar_w + 14 * s, y + 30 * s, 20 * s, UI_YELLOW)
	}

	zone_name: cstring = "CHUBBY"
	zone_color := UI_YELLOW
	if p.kg < KG_LEAN {
		zone_name, zone_color = "LEAN", UI_GREEN
	} else if p.kg >= KG_HUGE {
		zone_name, zone_color = "HUGE", UI_ORANGE
	}
	label(zone_name, x + 90 * s, y - 26 * s, 20 * s, zone_color)

	// Stamina bar.
	y += bar_h + 16 * s
	label("STAMINA", x, y, 20 * s)
	y += 26 * s
	ui_rect(x - 3 * s, y - 3 * s, bar_w + 6 * s, 18 * s + 6 * s, UI_DARK)
	ui_rect(x, y, bar_w * p.stamina / STAMINA_MAX, 18 * s, (p.winded || p.stamina < 25) ? UI_RED : UI_BLUE)
	// The notch shows how much one bump costs right now.
	ui_rect(x + bar_w * dash_cost(p.kg) / STAMINA_MAX - 1 * s, y, 2 * s, 18 * s, UI_DARK)

	// Truffles found.
	truffles := ui_format("GOLDEN TRUFFLES  %d / 5", i32(g.truffle_count))
	label(truffles, sw - ui_text_width(truffles, 22 * s) - 24 * s, 22 * s, 22 * s, UI_YELLOW)

	// What the action button does right now.
	if p.fail == .None {
		action: cstring = "Hold E: push-ups"
		if p.carry != .Nothing {
			switch {
			case p.carry == .Enemy && p.carry_kg > p.kg * LIFT_LIMIT:
				action = "Too heavy to swing!   SPACE: heave     F: let go"
			case p.carry == .Enemy:
				action = "SPACE: bash with it!     F: throw it"
			case p.lift_t > 0:
				action = "Lifting..."
			case:
				action = "F: throw it down"
			}
		} else if food_in_reach(p.pos, prosio_radius(p.kg) + 0.75) != nil || bush_in_reach(p.pos, prosio_radius(p.kg) + 0.6) != nil {
			action = "E: eat"
		} else if _, found := grab_target(); found {
			action = "F: grab     Hold E: push-ups"
		}
		label_centred(action, sw / 2, sh - 74 * s, 22 * s, UI_YELLOW)
	}
	label_centred("Move: WASD or arrows   Bump: SPACE   Jump: J   Sprint: SHIFT   Grab / throw: F   Eat / push-ups: E   Menu: ESC", sw / 2, sh - 40 * s, 20 * s)

	if g.truffle_count == len(g.truffles) && g.win_t < 6 {
		label_centred("ALL THE GOLDEN TRUFFLES!", sw / 2, sh * 0.26, 54 * s, UI_YELLOW)
		label_centred("Well done, Prosio!", sw / 2, sh * 0.26 + 62 * s, 30 * s)
	}

	if p.fail != .None && p.fail_t > 0.8 {
		ui_rect(0, 0, sw, sh, {0, 0, 0, 110})
		title: cstring = "PROSIO FAINTED!"
		line: cstring = "Too thin... he needed a snack."
		if p.fail == .Heart_Attack {
			title = "HEART ATTACK!"
			line = "Too heavy... his heart could not keep up."
		}
		label_centred(title, sw / 2, sh * 0.56, 64 * s, UI_RED)
		label_centred(line, sw / 2, sh * 0.56 + 76 * s, 28 * s)
		label_centred("Press ENTER to try again", sw / 2, sh * 0.56 + 124 * s, 26 * s, UI_YELLOW)
	}
}

Menu_Item :: enum {
	Play,
	Resume,
	Look,
	Restart,
	Exit_To_Menu,
	Quit,
}

MENU_TEXT := [Menu_Item]cstring {
	.Play         = "PLAY",
	.Resume       = "RESUME",
	.Look         = "",
	.Restart      = "RESTART",
	.Exit_To_Menu = "EXIT TO MENU",
	.Quit         = "QUIT",
}

look_text :: proc() -> cstring {
	return ui_format("PIXELS: %d / 5", i32(pixel_level + 1))
}

MENU_MAIN := [?]Menu_Item{.Play, .Look, .Quit}
MENU_MAIN_WEB := [?]Menu_Item{.Play, .Look} // the browser has nothing to quit to
MENU_PAUSE := [?]Menu_Item{.Resume, .Look, .Restart, .Exit_To_Menu}

menu_items :: proc() -> []Menu_Item {
	if scene == .Paused {
		return MENU_PAUSE[:]
	}
	return IS_WEB ? MENU_MAIN_WEB[:] : MENU_MAIN[:]
}

menu_length :: proc() -> int {
	return len(menu_items())
}

draw_menu :: proc() {
	sw, sh := screen_size()
	s := min(sw / 1280, sh / 720)
	ui_rect(0, 0, sw, sh, {10, 24, 20, scene == .Menu ? 120 : 150})

	title: cstring = scene == .Menu ? "PROSIO" : "PAUSED"
	size := (scene == .Menu ? 120 : 72) * s
	top := sh * (scene == .Menu ? 0.12 : 0.2)
	ui_text(title, sw / 2 - ui_text_width(title, size) / 2 + 5 * s, top + 5 * s, size, UI_DARK)
	ui_text(title, sw / 2 - ui_text_width(title, size) / 2, top, size, scene == .Menu ? Color{250, 172, 182, 255} : UI_WHITE)
	if scene == .Menu {
		label_centred("the pig who eats, runs and bumps", sw / 2, top + size + 4 * s, 24 * s, UI_YELLOW)
	}

	y := sh * 0.5
	for i in 0 ..< menu_length() {
		item := menu_items()[i]
		text := item == .Look ? look_text() : MENU_TEXT[item]
		chosen := i == menu_choice
		text_size := (chosen ? 44 : 36) * s
		w := ui_text_width(text, text_size)
		if chosen {
			ui_round_rect(sw / 2 - w / 2 - 28 * s, y - 8 * s, w + 56 * s, text_size + 16 * s, {250, 172, 182, 235})
			ui_text(text, sw / 2 - w / 2, y, text_size, UI_DARK)
		} else {
			label_centred(text, sw / 2, y, text_size)
		}
		y += 64 * s
	}

	label_centred("Choose: UP / DOWN     Select: ENTER or SPACE     Pixel size any time: 1 to 5", sw / 2, sh - 110 * s, 20 * s, UI_YELLOW)
	if scene == .Menu {
		// While paused, the game's own controls line is already showing.
		label_centred("Move: WASD or arrows   Bump: SPACE   Jump: J   Sprint: SHIFT   Grab / throw: F   Eat / push-ups: E", sw / 2, sh - 70 * s, 20 * s)
	}
}
