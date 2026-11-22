package game

import "core:math"

// Wood, and what he builds of it.
//
// Fallen branches lie under the forest trees: E puts one in the sack, and
// after a while another has fallen where it lay. Wood feeds the oven and the
// cooking fire (see the recipes in kitchen.odin), and at the workbench at
// home it is made into things, each to its plan:
//
//   a piece of fence   Q puts it up across his way, on a grid of two-metre
//                      squares, so that pieces join. Nothing gets past on
//                      foot; he jumps over, if he is light enough (see
//                      clears_fences). An animal with fences all round
//                      it is penned (see fenced_in): it settles down, stays
//                      where it is put, and is there next time he plays.
//   a scarecrow        Q stands it up in front of him. Crows leave the wheat
//                      near it alone.
//   a fishing rod      chosen in the sack, F at the pond casts it: it
//                      reaches fish much further out, and does not frighten
//                      the others.
//   a spear            chosen in the sack, hold F and let go: thrown like a
//                      pebble, at what he aims at, but it goes in deep. It
//                      lies where it comes down, to be picked up again.
//
// F takes a piece of fence or a scarecrow he is standing at back into the
// sack (when there is nothing to grab, and nothing to throw is chosen).
//
// He knows every plan from the start, for now. (Later a plan may have to be
// found first: see knows in Prosio.)

WOOD_LYING :: 36 // branches under the forest trees
BENCH_PLACE :: Vec2{1.5, 7} // where the workbench stands, from home: across the yard from the oven, between the paths to the fields and the garden
BENCH_RADIUS :: f32(0.8)

// What each thing built is for, as the workbench's menu says it.
PLAN_ABOUT := #partial [Item]cstring {
	.Fence     = "Q puts it up. Animals stay in... or out.",
	.Scarecrow = "Q stands it up. Crows keep off the wheat.",
	.Rod       = "F at the pond: fish from far, no fright.",
	.Spear     = "Hold F: throw it. E picks it up again.",
	.Gate      = "Q puts it up in a fence. E opens it.",
	.Larder    = "Q stands it up. Food keeps 5 times longer.",
}

// What the sack screen says of each thing in it that is not food.
THING_ABOUT := #partial [Item]cstring {
	.Pebble    = "For throwing: choose it, then hold F and let go",
	.Wood      = "For the oven, the cooking fire and the workbench",
	.Fence     = "Q puts it up in front of you. F takes it down again",
	.Scarecrow = "Q stands it up. Crows keep off the wheat near it",
	.Rod       = "Choose it, then F at the pond: fish from far off",
	.Spear     = "Choose it, then hold F and let go. E picks it up again",
	.Gate      = "Q puts it up like a fence. E opens and shuts it, even holding an animal",
	.Larder    = "Q stands it up. E opens it: food keeps 5 times longer in it",
}

// Fences stand on the lines of a grid of squares FENCE_LEN across, which
// covers the meadow. A piece runs from a point of the grid to the next one
// east or south of it.
FENCE_LEN :: f32(2)
FENCE_W :: 100 // squares across: the meadow's width over FENCE_LEN
FENCE_H :: 70
FENCE_POINTS :: (FENCE_W + 1) * (FENCE_H + 1)
MAX_FENCES :: 240 // pieces standing at once (as many as are saved)
FENCE_TOP :: f32(0.4) // anything with its feet higher than this is over it; a jump this high takes him over (at 80 kg he jumps 0.45 m)
FENCE_THICK :: f32(0.1)
FENCE_AHEAD :: f32(0.7) // a piece goes on the line of the grid nearest to the spot this far in front of him (never under his feet),
FENCE_REACH :: f32(1.05) // so it is never further from that spot than this; and F takes down a piece that near it
BUILT_REACH :: f32(0.6) // how near he must be to a scarecrow to take it down, or to a penned goat to milk it
PEN_MOST :: 40 // squares: an enclosure bigger than this is no pen, it is a field
PEN_CHECK :: f32(1) // seconds between an animal's looks at whether it is penned

Fence_Way :: enum u8 {
	East,
	South,
}

Fence_At :: struct {
	x, y: int, // the grid point it starts at
	way:  Fence_Way,
}

// A place a piece could stand: on the grid, and not along the meadow's edge
// (its own fence is there).
fence_valid :: proc(f: Fence_At) -> bool {
	if f.way == .East {
		return f.x >= 0 && f.x < FENCE_W && f.y > 0 && f.y < FENCE_H
	}
	return f.x > 0 && f.x < FENCE_W && f.y >= 0 && f.y < FENCE_H
}

