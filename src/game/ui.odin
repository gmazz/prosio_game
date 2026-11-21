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

CONTROLS :: "Move: WASD   Bump: SPACE   Jump: J   Sprint: SHIFT   Grab / throw: F   Pick up / use / drink: E   Sack: Z C   Eat: Q   Sack, outfit, map: M   Menu: ESC"

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

	// With too few vitamins his sight dims: the dark closes in from the edges.
	if lacks(.Vitamins) {
		ui_vignette(205, 2)
	} else {
		ui_vignette(35)
	}

	// Signs in the world.
	for o, at in g.stations {
		if !on_screen(o.pos, 4) {
			continue
		}
		top := Vec3{o.pos.x, at == .Oven ? 2.9 : 2.5, o.pos.y}
		switch {
		case o.ready:
			pulse := 1 + 0.08 * math.sin(g.time * 6)
			world_label("READY!", top, 22 * s * pulse, UI_GREEN)
		case o.baking:
			world_label(ui_format(STATION_BUSY[at], i32(math.ceil(o.bake_t))), top, 18 * s, UI_ORANGE)
		case:
			world_label(STATION_LABEL[at], top, 16 * s, UI_YELLOW)
		}
	}
	mill_top := Vec3{g.mill.pos.x, 4.6, g.mill.pos.y}
	switch {
	case g.mill.ready > 0 && g.mill.grinding == 0:
		pulse := 1 + 0.08 * math.sin(g.time * 6)
		world_label("FLOUR READY!", mill_top, 20 * s * pulse, UI_GREEN)
	case g.mill.grinding > 0:
		world_label(ui_format("GRINDING... %d", i32(g.mill.grinding)), mill_top, 18 * s, UI_ORANGE)
	case:
		world_label("MILL", mill_top, 16 * s, UI_YELLOW)
	}

	// Speech bubble.
	if p.bubble_t > 0 && p.fail == .None {
		size := 20 * s
		pos := world_to_screen({p.pos.x, p.height + 2.6, p.pos.y})
		w := ui_text_width(p.bubble, size) + 22 * s
		ui_round_rect(pos.x - w / 2, pos.y - size, w, size + 13 * s, UI_WHITE)
		ui_text(p.bubble, pos.x - w / 2 + 11 * s, pos.y - size + 6.5 * s, size, UI_DARK)
	}

	// What he is made of, and beside it the sack.
	x, y := 18 * s, 14 * s
	panel_w, _ := draw_body_panel(x, y, s)
	draw_sack(x + panel_w + 12 * s, 14 * s - 9 * s + 2 * s, s)

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
			case p.carry == .Enemy && g.enemies[p.carry_index].ko && MEAT_FROM[g.enemies[p.carry_index].kind] > 0:
				// A body: it wants chopping up, at the block by the fire.
				if station_in_reach(.Fire, p.pos, prosio_radius(p.kg) + 1.2) {
					action = "E: chop it into meat"
				} else {
					action = "Drag it to the fire by the pond     SPACE: bash with it     F: throw it"
				}
			case p.carry == .Enemy && p.carry_kg > p.kg * LIFT_LIMIT * strength():
				action = "Too heavy to swing!   SPACE: heave     F: let go"
			case p.carry == .Enemy && g.enemies[p.carry_index].kind == .Goat:
				action = "E: milk it     SPACE: bash with it     F: throw it"
			case p.carry == .Enemy:
				action = "SPACE: bash with it!     F: throw it"
			case p.lift_t > 0:
				action = "Lifting..."
			case:
				action = "F: throw it down"
			}
		} else if food := food_in_reach(p.pos, prosio_radius(p.kg) + 0.75); food != nil {
			// What it is worth now: less if it has not finished growing.
			action = ui_format(food.grow < 0.95 && !food.fallen ? "E: pick it now (%d kcal, still growing)" : "E: pick it (%d kcal)", i32(food_kcal(food)))
		} else if bush := bush_in_reach(p.pos, prosio_radius(p.kg) + 0.6); bush != nil {
			if bush.kind == .Hive {
				action = "E: take the honey (300 kcal)"
			} else if bush.kind == .Salt_Rock {
				action = "E: break off a lump of rock salt"
			} else {
				action = ui_format(bush.ripe < 0.95 ? "E: pick berries now (%d kcal, still ripening)" : "E: pick berries (%d kcal)", i32(bush_kcal(bush)))
			}
		} else if at, near := station_near(p.pos, prosio_radius(p.kg)); near {
			o := g.stations[at]
			switch at {
			case .Oven:
				action = o.ready ? "E: take it out of the oven" : (o.baking ? "Baking... wait for the ding!" : "E: bake something")
			case .Fire:
				action = o.ready ? "E: take it off the fire" : (o.baking ? "Cooking... wait for the sizzle!" : "E: cook something")
			case .Churn:
				action = o.ready ? "E: take it from the stool" : (o.baking ? "Churning... nearly there!" : "E: churn some milk")
			}
		} else if mill_in_reach(p.pos, prosio_radius(p.kg)) {
			switch {
			case g.mill.ready > 0:
				action = "E: take the flour"
			case g.mill.grinding > 0:
				action = "Grinding... wait for the flour"
			case p.sack[.Wheat] > 0:
				action = "E: grind the wheat"
			case:
				action = "The mill grinds wheat into flour"
			}
		} else if pond_in_reach(p.pos, prosio_radius(p.kg)) {
			action = fish_in_reach() ? "E: drink     F: grab that fish!" : "E: drink     F: grab for a fish (stand still and they come)"
		} else if target, found := grab_target(); found {
			action = target.kind == .Enemy && g.enemies[target.index].state == .Dead ? "F: take it by the leg" : "F: grab"
		}
		if action != nil {
			label_centred(action, sw / 2, sh - 64 * s, 20 * s, UI_YELLOW)
		}
	}
	label_centred(CONTROLS, sw / 2, sh - 34 * s, 16 * s)

	if p.fail != .None && p.fail_t > 0.8 {
		ui_rect(0, 0, sw, sh, {0, 0, 0, 110})
		title: cstring = "PROSIO FAINTED!"
		line: cstring = "No fat and no carbs left... nothing to keep him going."
		if p.fail == .Heart_Attack {
			title = "HEART ATTACK!"
			line = "Too heavy... his heart could not keep up."
		}
		if p.fail == .Diet {
			title, line = ending().title, ending().line
		}
		label_centred(title, sw / 2, sh * 0.56, 64 * s, UI_RED)
		label_centred(line, sw / 2, sh * 0.56 + 76 * s, 28 * s)
		label_centred("Press ENTER to wake up at home", sw / 2, sh * 0.56 + 124 * s, 26 * s, UI_YELLOW)
		label_centred("(his sack is lost, and some of his muscle; what he has learnt stays)", sw / 2, sh * 0.56 + 160 * s, 18 * s)
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
	.Restart      = "START OVER",
	.Exit_To_Menu = "EXIT TO MENU",
	.Quit         = "QUIT",
}

look_text :: proc() -> cstring {
	return ui_format("PIXELS: %d / 6", i32(pixel_level + 1))
}

// With a saved Prosio, the main menu carries on with him, or starts over
// with a new one. (The browser has nothing to quit to.)
MENU_MAIN := [?]Menu_Item{.Play, .Look, .Restart, .Quit}
MENU_PAUSE := [?]Menu_Item{.Resume, .Look, .Restart, .Exit_To_Menu}

menu_items :: proc() -> []Menu_Item {
	if scene == .Paused {
		return MENU_PAUSE[:]
	}
	@(static) list: [len(MENU_MAIN)]Menu_Item
	n := 0
	for item in MENU_MAIN {
		if (item == .Restart && !has_save) || (item == .Quit && IS_WEB) {
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
		if item == .Play && has_save {
			text = "CONTINUE"
		}
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
