package game

import "core:math"

Lab :: struct {
	visible, portrait, dragging: bool,
	drag: Lab_Slider,
	zoom: f32,
	notice_until: f32,
}

Lab_Slider :: enum {Fat, Arms, Legs, Lungs, Zoom}
Lab_Action :: enum {
	Goat, Billy, Fox,
	Turkey, Fallen_Goat, Apple,
	Rock, Eat_Pumpkin, Wind,
	Hiccup, Tipsy, Portrait,
	Pond, Oven, Reset,
}

start_lab :: proc() {
	g.lab = {visible = true, zoom = 1}
	// Leave room for repeatable spawns. The rest of the world remains playable.
	g.enemy_count = 0
	lab_act(.Goat)
	lab_act(.Fox)
	for need in recipe_for(.Apple_Pie).needs {
		missing := max(0, need.count - g.prosio.sack[need.item])
		for _ in 0 ..< missing {
			sack_add(need.item, item_kcal(need.item))
		}
	}
	for item in ([?]Item{.Rod, .Fence, .Spear}) {
		if g.prosio.sack[item] == 0 {
			sack_add(item, item_kcal(item))
		}
	}
	g.prosio.sack_sel = .Apple
}

lab_spot :: proc(radius: f32, origin: Vec2, distance: f32) -> (Vec2, bool) {
	for i in 0 ..< LAB_PLACEMENT_STEPS {
		angle := g.prosio.facing + f32((i + 1) / 2) * f32(1 - 2 * (i % 2)) * math.TAU / LAB_PLACEMENT_STEPS
		spot := origin + facing_dir(angle) * distance
		probe := spot
		hit, _ := collide_static(&probe, radius, 0, true)
		if hit || in_pond(spot) || beyond_edge(spot) + radius >= 0 {
			continue
		}
		occupied := false
		for e in g.enemies[:g.enemy_count] {
			if length2(spot - e.pos) < radius + ENEMY_RADIUS[e.kind] {
				occupied = true
				break
			}
		}
		if !occupied {
			return spot, true
		}
	}
	return {}, false
}

// The panel changes test setup. The simulation still handles the animals,
// grip, terrain, movement, cooking and dietary reactions.
lab_act :: proc(action: Lab_Action) -> bool {
	if !g.opts.lab {
		return false
	}
	p := &g.prosio
	switch action {
	case .Goat, .Billy, .Fox, .Turkey, .Fallen_Goat:
		if g.enemy_count == len(g.enemies) { return false }
		kind := Enemy_Kind.Goat
		#partial switch action {
		case .Billy: kind = .Billy
		case .Fox: kind = .Fox
		case .Turkey: kind = .Turkey
		}
		r := ENEMY_RADIUS[kind]
		pos, ok := lab_spot(r, p.pos, prosio_radius(p.kg) + r + LAB_PLACEMENT_GAP)
		if !ok { return false }
		add_enemy(kind, pos)
		if action == .Fallen_Goat {
			e := &g.enemies[g.enemy_count - 1]
			e.state, e.ko, e.health, e.body_t = .Dead, true, 0, BODY_LIFE
		}
	case .Apple, .Rock:
		r := action == .Rock ? LAB_ROCK_RADIUS : LAB_APPLE_RADIUS
		pos, ok := lab_spot(r, p.pos, prosio_radius(p.kg) + r + LAB_PLACEMENT_GAP)
		if !ok { return false }
		if action == .Rock {
			return add_round(pos, r, .Rock) >= 0
		}
		item := add_food(.Apple, pos)
		if item == nil { return false }
		item.fallen, item.life, item.size = true, APPLE_LIFE, 1
	case .Eat_Pumpkin:
		if p.fail != .None || p.eat_t > 0 || p.carry != .Nothing { return false }
		if p.sack[.Pumpkin] == 0 { sack_add(.Pumpkin, item_kcal(.Pumpkin)) }
		p.sack_sel = .Pumpkin
		eat_from_sack()
	case .Wind, .Hiccup, .Tipsy:
		if p.fail != .None || p.airborne || (action == .Hiccup && p.carry != .Nothing) { return false }
		#partial switch action {
		case .Wind: pass_gas()
		case .Hiccup: start_hiccup()
		case .Tipsy: p.tipsy_pose_t = PROSIO_REACTION_TIME.z
		}
	case .Portrait:
		g.lab.portrait = !g.lab.portrait
	case .Pond, .Oven:
		if p.carry != .Nothing || p.fail != .None { return false }
		centre := action == .Pond ? POND : g.stations[.Oven].pos
		clearance := action == .Pond ? POND_RADIUS : STATION_RADIUS[.Oven]
		r := prosio_radius(p.kg)
		pos, ok := lab_spot(r, centre, clearance + r + LAB_PLACEMENT_GAP)
		if !ok { return false }
		p.pos, p.vel, p.height, p.vy, p.airborne = pos, {}, 0, 0, false
		g.camera = pos
		explore(pos)
	case .Reset:
		new_game()
	}
	return true
}

lab_parameter :: proc(row: Lab_Slider) -> f32 {
	p := &g.prosio
	switch row {
	case .Fat: return p.fat / FAT_MAX
	case .Arms: return (p.trait[.Arms] + 1) * 0.5
	case .Legs: return (p.trait[.Legs] + 1) * 0.5
	case .Lungs: return p.trait[.Lungs]
	case .Zoom: return (g.lab.zoom - LAB_ZOOM.x) / (LAB_ZOOM.y - LAB_ZOOM.x)
	}
	return 0
}