fence_there :: proc(f: Fence_At) -> bool {
	return fence_valid(f) && g.fences[f.way][f.y * (FENCE_W + 1) + f.x]
}

set_fence :: proc(f: Fence_At, there: bool) {
	if !fence_valid(f) || fence_there(f) == there {
		return
	}
	g.fences[f.way][f.y * (FENCE_W + 1) + f.x] = there
	g.gates[f.way][f.y * (FENCE_W + 1) + f.x] = 0
	g.fence_count += there ? 1 : -1
}

// A gate is a piece of fence that opens: GATE_SHUT or GATE_OPEN (0 for a
// plain piece, or none). E at it opens and shuts it, even with an animal in
// his hooves. Open, anything can go through; shut, it is fence like the
// rest. Either way it counts as fence for a pen (see fenced_in), so an
// animal in a pen stays penned while he opens the gate to bring another in.
GATE_SHUT :: u8(1)
GATE_OPEN :: u8(2)

gate_state :: proc(f: Fence_At) -> u8 {
	return fence_there(f) ? g.gates[f.way][f.y * (FENCE_W + 1) + f.x] : 0
}

set_gate :: proc(f: Fence_At, state: u8) {
	if fence_there(f) {
		g.gates[f.way][f.y * (FENCE_W + 1) + f.x] = state
	}
}

// The gate in front of him, if there is one within reach.
gate_in_reach :: proc() -> (f: Fence_At, ok: bool) {
	what, fence, _ := built_in_reach()
	if what == .Fence && gate_state(fence) != 0 {
		return fence, true
	}
	return {}, false
}

// E at a gate: open it, or shut it if nothing is standing in the way.
use_gate :: proc(f: Fence_At) {
	a, b := fence_ends(f)
	if gate_state(f) == GATE_SHUT {
		set_gate(f, GATE_OPEN)
		say("Creak... open!", 0.9)
	} else {
		p := &g.prosio
		blocked := segment_distance(p.pos, a, b) < prosio_radius(p.kg) + FENCE_THICK
		for &e in g.enemies[:g.enemy_count] {
			at := e.state == .Held ? e.chain[1].xz : e.pos
			if e.state != .Gone && segment_distance(at, a, b) < ENEMY_RADIUS[e.kind] + FENCE_THICK {
				blocked = true
			}
		}
		if blocked {
			answer("Something is in the gateway!")
			return
		}
		set_gate(f, GATE_SHUT)
		say("Clack! Shut.", 0.9)
	}
	burst({(a.x + b.x) / 2, 0.4, (a.y + b.y) / 2}, 4, 1.5, COLOR_PLANK, 0.06)
}

// He can lift an animal over a fence if it weighs no more than this.
HOIST_SHARE :: f32(0.35) // of his own weight, times the strength of his arms: 28 kg for an ordinary pig, never a goat
FENCE_HEAVY :: f32(30) // an animal heavier than this does not go over a fence even thrown: a goat comes in by the gate

hoist_most :: proc() -> f32 {
	return HOIST_SHARE * g.prosio.kg * strength()
}

// F tapped with an animal in his hooves, at a fence: he lifts it over and
// sets it down on the far side, if he can. True if the fence had to do with
// it (it is let go either way: too heavy, it is put down on his side).
hoist_over :: proc() -> bool {
	p := &g.prosio
	if p.carry != .Enemy {
		return false
	}
	what, f, _ := built_in_reach()
	if what != .Fence || gate_state(f) == GATE_OPEN {
		return false
	}
	e := &g.enemies[p.carry_index]
	if ENEMY_KG[e.kind] > hoist_most() {
		drop_carry()
		answer(ENEMY_KG[e.kind] > FENCE_HEAVY ? "Way too heavy to lift over! It needs a gate." : "Too heavy to lift over... I need stronger arms!")
		return true
	}
	a, b := fence_ends(f)
	along := b - a
	away := Vec2{-along.y, along.x} / FENCE_LEN
	if dot2(p.pos - a, away) > 0 {
		away = -away // from him, over the fence
	}
	t := clamp(dot2(p.pos - a, along) / (FENCE_LEN * FENCE_LEN), 0.2, 0.8)
	foot := a + along * t
	drop_carry()
	// Up over the top rail, and down on the far side.
	e.pos = foot + away * (ENEMY_RADIUS[e.kind] + FENCE_THICK + 0.15)
	e.y = 0.8
	e.vy = 0
	e.vel = away
	e.skip = false
	e.state = .Flying
	p.facing = math.atan2(away.x, away.y)
	p.stamina = max(p.stamina - 5, 0)
	burn(FIGHT_BURN, .Fighting, true)
	train(.Arms, SWING_WORK * ENEMY_KG[e.kind] / p.kg)
	say("Hup! Over you go!", 1)
	burst({foot.x, 0.6, foot.y}, 5, 2, COLOR_DUST, 0.08)
	return true
}

