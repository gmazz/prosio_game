package game

import "core:math"

UI_WHITE :: Color{255, 255, 255, 255}
UI_DARK :: Color{30, 34, 40, 255}
UI_PANEL :: Color{20, 30, 24, 150}
UI_RED :: Color{226, 70, 70, 255}
UI_GREEN :: Color{110, 200, 90, 255}
UI_YELLOW :: Color{246, 206, 70, 255}
UI_ORANGE :: Color{244, 150, 60, 255}
UI_BLUE :: Color{80, 170, 240, 255}

CONTROLS :: "Move: WASD   Bump: SPACE   Jump: J   Sprint: SHIFT   Grab / throw: F   Pick up / oven: E   Sack: Z C   Eat: Q   Menu: ESC"

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
	oven_top := Vec3{g.oven.pos.x, 2.9, g.oven.pos.y}
	switch {
	case g.oven.ready:
		pulse := 1 + 0.08 * math.sin(g.time * 6)
		world_label("READY!", oven_top, 22 * s * pulse, UI_GREEN)
	case g.oven.baking:
		world_label(ui_format("BAKING... %d", i32(math.ceil(g.oven.bake_t))), oven_top, 18 * s, UI_ORANGE)
	case:
		world_label("OVEN", oven_top, 16 * s, UI_YELLOW)
	}
	for kind in Region_Kind {
		if kind != .Home && length2(signpost_pos(kind) - g.camera) < 16 {
			at := signpost_pos(kind)
			world_label(REGIONS[kind].sign, {at.x, 2.05, at.y}, 15 * s, UI_YELLOW)
		}
	}

	// Speech bubble.
	if p.bubble_t > 0 && p.fail == .None {
		size := 20 * s
		pos := world_to_screen({p.pos.x, p.height + 2.6, p.pos.y})
		w := ui_text_width(p.bubble, size) + 22 * s
		ui_round_rect(pos.x - w / 2, pos.y - size, w, size + 13 * s, UI_WHITE)
		ui_text(p.bubble, pos.x - w / 2 + 11 * s, pos.y - size + 6.5 * s, size, UI_DARK)
	}

	// Weight bar, with its zones, and the stamina bar under it.
	x, y := 18 * s, 14 * s
	bar_w, bar_h := 250 * s, 15 * s
	pad := 9 * s
	panel_w := bar_w + 82 * s
	panel_h := 104 * s
	ui_round_rect(x - pad, y - pad + 2 * s, panel_w + pad, panel_h, UI_PANEL, 0.2)
	label("WEIGHT", x, y, 16 * s)
	zone_name: cstring = "CHUBBY"
	zone_color := UI_YELLOW
	if p.kg < KG_LEAN {
		zone_name, zone_color = "LEAN", UI_GREEN
	} else if p.kg >= KG_HUGE {
		zone_name, zone_color = "HUGE", UI_ORANGE
	}
	label(zone_name, x + 76 * s, y, 16 * s, zone_color)
	y += 22 * s
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
	ui_rect(x - 2 * s, y - 2 * s, bar_w + 4 * s, bar_h + 4 * s, UI_DARK)
	for z in zones {
		x0 := x + bar_w * fatness(z.from)
		x1 := x + bar_w * fatness(z.to)
		ui_rect(x0, y, x1 - x0, bar_h, z.color)
	}
	marker := x + bar_w * fatness(p.kg)
	ui_rect(marker - 4 * s, y - 5 * s, 8 * s, bar_h + 10 * s, UI_DARK)
	ui_rect(marker - 2 * s, y - 3.5 * s, 4 * s, bar_h + 7 * s, UI_WHITE)
	label(ui_format("%d kg", i32(p.kg + 0.5)), x + bar_w + 10 * s, y - 1 * s, 18 * s)
	if p.carry == .Rock {
		// What he carries counts as his weight when he jumps and lands.
		label(ui_format("+%d", i32(p.carry_kg + 0.5)), x + bar_w + 10 * s, y + 19 * s, 15 * s, UI_YELLOW)
	}
	y += bar_h + 10 * s
	label("STAMINA", x, y, 16 * s)
	y += 22 * s
	ui_rect(x - 2 * s, y - 2 * s, bar_w + 4 * s, 10 * s + 4 * s, UI_DARK)
	ui_rect(x, y, bar_w * p.stamina / STAMINA_MAX, 10 * s, (p.winded || p.stamina < 25) ? UI_RED : UI_BLUE)
	// The notch shows how much one bump costs right now.
	ui_rect(x + bar_w * dash_cost(p.kg) / STAMINA_MAX - 1 * s, y, 2 * s, 10 * s, UI_DARK)

	// The sack, beside the weight.
	draw_sack(x + panel_w + 12 * s, 14 * s - pad + 2 * s, s)

	// Where he is: the part of the meadow and what is found there.
	if g.in_region {
		r := REGIONS[g.region]
		fade := clamp(g.region_t * 2, 0, 1)
		name_color := UI_YELLOW
		name_color.a = u8(255 * fade)
		about_color := UI_WHITE
		about_color.a = u8(255 * fade)
		label(r.name, sw - ui_text_width(r.name, 22 * s) - 20 * s, 16 * s, 22 * s, name_color)
		label(r.about, sw - ui_text_width(r.about, 16 * s) - 20 * s, 44 * s, 16 * s, about_color)
	}

	// What the action buttons do right now.
	if p.fail == .None {
		action: cstring = nil
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
			action = "E: put it in the sack"
		} else if oven_in_reach(p.pos, prosio_radius(p.kg)) {
			action = g.oven.ready ? "E: take it out of the oven" : (g.oven.baking ? "Baking... wait for the ding!" : "E: bake something")
		} else if _, found := grab_target(); found {
			action = "F: grab"
		}
		if action != nil {
			label_centred(action, sw / 2, sh - 64 * s, 20 * s, UI_YELLOW)
		}
	}
	label_centred(CONTROLS, sw / 2, sh - 34 * s, 16 * s)

	if p.fail != .None && p.fail_t > 0.8 {
		ui_rect(0, 0, sw, sh, {0, 0, 0, 110})
		title: cstring = "PROSIO FAINTED!"
		line: cstring = "Too thin... he needed to eat more."
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
	return ui_format("PIXELS: %d / 6", i32(pixel_level + 1))
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
		label_centred("the pig who gathers, bakes and bumps", sw / 2, top + size + 4 * s, 24 * s, UI_YELLOW)
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

	label_centred("Choose: UP / DOWN     Select: ENTER or SPACE     Pixel size any time: 1 to 6", sw / 2, sh - 110 * s, 20 * s, UI_YELLOW)
	if scene == .Menu {
		// While paused, the game's own controls line is already showing.
		label_centred(CONTROLS, sw / 2, sh - 70 * s, 16 * s)
	}
}
