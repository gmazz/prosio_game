package game

// What the workbench (src/workbench, built by tools/workbench.sh) needs from
// the game, and only in its own build: the game the players get is built
// without WORKBENCH, so none of this is in it (a rule in tools/check.sh
// keeps it so).
//
// The workbench runs the game as a library it rebuilds and swaps in on every
// save. Two hooks let its panels run after the game's update and after its
// drawing; Kept is what lives outside g and must survive a swap.
WORKBENCH :: #config(WORKBENCH, false)

when WORKBENCH {
	workbench_after_update: proc()
	workbench_after_draw: proc()

	// Besides g: which screen is showing, his outfit, the language, the key
	// bindings and the pixel size. (Menu cursors and the like start again.)
	Kept :: struct {
		scene:       Scene,
		outfit:      Outfit,
		language:    Language,
		bindings:    type_of(bindings),
		pixel_level: int,
	}

	kept :: proc() -> Kept {
		return {scene, outfit, language, bindings, pixel_level}
	}

	restore_kept :: proc(k: Kept) {
		scene, outfit, bindings, pixel_level = k.scene, k.outfit, k.bindings, k.pixel_level
		set_language(k.language)
	}
}

// The workbench's test rig, for its Attacks pane (src/workbench/panes.odin):
// an animal that stands still, mending on or off, a stand of any height he
// can be put on, and his jump set by hand. None of it is in the game the
// players get: there these are always as the game has them.
when WORKBENCH {
	Bench_Rig :: struct {
		still:   int, // the animal (its index) that stands still, or -1
		no_mend: bool, // animals do not mend
		jump:    f32, // his jump's height, set by hand (0: as his legs and weight make it)
		stand:   bool, // the stand is up,
		stand_at: Vec2, // here,
		stand_r: f32, // this wide (its radius),
		stand_h: f32, // and this high
	}

	bench := Bench_Rig{still = -1}
}

// Whether the animal at this index stands still (only ever on the workbench).
held_still :: proc(index: int) -> bool {
	when WORKBENCH {
		return bench.still == index
	} else {
		return false
	}
}

// Whether animals mend (always, but for the workbench's switch).
mends :: proc() -> bool {
	when WORKBENCH {
		return !bench.no_mend
	} else {
		return true
	}
}

// How high the ground is under this place: the meadow is flat, but for the
// workbench's stand.
floor_at :: proc(pos: Vec2) -> f32 {
	when WORKBENCH {
		if bench.stand && length2(pos - bench.stand_at) < bench.stand_r {return bench.stand_h}
	}
	return 0
}

// His jump, unless the workbench sets it.
jump_set :: proc(height: f32) -> f32 {
	when WORKBENCH {
		if bench.jump > 0 {return bench.jump}
	}
	return height
}

// The blows that land, for the Attacks pane's live numbers: what moved (its
// weight and speed, for the momentum), the energy that counted, the kind of
// blow and what it took. kinetic and the stomp note what moved, blow_harm
// what that makes, and hurt_enemy, when the harm is that, the animal it hit.
when WORKBENCH {
	Bench_Blow :: struct {
		kind:      Enemy_Kind,
		how:       Blow,
		kg, speed: f32, // what hit it
		joules:    f32, // the energy that counted
		harm:      f32, // out of ENEMY_HEALTH
		enemy:     int,
		health:    f32, // what it had left
		time:      f32, // g.time
	}

	bench_moving: [2]f32 // kg and speed of the last thing whose energy was counted
	bench_pending: Bench_Blow
	bench_blows: [6]Bench_Blow // the latest first
	bench_blow_count: int
}

note_moving :: proc(kg, speed: f32) {
	when WORKBENCH {
		bench_moving = {kg, speed}
	}
}

note_harm :: proc(kind: Enemy_Kind, joules: f32, how: Blow, harm: f32) {
	when WORKBENCH {
		bench_pending = {kind = kind, how = how, kg = bench_moving.x, speed = bench_moving.y, joules = joules, harm = harm}
	}
}

note_hurt :: proc(e: ^Enemy, damage: f32) {
	when WORKBENCH {
		if bench_pending.harm != damage || bench_pending.kind != e.kind {
			return // (not a blow that went by its energy: drowning, say)
		}
		b := bench_pending
		b.enemy = int((uintptr(e) - uintptr(&g.enemies[0])) / size_of(Enemy))
		b.health = e.health
		b.time = g.time
		copy(bench_blows[1:], bench_blows[:len(bench_blows) - 1])
		bench_blows[0] = b
		bench_blow_count += 1
		bench_pending = {}
	}
}