fence_ends :: proc(f: Fence_At) -> (a, b: Vec2) {
	a = Vec2{f32(f.x), f32(f.y)} * FENCE_LEN - WORLD_HALF
	b = a + (f.way == .East ? Vec2{FENCE_LEN, 0} : Vec2{0, FENCE_LEN})
	return
}

// The square of the grid a place is in.
fence_cell :: proc(pos: Vec2) -> (x, y: int) {
	return int(math.floor((pos.x + WORLD_HALF.x) / FENCE_LEN)), int(math.floor((pos.y + WORLD_HALF.y) / FENCE_LEN))
}

// Keeps a circle out of the fences near it.
push_out_fences :: proc(pos: ^Vec2, r: f32) -> (hit: bool, normal: Vec2) {
	cx, cy := fence_cell(pos^)
	for dy in -1 ..= 1 {
		for dx in -1 ..= 1 {
			for way in Fence_Way {
				f := Fence_At{cx + dx, cy + dy, way}
				if !fence_there(f) || gate_state(f) == GATE_OPEN {
					continue
				}
				a, b := fence_ends(f)
				if h, n := push_out_segment(pos, r + FENCE_THICK, a, b); h {
					hit, normal = true, n
				}
			}
		}
	}
	return
}

// A jump high enough to clear a fence carries him over it: the fences do not
// stop him while he is in the air. (Lower ones do, so he bumps into them; a
// heavy Prosio, or one with a heavy sack, cannot get over, and takes a piece
// down with F instead.)
clears_fences :: proc() -> bool {
	p := &g.prosio
	return p.airborne && p.jump_h >= FENCE_TOP
}

// Would a jump now take him over a fence? (Not with an animal in his
// hooves: he cannot jump at all then.)
can_clear_fence :: proc() -> bool {
	height := jump_height(total_kg())
	if lacks(.Electrolytes) {
		height *= CRAMP_JUMP
	}
	return height >= FENCE_TOP && g.prosio.carry != .Enemy
}

// Where a piece put up now would go: across his way, on the line of the
// grid nearest in front of him.
fence_ahead :: proc() -> Fence_At {
	p := &g.prosio
	dir := facing_dir(p.facing)
	q := (p.pos + dir * (prosio_radius(p.kg) + FENCE_AHEAD) + WORLD_HALF) / FENCE_LEN
	if abs(dir.y) >= abs(dir.x) {
		return {int(math.floor(q.x)), int(math.round(q.y)), .East}
	}
	return {int(math.round(q.x)), int(math.floor(q.y)), .South}
}

// Nothing solid stands where the piece would: no tree, rock or building,
// and not the pond.
fence_clear :: proc(f: Fence_At) -> bool {
	a, b := fence_ends(f)
	for k in ([3]f32{0.25, 0.5, 0.75}) {
		probe := a + (b - a) * k
		if hit, _ := collide_static(&probe, 0.12, 0); hit {
			return false
		}
	}
	return true
}

// Could a piece go up in front of him now? If not, why says why not.
fence_fits :: proc(f: Fence_At) -> (ok: bool, why: cstring) {
	switch {
	case !fence_valid(f):
		return false, "The meadow has its own fence there!"
	case fence_there(f):
		return false, "There is a piece of fence here already! F takes it down."
	case g.fence_count >= MAX_FENCES:
		return false, "That is all the fence the meadow can take!"
	case !fence_clear(f):
		return false, "Something is in the way here!"
	}
	return true, nil
}

