package game

import "core:math"

Larder :: struct {
	used:  bool,
	round: int, // its round in g.rounds, for bumping into
	pos:   Vec2,
	stock: [Item]int,
	kcal:  [Item]f32,
	fresh: [Item]f32,
}

// Spoils a store of things by this many seconds' worth (slower times as
// slowly). Says what has gone rotten and been thrown out, if anything.
spoil :: proc(stock: ^[Item]int, kcal, fresh: ^[Item]f32, seconds, slower: f32) -> (rotten: Item, any: bool) {
	for item in Item {
		half := SPOIL_HALF[item]
		if stock[item] <= 0 || half <= 0 {
			continue
		}
		keep := math.pow(0.5, seconds / (half * slower))
		kcal[item] *= keep
		fresh[item] *= keep
		if fresh[item] < ROTTEN {
			stock[item], kcal[item], fresh[item] = 0, 0, 0
			rotten, any = item, true
		}
	}
	return
}

update_spoil :: proc(dt: f32) {
	p := &g.prosio
	p.spoil_t += dt
	if p.spoil_t < SPOIL_EVERY {
		return
	}
	seconds := p.spoil_t
	p.spoil_t = 0
	if rotten, any := spoil(&p.sack, &p.sack_kcal, &p.sack_fresh, seconds, 1); any {
		say_filled(fill(TEXT.went_bad, {"thing", TEXT.item_name[rotten]}))
		sack_step(0)
	}
	for &l in g.larders {
		if l.used {
			spoil(&l.stock, &l.kcal, &l.fresh, seconds, LARDER_KEEPS)
		}
	}
}

// How fresh a store of something is, in a word or two (nil for what keeps).
fresh_word :: proc(item: Item, fresh: f32) -> cstring {
	switch {
	case SPOIL_HALF[item] <= 0:
		return nil
	case fresh >= STALE:
		return TEXT.fresh
	case fresh >= 0.5:
		return TEXT.a_bit_stale
	}
	return TEXT.going_off
}

// Room taken up in a larder.
larder_litres :: proc(l: ^Larder) -> (sum: f32) {
	for count, item in l.stock {
		sum += f32(count) * ITEM_LITRES[item]
	}
	return
}

larder_empty :: proc(l: ^Larder) -> bool {
	for count in l.stock {
		if count > 0 {
			return false
		}
	}
	return true
}

larder_count :: proc() -> (n: int) {
	for l in g.larders {
		n += l.used ? 1 : 0
	}
	return
}

// Stands a larder here. False if there are as many as there can be.
add_larder :: proc(at: Vec2) -> bool {
	for &l in g.larders {
		if l.used {
			continue
		}
		round := -1
		for &rd, i in g.rounds[:g.round_count] {
			if rd.kind == .Larder && rd.r <= 0 {
				rd.pos, rd.r = at, LARDER_RADIUS
				round = i
				break
			}
		}
		if round < 0 {
			round = add_round(at, LARDER_RADIUS, .Larder)
		}
		if round < 0 {
			return false
		}
		l = {used = true, round = round, pos = at}
		return true
	}
	return false
}

remove_larder :: proc(l: ^Larder) {
	g.rounds[l.round].r = 0
	l^ = {}
}

// The larder he is standing at, if any.
larder_in_reach :: proc() -> int {
	p := &g.prosio
	for l, i in g.larders {
		if l.used && length2(l.pos - p.pos) - prosio_radius(p.kg) - LARDER_RADIUS < BUILT_REACH + 0.2 {
			return i
		}
	}
	return -1
}

// The larder E would open: one in reach and nearer than any station in
// reach (a larder may well stand by the workbench). -1 if none.
larder_first :: proc() -> int {
	p := &g.prosio
	l := larder_in_reach()
	if l < 0 {
		return -1
	}
	if at, near := station_near(p.pos, prosio_radius(p.kg)); near && length2(g.stations[at].pos - p.pos) < length2(g.larders[l].pos - p.pos) {
		return -1
	}
	return l
}