lab_adjust :: proc(row: Lab_Slider, fraction: f32) {
	if !g.opts.lab { return }
	p := &g.prosio
	value := clamp(fraction, 0, 1)
	switch row {
	case .Fat: p.fat = lerp(1, FAT_MAX - 1, value)
	case .Arms: p.trait[.Arms] = lerp(-1, 1, value)
	case .Legs: p.trait[.Legs] = lerp(-1, 1, value)
	case .Lungs: p.trait[.Lungs] = value
	case .Zoom:
		g.lab.portrait = false
		g.lab.zoom = lerp(LAB_ZOOM.x, LAB_ZOOM.y, value)
		return
	}
	p.kg = body_kg()
	p.trait_was = p.trait
}

Lab_Layout :: struct {
	x, y, w, s: f32,
}

lab_layout :: proc() -> Lab_Layout {
	sw, sh := screen_size()
	s := min(sw / 1280, sh / 720, 1.25)
	return {sw - 372 * s, 14 * s, 358 * s, s}
}

lab_slider_rect :: proc(l: Lab_Layout, row: Lab_Slider) -> (x, y, w, h: f32) {
	return l.x + 122 * l.s, l.y + (69 + 30 * f32(row)) * l.s, 184 * l.s, 25 * l.s
}

lab_action_rect :: proc(l: Lab_Layout, action: Lab_Action) -> (x, y, w, h: f32) {
	return l.x + (12 + 113 * f32(int(action) % 3)) * l.s,
		l.y + (250 + 35 * f32(int(action) / 3)) * l.s, 108 * l.s, 30 * l.s
}

lab_hit :: proc(pos: Vec2, x, y, w, h: f32) -> bool {
	return pos.x >= x && pos.x <= x + w && pos.y >= y && pos.y <= y + h
}

update_lab :: proc() {
	pos, pressed, down, toggle := lab_pointer()
	l := lab_layout()
	if toggle || (pressed && lab_hit(pos, l.x + 284 * l.s, l.y, 74 * l.s, 38 * l.s)) {
		g.lab.visible = !g.lab.visible
		g.lab.dragging = false
		return
	}
	if !g.lab.visible { return }
	if !down { g.lab.dragging = false }
	if pressed {
		for row in Lab_Slider {
			x, y, w, h := lab_slider_rect(l, row)
			if lab_hit(pos, x, y, w, h) {
				g.lab.drag, g.lab.dragging = row, true
				break
			}
		}
		for action in Lab_Action {
			x, y, w, h := lab_action_rect(l, action)
			if lab_hit(pos, x, y, w, h) {
				if !lab_act(action) {
					g.lab.notice_until = g.time + LAB_NOTICE_SECONDS
				}
				break
			}
		}
	}
	if g.lab.dragging {
		row := g.lab.drag
		x, _, w, _ := lab_slider_rect(l, row)
		lab_adjust(row, (pos.x - x) / w)
	}
}

draw_lab :: proc() {
	pos, _, _, _ := lab_pointer()
	l := lab_layout()
	s := l.s
	bx := l.x + 284 * s
	ui_round_rect(bx, l.y, 74 * s, 38 * s, UI_DARK, 0.25)
	toggle := g.lab.visible ? TEXT.lab_hide : TEXT.lab_show
	label_centred(toggle, bx + 37 * s, l.y + 9 * s, 15 * s)
	if !g.lab.visible { return }

	ui_round_rect(l.x, l.y, 279 * s, 38 * s, UI_DARK, 0.20)
	ui_round_rect(l.x, l.y + 43 * s, l.w, 423 * s, UI_DARK, 0.08)
	label(TEXT.lab_title, l.x + 12 * s, l.y + 8 * s, 20 * s, UI_YELLOW)
	label(TEXT.lab_body, l.x + 12 * s, l.y + 49 * s, 15 * s, UI_YELLOW)
	for row in Lab_Slider {
		x, y, w, h := lab_slider_rect(l, row)
		v := clamp(lab_parameter(row), 0, 1)
		label(TEXT.lab_slider[row], l.x + 12 * s, y + 2 * s, 16 * s)
		ui_rect(x, y + h / 2 - 2 * s, w, 4 * s, BUBBLE_EDGE_COLOR)
		ui_rect(x, y + h / 2 - 2 * s, w * v, 4 * s, UI_YELLOW)
		ui_circle(x + w * v, y + h / 2, 6 * s, UI_WHITE)
		display := v * 100
		if row == .Fat { display = g.prosio.fat }
		if row == .Arms || row == .Legs { display = (2 * v - 1) * 100 }
		label(number_text(int(math.round(display))), x + w + 10 * s, y + 2 * s, 15 * s)
	}
	label(TEXT.lab_world, l.x + 12 * s, l.y + 226 * s, 15 * s, UI_YELLOW)
	for action in Lab_Action {
		x, y, w, h := lab_action_rect(l, action)
		hot := lab_hit(pos, x, y, w, h) || (action == .Portrait && g.lab.portrait)
		ui_round_rect(x, y, w, h, hot ? BUBBLE_EDGE_COLOR : UI_PANEL, 0.20)
		text := TEXT.lab_action[action]
		label_centred(text, x + w / 2, y + 6 * s, fit_size(text, 15 * s, w - 5 * s), hot ? UI_YELLOW : UI_WHITE)
	}
	note := g.lab.notice_until > g.time ? TEXT.lab_unavailable : TEXT.lab_help
	label_fitted(note, l.x + l.w / 2, l.y + 436 * s, 15 * s, l.w - 18 * s)
}