// Q with a piece of fence or a scarecrow chosen: up it goes, in front of him.
put_up :: proc(item: Item) {
	p := &g.prosio
	at: Vec2
	if item == .Fence || item == .Gate {
		f := fence_ahead()
		if ok, why := fence_fits(f); !ok {
			answer(why)
			return
		}
		set_fence(f, true)
		a, b := fence_ends(f)
		at = (a + b) / 2
		if item == .Gate {
			set_gate(f, GATE_SHUT)
			say("Knock, knock! A gate. E opens it.", 1.4)
		} else {
			say(g.fence_count == 1 ? "Knock, knock! My first piece of fence!" : "Knock, knock! Another piece of fence!", 1.2)
		}
	} else if item == .Larder {
		at = p.pos + facing_dir(p.facing) * (prosio_radius(p.kg) + LARDER_RADIUS + 0.3)
		probe := at
		if hit, _ := collide_static(&probe, LARDER_RADIUS + 0.1, 0); hit {
			answer("Something is in the way here!")
			return
		}
		if !add_larder(at) {
			answer("That is all the larders the meadow can take!")
			return
		}
		say("There! A larder. E opens it.", 1.4)
	} else {
		at = p.pos + facing_dir(p.facing) * (prosio_radius(p.kg) + SCARECROW_RADIUS + 0.4)
		probe := at
		if hit, _ := collide_static(&probe, SCARECROW_RADIUS + 0.2, 0); hit {
			answer("Something is in the way here!")
			return
		}
		if !add_scarecrow(at) {
			answer("That is all the scarecrows the meadow can take!")
			return
		}
		say("There! Now, crows... BOO!", 1.4)
	}
	sack_take(item, 1)
	sack_step(0)
	burst({at.x, 0.5, at.y}, 8, 2, COLOR_PLANK, 0.07)
	stoop_towards(at)
	pests_look_again()
}

// A moment's stoop, hoof empty, towards a place.
stoop_towards :: proc(at: Vec2) {
	p := &g.prosio
	p.pick_t = pick_time()
	p.pick_total = p.pick_t
	p.drinking = true // nothing comes up in his hoof
	p.casting = false
	p.vel = {}
	to := at - p.pos
	if to != {} {
		p.facing = math.atan2(to.x, to.y)
	}
}

// What he has built that F would take down now.
Built :: enum {
	Nothing,
	Fence,
	Scarecrow,
	Larder,
}

// The scarecrow he is standing at, or failing that the piece of fence in
// front of him: of several pieces, the one nearest the spot where he would
// put one.
built_in_reach :: proc() -> (what: Built, fence: Fence_At, round: int) {
	p := &g.prosio
	pr := prosio_radius(p.kg)
	best := f32(1e9)
	for rd, i in g.rounds[:g.round_count] {
		if rd.kind != .Scarecrow || rd.r <= 0 {
			continue
		}
		if d := length2(rd.pos - p.pos) - pr - rd.r; d < BUILT_REACH && d < best {
			what, round, best = .Scarecrow, i, d
		}
	}
	for l, i in g.larders {
		if l.used && length2(l.pos - p.pos) - pr - LARDER_RADIUS < BUILT_REACH + 0.2 && what == .Nothing {
			what, round = .Larder, i // (round: here, which larder)
		}
	}
	if what != .Nothing || g.fence_count == 0 {
		return
	}
	front := p.pos + facing_dir(p.facing) * (pr + FENCE_AHEAD)
	cx, cy := fence_cell(p.pos)
	for dy in -1 ..= 1 {
		for dx in -1 ..= 1 {
			for way in Fence_Way {
				f := Fence_At{cx + dx, cy + dy, way}
				if !fence_there(f) {
					continue
				}
				a, b := fence_ends(f)
				if d := segment_distance(front, a, b); d < FENCE_REACH && d < best {
					what, fence, best = .Fence, f, d
				}
			}
		}
	}
	return
}

// F at something he built: back into the sack with it. False if there is
// nothing of his within reach.
take_down :: proc() -> bool {
	what, fence, round := built_in_reach()
	at: Vec2
	switch what {
	case .Nothing:
		return false
	case .Fence:
		item := gate_state(fence) != 0 ? Item.Gate : Item.Fence
		if sack_room(item) < 1 {
			answer("No room in my sack for more fence!")
			return true
		}
		set_fence(fence, false)
		sack_add(item, 0)
		a, b := fence_ends(fence)
		at = (a + b) / 2
		say("Down it comes. Into the sack!", 1.2)
	case .Larder:
		l := &g.larders[round]
		if !larder_empty(l) {
			answer("I must empty the larder first!")
			return true
		}
		if sack_room(.Larder) < 1 {
			answer("No room in my sack for the larder!")
			return true
		}
		at = l.pos
		remove_larder(l)
		sack_add(.Larder, 0)
		say("Up it comes. Heavy!", 1.2)
	case .Scarecrow:
		if sack_room(.Scarecrow) < 1 {
			answer("No room in my sack for more scarecrows!")
			return true
		}
		at = g.rounds[round].pos
		g.rounds[round].r = 0
		sack_add(.Scarecrow, 0)
		say("Come along, scarecrow.", 1.2)
	}
	sack_step(0)
	burst({at.x, 0.5, at.y}, 6, 2, COLOR_PLANK, 0.07)
	stoop_towards(at)
	return true
}