// Moves up to n of something between the sack and a larder (into it if
// in is true). Says how many went.
larder_move :: proc(l: ^Larder, item: Item, n: int, into: bool) -> int {
	p := &g.prosio
	moved := 0
	for _ in 0 ..< n {
		if into {
			if p.sack[item] <= 0 || larder_litres(l) + ITEM_LITRES[item] > LARDER_LITRES + 0.001 {
				break
			}
			fresh := p.sack_fresh[item]
			kcal := sack_take(item, 1)
			l.fresh[item] = (l.fresh[item] * f32(l.stock[item]) + fresh) / f32(l.stock[item] + 1)
			l.stock[item] += 1
			l.kcal[item] += kcal
		} else {
			if l.stock[item] <= 0 || sack_room(item) < 1 {
				break
			}
			kcal := l.kcal[item] / f32(l.stock[item])
			l.kcal[item] -= kcal
			l.stock[item] -= 1
			sack_add(item, kcal, l.fresh[item])
			if l.stock[item] == 0 {
				l.kcal[item], l.fresh[item] = 0, 0
			}
		}
		moved += 1
	}
	return moved
}

// The larder's menu: one row for each thing in the sack or the larder.
larder_open: int
larder_choice: int

open_larder :: proc(i: int) {
	p := &g.prosio
	to := g.larders[i].pos - p.pos
	p.facing = math.atan2(to.x, to.y)
	larder_open = i
	larder_choice = 0
	scene = .Larder
}

larder_rows :: proc(l: ^Larder, buf: ^[len(Item)]Item) -> []Item {
	n := 0
	for item in Item {
		if g.prosio.sack[item] > 0 || l.stock[item] > 0 {
			buf[n] = item
			n += 1
		}
	}
	return buf[:n]
}

update_larder_menu :: proc() {
	l := &g.larders[larder_open]
	if button_pressed(.Menu) || button_pressed(.Bag) || button_pressed(.Grab) || !l.used {
		scene = .Playing
		return
	}
	buf: [len(Item)]Item
	rows := larder_rows(l, &buf)
	if len(rows) == 0 {
		return
	}
	larder_choice = clamp(larder_choice, 0, len(rows) - 1)
	if button_pressed(.Down) {larder_choice = (larder_choice + 1) % len(rows)}
	if button_pressed(.Up) {larder_choice = (larder_choice + len(rows) - 1) % len(rows)}
	item := rows[larder_choice]
	switch {
	case button_pressed(.Right):
		if larder_move(l, item, 1, true) == 0 && g.prosio.sack[item] > 0 {
			answer(TEXT.larder_full)
		}
	case button_pressed(.Left):
		if larder_move(l, item, 1, false) == 0 && l.stock[item] > 0 {
			answer(TEXT.sack_full)
		}
	case button_pressed(.Confirm) || button_pressed(.Action):
		// All of it in, or (with none in the sack) all of it out.
		if g.prosio.sack[item] > 0 {
			larder_move(l, item, g.prosio.sack[item], true)
		} else {
			larder_move(l, item, l.stock[item], false)
		}
	}
	sack_step(0)
}

