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
UI_BRUISE :: Color{132, 84, 160, 255}

REGION_ABOUT_TIME :: f32(5) // seconds the line about a part of the meadow shows after he gets there
CONTROLS :: "Move: {Move}   Bump: {Bump}   Jump: {Jump}   Sprint: {Sprint}   Grab / throw: {Grab}   Pick up / use / drink: {Action}   Sack: {Sack}   Eat: {Eat}   Sack, outfit, map: {Bag}   Menu: {Menu}"

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
			action = open ? "{Action}: shut the gate     drag it through first!" : "{Action}: open the gate, to bring it through"
		case open:
			action = "{Action}: shut the gate     {Grab}: take it down"
		case:
			action = "{Action}: open the gate     {Grab}: take it down"
		}
	} else if p.carry != .Nothing {
		// What F will do with an animal: throw it, or, too heavy or too
		// tired for that, put it down.
		too_heavy := p.carry_kg > p.kg * LIFT_LIMIT * strength()
		let_go: cstring = too_heavy ? "{Grab}: let go" : (p.stamina < throw_cost() ? "{Grab}: put it down (too tired to throw)" : "{Grab}: put it down     hold {Grab}, let go: throw")
		at_fence := false
		if p.carry == .Enemy && p.lift_t <= 0 {
			what, _, _ := built_in_reach()
			at_fence = what == .Fence
		}
		switch {
		case at_fence && ENEMY_KG[g.enemies[p.carry_index].kind] <= hoist_most():
			action = "{Grab}: lift it over the fence"
		case at_fence:
			action = "Too heavy to lift over the fence: it needs a gate     {Grab}: let go" 
		case p.carry == .Enemy && g.enemies[p.carry_index].ko && MEAT_FROM[g.enemies[p.carry_index].kind] > 0:
			// A body: it wants chopping up, at the block by the fire.
			if _, at_fire := fire_in_reach(p.pos, prosio_radius(p.kg) + 1.2); at_fire {
				action = ui_format_name("{Action}: chop it into meat     %s", let_go)
			} else if g.camp_up {
				action = ui_format_name(too_heavy ? "Drag it to a fire to chop it     %s" : "Drag it to a fire to chop it     {Bump}: bash with it     %s", let_go)
			} else {
				action = ui_format_name(too_heavy ? "Drag it to the fire by the pond     %s" : "Drag it to the fire by the pond     {Bump}: bash with it     %s", let_go)
			}
		case p.carry == .Enemy && too_heavy:
			action = "Too heavy to swing!   {Bump}: heave     {Grab}: let go"
		case p.carry == .Enemy && g.enemies[p.carry_index].kind == .Goat:
			action = ui_format_name("{Action}: milk it     {Bump}: bash with it     %s", let_go)
		case p.carry == .Enemy:
			action = ui_format_name("{Bump}: bash with it!     %s", let_go)
		case p.lift_t > 0:
			action = "Lifting..."
		case:
			action = "{Grab}: put it down     hold {Grab}, let go: throw"
		}
	} else if goat := licking_goat(); goat != nil && goat.milk_t <= 0 {
		action = goat.licking ? "{Action}: milk the goat while it licks" : "{Action}: milk the goat"
	} else if food := food_in_reach(p.pos, prosio_radius(p.kg) + 0.75); food != nil && food.kind == .Wood {
		action = "{Action}: pick up the branch (wood for fires and for building)"
	} else if food != nil && food.kind == .Spear {
		action = "{Action}: pick up the spear"
	} else if food != nil {
		// What it is worth now: less if it has not finished growing.
		action = ui_format(food.grow < 0.95 && !food.fallen ? "{Action}: pick it now (%d kcal, still growing)" : "{Action}: pick it (%d kcal)", i32(food_kcal(food)))
	} else if bush := bush_in_reach(p.pos, prosio_radius(p.kg) + 0.6); bush != nil {
		if bush.kind == .Hive {
			action = "{Action}: take the honey (300 kcal)"
		} else if bush.kind == .Salt_Rock {
			action = "{Action}: break off a lump of rock salt"
		} else if bush.kind == .Pebbles {
			action = "{Action}: pick up pebbles (for throwing)"
		} else {
			action = ui_format(bush.ripe < 0.95 ? "{Action}: pick berries now (%d kcal, still ripening)" : "{Action}: pick berries (%d kcal)", i32(bush_kcal(bush)))
		}
	} else if l := larder_first(); l >= 0 {
		action = larder_empty(&g.larders[l]) ? "{Action}: open the larder     {Grab}: take it down" : "{Action}: open the larder"
	} else if at, near := station_near(p.pos, prosio_radius(p.kg)); near {
		o := g.stations[at]
		switch at {
		case .Oven:
			action = o.ready ? "{Action}: take it out of the oven" : (o.baking ? "Baking... wait for the ding!" : "{Action}: bake something")
		case .Fire:
			action = o.ready ? "{Action}: take it off the fire" : (o.baking ? "Cooking... wait for the sizzle!" : "{Action}: cook something")
		case .Camp:
			action = o.ready ? "{Action}: take it off the fire" : (o.baking ? "Cooking... wait for the sizzle!" : "{Action}: cook something     {Grab}: pack it up")
		case .Churn:
			action = o.ready ? "{Action}: take it from the stool" : (o.baking ? "Churning... nearly there!" : "{Action}: churn some milk")
		case .Bench:
			action = o.ready ? "{Action}: take it off the workbench" : (o.baking ? "Building... nearly done!" : "{Action}: build something of wood")
		}
	} else if mill_in_reach(p.pos, prosio_radius(p.kg)) {
		switch {
		case g.mill.ready > 0:
			action = "{Action}: take the flour"
		case g.mill.grinding > 0:
			action = "Grinding... wait for the flour"
		case p.sack[.Wheat] > 0:
			action = "{Action}: grind the wheat"
		case:
			action = "The mill grinds wheat into flour"
		}
	} else if pond_in_reach(p.pos, prosio_radius(p.kg)) {
		if rod_chosen() {
			action = fish_in_reach() ? "{Action}: drink     {Grab}: cast the rod, a fish is near enough!" : "{Action}: drink     {Grab}: cast the rod (no fish near enough yet)"
		} else {
			action = fish_in_reach() ? "{Action}: drink     {Grab}: grab that fish!" : "{Action}: drink     {Grab}: grab for a fish (stand still and they come)"
		}
	} else if _, in_reach := grab_target(); !in_reach && throwable_chosen() {
		action = p.winding ? "Let go of {Grab}: throw     {Aim}: aim at something else" : (p.sack_sel == .Spear ? "Hold {Grab}, let go: throw the spear" : "Hold {Grab}, let go: throw a pebble")
	} else if target, found := grab_target(); found {
		if target.kind == .Rock {
			action = "{Grab}: lift the rock"
		} else if e := &g.enemies[target.index]; e.state == .Dead {
			action = "{Grab}: take it by the leg"
		} else {
			GRAB := [Enemy_Kind]cstring{.Turkey = "{Grab}: grab the turkey", .Goat = "{Grab}: grab the goat", .Billy = "{Grab}: grab the billy goat", .Fox = "{Grab}: grab the fox"}
			action = GRAB[e.kind]
		}
	} else if (p.sack_sel == .Fence || p.sack_sel == .Gate) && p.sack[p.sack_sel] > 0 {
		// Q puts a piece up where the mark on the ground is; F takes one down.
		ok, _ := fence_fits(fence_ahead())
		what, _, _ := built_in_reach()
		put: cstring = p.sack_sel == .Gate ? "{Eat}: put the gate up here" : "{Eat}: put a piece of fence up here"
		switch {
		case ok && what == .Fence:
			action = ui_format_name("%s     {Grab}: take this piece down", put)
		case ok:
			action = put
		case what == .Fence:
			action = "{Grab}: take this piece of fence down"
		case what == .Scarecrow:
			action = "{Grab}: take the scarecrow down"
		}
	} else if p.sack_sel == .Scarecrow && p.sack[.Scarecrow] > 0 {
		action = "{Eat}: stand the scarecrow up here"
	} else if p.sack_sel == .Larder && p.sack[.Larder] > 0 && larder_in_reach() < 0 {
		action = "{Eat}: stand the larder up here"
	} else if p.sack_sel == .Campfire && p.sack[.Campfire] > 0 && !g.camp_up {
		action = "{Eat}: set up my campfire here"
	} else if what, _, which := built_in_reach(); what != .Nothing {
		switch {
		case what == .Larder:
			action = larder_empty(&g.larders[which]) ? "{Action}: open the larder     {Grab}: take it down" : "{Action}: open the larder"
		case what == .Scarecrow:
			action = "{Grab}: take the scarecrow down"
		case can_clear_fence():
			action = "{Jump}: jump over the fence     {Grab}: take this piece down"
		case g.prosio.carry == .Enemy:
			action = "Throw it over the fence: hold {Grab}, let go"
		case:
			action = "Too heavy to jump the fence!     {Grab}: take this piece down"
		}
	}
	if action == nil && p.carry == .Nothing {
		if _, at_tree := tree_in_front(facing_dir(p.facing)); at_tree {
			action = "{Bump}: shake the tree"
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
		pos := world_to_screen({p.pos.x, p.height + 2.6 * PROSIO_SIZE, p.pos.y})
		w := ui_text_width(p.bubble, size) + 22 * s
		ui_round_rect(pos.x - w / 2, pos.y - size, w, size + 13 * s, UI_WHITE)
		ui_text(p.bubble, pos.x - w / 2 + 11 * s, pos.y - size + 6.5 * s, size, UI_DARK)
	}

	// What he is made of, and beside it the sack.
	x, y := 18 * s, 14 * s
	panel_w, _ := draw_body_panel(x, y, s)
	draw_sack(x + panel_w + 12 * s, 14 * s - 9 * s + 2 * s, s)

	// Where he is: the part of the meadow, and, for a few seconds after he
	// gets there, what is found there.
	if g.in_region {
		r := REGIONS[g.region]
		fade := clamp(g.region_t * 2, 0, 1)
		name_color := UI_YELLOW
		name_color.a = u8(255 * fade)
		about_color := UI_WHITE
		about_color.a = u8(255 * fade * clamp(REGION_ABOUT_TIME - g.region_t, 0, 1))
		label(r.name, sw - ui_text_width(r.name, 22 * s) - 20 * s, 16 * s, 22 * s, name_color)
		label(r.about, sw - ui_text_width(r.about, 16 * s) - 20 * s, 44 * s, 16 * s, about_color)
	}

	// What the action buttons do right now.
	if action := prompt_text(); action != nil {
		label_centred(action, sw / 2, sh - 46 * s, 20 * s, UI_YELLOW)
	}

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
		if p.fail == .Beaten {
			title = "KNOCKED OUT!"
			line = "Bruised all over... the animals got the better of him."
		}
		label_centred(title, sw / 2, sh * 0.56, 64 * s, UI_RED)
		label_centred(line, sw / 2, sh * 0.56 + 76 * s, 28 * s)
		label_centred("Press {Restart} to wake up at home", sw / 2, sh * 0.56 + 124 * s, 26 * s, UI_YELLOW)
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

	label_centred("Choose: UP / DOWN     Select: {Confirm}     Pixel size any time: 1 to 6", sw / 2, sh - 110 * s, 20 * s, UI_YELLOW)
	// What every button does (in the game only the line about what the
	// buttons would do just there shows).
	label_centred(CONTROLS, sw / 2, sh - 70 * s, 16 * s)
}