// Is this place fenced in? It is if, going from square to square of the
// grid without crossing a piece of fence (or the edge of the meadow), one
// cannot get to more than PEN_MOST squares.
fenced_in :: proc(pos: Vec2) -> bool {
	if g.fence_count < 2 {
		return false
	}
	Cell :: [2]int
	cells: [PEN_MOST]Cell
	x, y := fence_cell(pos)
	if x < 0 || x >= FENCE_W || y < 0 || y >= FENCE_H {
		return false
	}
	cells[0] = {x, y}
	n := 1
	for i := 0; i < n; i += 1 {
		c := cells[i]
		// The four ways out of this square, and the piece that would bar each.
		ways := [4]Cell{{1, 0}, {-1, 0}, {0, 1}, {0, -1}}
		bars := [4]Fence_At{{c.x + 1, c.y, .South}, {c.x, c.y, .South}, {c.x, c.y + 1, .East}, {c.x, c.y, .East}}
		for way, k in ways {
			to := c + way
			if to.x < 0 || to.x >= FENCE_W || to.y < 0 || to.y >= FENCE_H || fence_there(bars[k]) {
				continue
			}
			been := false
			for other in cells[:n] {
				been ||= other == to
			}
			if been {
				continue
			}
			if n >= PEN_MOST {
				return false
			}
			cells[n] = to
			n += 1
		}
	}
	return true
}

// An animal looks about it: with fences all round, it is penned, and its
// pen is its home; out of them again, its home is where it came from.
look_for_pen :: proc(e: ^Enemy) {
	inside := fenced_in(e.pos)
	if inside && !e.penned {
		e.penned = true
		e.wild = e.home
		e.home = e.pos
		e.hunt = .Stalk
		e.licking = false
		if e.kind == .Turkey {
			e.egg_t = min(e.egg_t, random_range(PEN_EGG_EVERY.x, PEN_EGG_EVERY.y))
		}
	} else if !inside && e.penned {
		unpen(e)
	}
}

unpen :: proc(e: ^Enemy) {
	if e.penned {
		e.penned = false
		e.home = e.wild
	}
}

// A goat in a pen stands to be milked: the nearest one within reach.
penned_goat_in_reach :: proc(e: ^Enemy) -> bool {
	p := &g.prosio
	return e.penned && length2(e.pos - p.pos) < prosio_radius(p.kg) + ENEMY_RADIUS[e.kind] + BUILT_REACH
}

// Scarecrows are round things of the world, like trees. One that has been
// taken down leaves its place free for the next.
MAX_SCARECROWS :: 8
SCARECROW_RADIUS :: f32(0.22)
SCARECROW_REACH :: f32(9) // crows leave wheat this near one alone

scarecrow_count :: proc() -> (n: int) {
	for rd in g.rounds[:g.round_count] {
		if rd.kind == .Scarecrow && rd.r > 0 {
			n += 1
		}
	}
	return
}

add_scarecrow :: proc(at: Vec2) -> bool {
	if scarecrow_count() >= MAX_SCARECROWS {
		return false
	}
	for &rd in g.rounds[:g.round_count] {
		if rd.kind == .Scarecrow && rd.r <= 0 {
			rd.pos, rd.r = at, SCARECROW_RADIUS
			return true
		}
	}
	return add_round(at, SCARECROW_RADIUS, .Scarecrow) >= 0
}

scarecrow_near :: proc(pos: Vec2) -> bool {
	for rd in g.rounds[:g.round_count] {
		if rd.kind == .Scarecrow && rd.r > 0 && length2(rd.pos - pos) < SCARECROW_REACH {
			return true
		}
	}
	return false
}

// A crop this pest will not touch: for a crow, wheat with a scarecrow near
// it; for a rabbit, anything fenced in.
crop_guarded :: proc(kind: Pest_Kind, pos: Vec2) -> bool {
	return kind == .Crow ? scarecrow_near(pos) : fenced_in(pos)
}