draw_larder_menu :: proc() {
	sw, sh := screen_size()
	s := min(sw / 1280, sh / 720)
	l := &g.larders[larder_open]
	ui_rect(0, 0, sw, sh, {10, 24, 20, 130})
	buf: [len(Item)]Item
	rows := larder_rows(l, &buf)
	row := 44 * s
	shown := min(len(rows), 10)
	pw, ph := 760 * s, 190 * s + f32(max(shown, 1)) * row
	px, py := sw / 2 - pw / 2, sh / 2 - ph / 2
	ui_round_rect(px, py, pw, ph, {74, 46, 38, 240}, 0.08)
	label_centred(TEXT.larder_title, sw / 2, py + 16 * s, 40 * s, UI_ORANGE)
	label_centred(TEXT.larder_about, sw / 2, py + 62 * s, 18 * s, UI_YELLOW)
	GREY :: Color{220, 200, 180, 255}
	top := py + 100 * s
	label(TEXT.in_the_sack, px + 290 * s, top, 15 * s, GREY)
	label(TEXT.in_the_larder, px + 470 * s, top, 15 * s, GREY)
	label(fill(TEXT.sack_percent_full, {"percent", int(i32(math.round(sack_full() * 100)))}), px + 290 * s, top + 18 * s, 13 * s, GREY)
	label(fill(TEXT.larder_percent_full, {"percent", int(i32(math.round(larder_litres(l) / LARDER_LITRES * 100)))}), px + 470 * s, top + 18 * s, 13 * s, GREY)
	if len(rows) == 0 {
		label_centred(TEXT.nothing_in_either, sw / 2, top + 50 * s, 18 * s, UI_WHITE)
	}
	first := clamp(larder_choice - shown + 1, 0, max(len(rows) - shown, 0))
	y := top + 42 * s
	for k in 0 ..< shown {
		i := first + k
		item := rows[i]
		if i == larder_choice {
			ui_round_rect(px + 18 * s, y - 4 * s, pw - 36 * s, row - 4 * s, {118, 78, 60, 255}, 0.3)
		}
		ui_round_rect(px + 30 * s, y, 32 * s, 32 * s, SACK_BOX, 0.2)
		draw_icon(item, px + 33 * s, y + 3 * s, 26 * s)
		label(TEXT.item_name[item], px + 74 * s, y + 6 * s, 18 * s)
		label(number_text(int(i32(g.prosio.sack[item]))), px + 300 * s, y + 6 * s, 20 * s, g.prosio.sack[item] > 0 ? UI_WHITE : GREY)
		if word := fresh_word(item, g.prosio.sack_fresh[item]); word != nil && g.prosio.sack[item] > 0 {
			label(word, px + 340 * s, y + 9 * s, 13 * s, g.prosio.sack_fresh[item] < STALE ? UI_ORANGE : GREY)
		}
		label(number_text(int(i32(l.stock[item]))), px + 480 * s, y + 6 * s, 20 * s, l.stock[item] > 0 ? UI_WHITE : GREY)
		if word := fresh_word(item, l.fresh[item]); word != nil && l.stock[item] > 0 {
			label(word, px + 520 * s, y + 9 * s, 13 * s, l.fresh[item] < STALE ? UI_ORANGE : GREY)
		}
		y += row
	}
	label_fitted(TEXT.larder_help, sw / 2, py + ph - 40 * s, 15 * s, pw - 40 * s, UI_YELLOW)
}

// A larder: a wooden cupboard on short legs under a little roof, with a
// door and a latch, and a bag of salt at its foot.
draw_larder :: proc(m: Mat4) {
	for x in ([2]f32{-0.36, 0.36}) {
		for z in ([2]f32{-0.22, 0.22}) {
			box(m, {x, 0.12, z}, {0.08, 0.24, 0.08}, PLANK_DARK)
		}
	}
	box(m, {0, 0.66, 0}, {0.86, 0.84, 0.56}, COLOR_PLANK)
	box(m, {0, 0.66, 0.29}, {0.62, 0.66, 0.04}, PLANK_DARK) // the door
	box(m, {0.22, 0.66, 0.32}, {0.05, 0.12, 0.04}, {70, 70, 76, 255}) // the latch
	for side in ([2]f32{-1, 1}) {
		box(m * translate({side * 0.24, 1.17, 0}) * rot_z(-side * 0.5), {}, {0.6, 0.06, 0.7}, PLANK_DARK)
	}
	ball(m, {0.58, 0.16, 0.12}, {0.16, 0.18, 0.14}, {236, 232, 222, 255}) // salt, against the damp
}
