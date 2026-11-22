package check

// Tests the game without playing it: the real game code, run without a
// window, faster than real time.
//
//   prosio-check                       the check suite: rules the game must keep
//   prosio-check autoplay [options]    a bot plays, and reports anything odd
//       --minutes 30   how long it plays (in game time)
//       --seed 7       which meadow, and which choices the bot makes
//
// The suite prints PASS or FAIL for each rule and exits with the number of
// failures. Autoplay prints a report (see autoplay.odin) and exits with 1 if
// it saw anything odd. See tools/ for the scripts that build and run these.

import game "../game"
import "core:fmt"
import "core:math"
import "core:os"
import "core:strconv"

main :: proc() {
	game.keyboard_enabled = false
	args := os.args[1:]
	if len(args) > 0 && args[0] == "autoplay" {
		minutes := 30
		seed := 1
		for i := 1; i < len(args); i += 1 {
			switch args[i] {
			case "--minutes":
				if i + 1 < len(args) {
					minutes, _ = strconv.parse_int(args[i + 1])
					i += 1
				}
			case "--seed":
				if i + 1 < len(args) {
					seed, _ = strconv.parse_int(args[i + 1])
					i += 1
				}
			}
		}
		os.exit(autoplay(minutes, seed) ? 0 : 1)
	}
	failures := run_rules()
	os.exit(failures)
}

// Starts a fresh game, the usual meadow (or another), with nothing saved.
fresh :: proc(seed: u32 = 0) {
	game.g.opts = {no_save = true, seed = seed}
	game.scene = .Playing
	game.new_game()
}

// Runs the game on for this many frames (a sixtieth of a second each),
// holding these buttons down, and pressing these on the first frame.
step :: proc(frames: int, down: bit_set[game.Button] = {}, tap: bit_set[game.Button] = {}) {
	for f in 0 ..< frames {
		game.forced_down = down
		game.forced_pressed = f == 0 ? tap : {}
		game.simulate(1.0 / 60)
	}
	game.forced_down = {}
	game.forced_pressed = {}
}

// He eats one full-grown piece of this.
feed :: proc(item: game.Item) {
	game.eat(game.item_meal(item, game.item_kcal(item)))
}

// The sum of his parts.
parts_kg :: proc() -> (sum: f32) {
	for part in game.Part {
		sum += game.part_kg(part)
	}
	return
}

length :: proc(v: game.Vec2) -> f32 {
	return math.sqrt(v.x * v.x + v.y * v.y)
}

// Stands at a station, makes this many of a dish and takes them.
cook :: proc(at: game.Station_Kind, dish: game.Item, count: int) {
	g := &game.g
	p := &g.prosio
	p.pos = g.stations[at].pos + {0, game.STATION_RADIUS[at] + 1.0}
	p.vel = {}
	game.use_station(at) // (as E would; E itself might find pebbles or a branch beside it first)
	buf: [len(game.RECIPES)]^game.Recipe
	for r, i in game.station_recipes(at, &buf) {
		if r.dish == dish {
			game.cook_choice = i
		}
	}
	game.cook_count = count
	game.forced_pressed = {.Confirm}
	game.update_cook_menu(1.0 / 60)
	game.forced_pressed = {}
	game.scene = .Playing
	step(60 * 10)
	game.use_station(at)
	step(40)
}

// Puts an animal right in front of him.
animal_before_him :: proc(kind: game.Enemy_Kind) -> ^game.Enemy {
	g := &game.g
	p := &g.prosio
	p.facing = 0
	game.add_enemy(kind, p.pos + {0, game.prosio_radius(p.kg) + game.ENEMY_RADIUS[kind] + 0.3})
	e := &g.enemies[g.enemy_count - 1]
	e.facing = math.PI
	return e
}

say :: fmt.printf