// Something has been built: a pest on its way to a crop, or at it, that is
// now guarded is off.
pests_look_again :: proc() {
	for &c in g.pests {
		if (c.state == .Coming || c.state == .Eating) && crop_guarded(c.kind, g.foods[c.food].pos) {
			c.state = .Fleeing
			c.stoned = true // a fright it remembers
			say(c.kind == .Crow ? "Ha! The crow is off!" : "Ha! The rabbit cannot get in!", 1.4)
		}
	}
}

// The rod: how far out it reaches for a fish, from where he stands.
ROD_REACH :: f32(4)

// The spear. It leaves his hoof as a stone of its weight would, and what it
// takes from an animal's health when thrown as fast as an arm can (ARM_SPEED)
// is SPEAR_BLOW; slower, less, by the square of the speed. The animal is
// not bowled over, it staggers for SPEAR_STAGGER seconds.
SPEAR_KG :: f32(1.5)
SPEAR_RADIUS :: f32(0.12)
SPEAR_COST :: f32(6) // stamina to throw one
SPEAR_LEN :: f32(1.5)
SPEAR_STAGGER :: f32(0.8)
SPEAR_BLOW := [Enemy_Kind]f32 {
	.Turkey = 55,
	.Goat   = 40,
	.Billy  = 28,
	.Fox    = 60,
}

spear_damage :: proc(kind: Enemy_Kind, speed: f32) -> f32 {
	share := speed / ARM_SPEED
	return SPEAR_BLOW[kind] * share * share
}

// A spear in flight meets an animal.
spear_hits :: proc(t: ^Thrown_Rock, e: ^Enemy, speed: f32) {
	drop_loot(e)
	hurt_enemy(e, spear_damage(e.kind, speed))
	e.state = .Dizzy
	e.timer = e.ko ? 0.7 : SPEAR_STAGGER
	e.vel = normalize2(t.vel) * 2
	pain_stars({e.pos.x, ENEMY_RADIUS[e.kind] * 1.6, e.pos.y}, 8)
	g.shake = max(g.shake, 0.25)
	say("THUNK!", 0.6)
	spear_lands(t, e.pos + normalize2(t.vel) * (ENEMY_RADIUS[e.kind] + 0.3))
}

// A spear comes down: it lies there until he picks it up again.
spear_lands :: proc(t: ^Thrown_Rock, at: Vec2) {
	t.active = false
	pos := at
	collide_static(&pos, 0.15, 0)
	if f := add_food(.Spear, pos); f != nil {
		f.fallen = true
		f.life = 1e9 // it does not rot
		f.size = 1
		burst({pos.x, 0.15, pos.y}, 4, 1.5, COLOR_DUST, 0.08)
	} else {
		sack_add(.Spear, 0) // nowhere to lie: back in the sack it is
	}
}

PLANK_DARK :: Color{176, 128, 80, 255}
SACKCLOTH :: Color{226, 200, 150, 255}

// One piece of fence: a post at each end and two rails between. The matrix
// puts its start on the ground, with the piece running along +z.
draw_fence_piece :: proc(m: Mat4) {
	for z in ([2]f32{0, FENCE_LEN}) {
		box(m, {0, 0.3, z}, {0.17, 0.6, 0.17}, PLANK_DARK)
	}
	for y in ([2]f32{0.18, FENCE_TOP}) {
		box(m, {0, y, FENCE_LEN / 2}, {0.07, 0.1, FENCE_LEN}, COLOR_PLANK)
	}
}

// A gate: a post at each end, and between them a leaf of planks with a
// brace across it, hung on the first post. Open, the leaf stands swung
// back square to the fence.
draw_gate :: proc(m: Mat4, open: bool) {
	for z in ([2]f32{0, FENCE_LEN}) {
		box(m, {0, 0.32, z}, {0.19, 0.64, 0.19}, PLANK_DARK)
	}
	leaf := m * translate({0, 0, 0.1}) * rot_y(open ? -math.PI / 2 : 0)
	width := FENCE_LEN - 0.2
	for y in ([3]f32{0.12, 0.29, FENCE_TOP + 0.02}) {
		box(leaf, {0, y, width / 2}, {0.07, 0.09, width}, COLOR_PLANK)
	}
	for z in ([2]f32{0.06, width - 0.06}) {
		box(leaf, {0, 0.27, z}, {0.08, 0.42, 0.09}, COLOR_PLANK)
	}
	rise := math.atan2(FENCE_TOP - 0.12, width)
	box(leaf * translate({0, 0.27, width / 2}) * rot_x(-rise), {0, 0, 0}, {0.06, 0.08, width * 1.02}, PLANK_DARK)
	box(leaf, {0.06, 0.29, 0.14}, {0.05, 0.05, 0.08}, {70, 70, 76, 255}) // the latch
}

fence_matrix :: proc(f: Fence_At) -> Mat4 {
	a, _ := fence_ends(f)
	return translate({a.x, 0, a.y}) * rot_y(f.way == .East ? math.PI / 2 : 0)
}

// The fences in view; and, with a piece chosen in the sack, a mark on the
// ground where Q would put it (yellow), or cannot (red).
draw_fences :: proc() {
	p := &g.prosio
	if g.fence_count > 0 {
		cx, cy := fence_cell(g.camera)
		wide := int(22 * g.camera_zoom / FENCE_LEN) + 2
		for y in max(cy - wide, 0) ..= min(cy + wide, FENCE_H) {
			for x in max(cx - wide, 0) ..= min(cx + wide, FENCE_W) {
				for way in Fence_Way {
					f := Fence_At{x, y, way}
					if !fence_there(f) {
						continue
					}
					a, b := fence_ends(f)
					if on_screen((a + b) / 2, 2) {
						if gate := gate_state(f); gate != 0 {
							draw_gate(fence_matrix(f), gate == GATE_OPEN)
						} else {
							draw_fence_piece(fence_matrix(f))
						}
					}
				}
			}
		}
	}
	if scene == .Playing && !drawing_shadows() && p.fail == .None && p.carry == .Nothing && (p.sack_sel == .Fence || p.sack_sel == .Gate) && p.sack[p.sack_sel] > 0 {
		f := fence_ahead()
		ok, _ := fence_fits(f)
		m := fence_matrix(f)
		mark := ok ? UI_YELLOW : UI_RED
		box(m, {0, 0.03, FENCE_LEN / 2}, {0.07, 0.05, FENCE_LEN}, mark)
		for z in ([2]f32{0, FENCE_LEN}) {
			box(m, {0, 0.12, z}, {0.12, 0.24, 0.12}, mark)
		}
	}
}

// A scarecrow: a pole and a crossbar in an old red shirt, straw at the
// cuffs, a sackcloth head and a straw hat. The matrix puts its foot on the
// ground.
draw_scarecrow :: proc(m: Mat4) {
	tube(m, {}, 0.05, 1.5, COLOR_TRUNK)
	box(m, {0, 1.2, 0}, {1.3, 0.07, 0.07}, COLOR_TRUNK)
	set_sway(0.03)
	ball(m, {0, 1.02, 0}, {0.27, 0.36, 0.17}, TSHIRT)
	for side in ([2]f32{-1, 1}) {
		ball(m, {side * 0.38, 1.2, 0}, {0.24, 0.1, 0.1}, TSHIRT)
		ball(m, {side * 0.66, 1.2, 0}, {0.09, 0.06, 0.06}, STRAW)
		ball(m, {side * 0.1, 0.66, 0}, {0.07, 0.1, 0.06}, STRAW)
	}
	h := m * translate({0, 1.56, 0})
	ball(h, {}, {0.2, 0.2, 0.19}, SACKCLOTH)
	for side in ([2]f32{-1, 1}) {
		ball(h, {side * 0.07, 0.03, 0.17}, {0.03, 0.035, 0.02}, ANIMAL_INK)
	}
	box(h, {0, -0.07, 0.18}, {0.12, 0.02, 0.02}, ANIMAL_INK)
	tube(h, {0, 0.12, 0}, 0.33, 0.03, STRAW)
	draw_shape(.Hemisphere, h * translate({0, 0.14, 0}) * scale({0.19, 0.17, 0.19}), STRAW)
	set_sway(0)
}

// A spear from its butt to its stone point.
draw_spear :: proc(butt, point: Vec3) {
	limb(IDENTITY, butt, point, 0.04, PLANK_DARK)
	along := point - butt
	limb(IDENTITY, point - along * 0.16, point + along * 0.04, 0.075, COLOR_ROCK_LIGHT)
}

// The workbench: a stout table with a saw and a mallet on it, planks
// leaning against it, and what has been built waiting on top.
draw_bench :: proc() {
	o := &g.stations[.Bench]
	if !on_screen(o.pos, 3) {
		return
	}
	m := translate({o.pos.x, 0, o.pos.y})
	box(m, {0, 0.72, 0}, {1.4, 0.1, 0.8}, COLOR_PLANK)
	for x in ([2]f32{-0.58, 0.58}) {
		for z in ([2]f32{-0.3, 0.3}) {
			box(m, {x, 0.34, z}, {0.12, 0.68, 0.12}, PLANK_DARK)
		}
	}
	box(m, {0, 0.22, 0.3}, {1.1, 0.07, 0.06}, PLANK_DARK)
	// The saw goes to and fro while he builds; otherwise it lies there.
	saw: f32 = o.baking ? 0.14 * math.sin(g.time * 12) : 0
	blade := m * translate({-0.3 + saw, 0.79, -0.12}) * rot_y(0.3)
	box(blade, {0.12, 0.01, 0}, {0.5, 0.015, 0.11}, STEEL)
	box(blade, {-0.2, 0.03, 0}, {0.16, 0.06, 0.13}, COLOR_HOOF)
	mallet := m * translate({0.42, 0.8, 0.14}) * rot_y(-0.5)
	box(mallet, {}, {0.2, 0.12, 0.12}, PLANK_DARK)
	box(mallet, {0, 0, 0.2}, {0.045, 0.045, 0.3}, COLOR_TRUNK)
	for k in 0 ..< 3 {
		lean := m * translate({-0.86 - 0.1 * f32(k), 0, -0.1 + 0.16 * f32(k)}) * rot_z(-0.22)
		box(lean, {0, 0.5, 0}, {0.06, 1.0, 0.16}, k == 1 ? PLANK_DARK : COLOR_PLANK)
	}
	if o.baking && math.mod(g.time, 0.25) < 0.02 {
		burst({o.pos.x - 0.2, 0.85, o.pos.y - 0.1}, 1, 1.2, COLOR_PLANK, 0.04)
	}
	if o.ready {
		top := m * translate({0.05, 0.78, 0.05})
		#partial switch o.dish {
		case .Fence:
			draw_fence_piece(top * translate({0, 0, -0.3}) * rot_y(math.PI / 2) * scale({0.4, 0.4, 0.4}) * translate({0, 0, -FENCE_LEN / 2}))
		case .Scarecrow:
			draw_scarecrow(top * scale({0.45, 0.45, 0.45}))
		case .Rod:
			limb(top, {-0.5, 0.03, 0.1}, {0.5, 0.03, -0.05}, 0.02, COLOR_TRUNK)
			ball(top, {0.5, 0.03, -0.05}, {0.035, 0.035, 0.035}, FISH_ORANGE)
		case .Spear:
			limb(top, {-0.55, 0.03, 0.1}, {0.45, 0.03, -0.05}, 0.025, COLOR_TRUNK)
			limb(top, {0.4, 0.03, -0.04}, {0.58, 0.03, -0.07}, 0.04, COLOR_ROCK)
		}
	}
}

// His rod and line, while he casts.
draw_cast :: proc() {
	p := &g.prosio
	if !p.casting || p.pick_t <= 0 || p.fail != .None {
		return
	}
	hand := prosio_to_world({HOLD_SIDE * 0.35, 1.0, 0.35})
	tip := prosio_to_world({HOLD_SIDE * 0.2, 2.1, 1.5})
	limb(IDENTITY, hand, tip, 0.035, PLANK_DARK)
	float := Vec3{p.cast_at.x, 0.08, p.cast_at.y}
	limb(IDENTITY, tip, float, 0.012, COLOR_WHITE)
	ball(IDENTITY, float, {0.09, 0.09, 0.09}, UI_RED)
	ball(IDENTITY, float + {0, 0.07, 0}, {0.06, 0.05, 0.06}, COLOR_WHITE)
}

// Does going straight from a to b cross a piece of fence? (For the tests:
// no animal on its feet ever should.)
crosses_fence :: proc(a, b: Vec2) -> bool {
	if g.fence_count == 0 {
		return false
	}
	// Twice the area of the triangle a, b, c: its sign says which side of
	// the line through a and b the point c is on.
	side :: proc(a, b, c: Vec2) -> f32 {
		return (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)
	}
	ax, ay := fence_cell(a)
	bx, by := fence_cell(b)
	for y in min(ay, by) - 1 ..= max(ay, by) + 1 {
		for x in min(ax, bx) - 1 ..= max(ax, bx) + 1 {
			for way in Fence_Way {
				f := Fence_At{x, y, way}
				if !fence_there(f) || gate_state(f) == GATE_OPEN {
					continue
				}
				c, d := fence_ends(f)
				if side(a, b, c) * side(a, b, d) < 0 && side(c, d, a) * side(c, d, b) < 0 {
					return true
				}
			}
		}
	}
	return false
}
