package main_desktop

// Entry point for Mac, Linux and Windows.

import game "../game"
import "core:fmt"
import "core:os"
import "core:reflect"
import "core:strconv"
import "core:strings"

main :: proc() {
	// Testing options:
	//   --kg 120          start at this weight
	//   --pos -11 0       start at this place
	//   --shot name.png   save a picture after a moment, then quit
	//   --frame 90        which frame to take the picture on
	//   --hold ub         hold buttons from frame 10: l r u d, b = bump, a = pick up or oven,
	//                     j = jump, s = sprint, g = grab or throw, q = eat,
	//                     z c = choose in the sack, e = enter, m = sack and outfit menu
	//   --tap j           press buttons once on frame 10 (same letters)
	//   --tap-at 40       press the --tap buttons on this frame instead
	//   --release-at 90   let go of the --hold buttons on this frame
	//   --tap2 g          a second set of buttons to press once...
	//   --tap2-at 90      ...on this frame
	//   --menu            show the menu instead of starting the game
	//   --crowd           put turkeys and goats round Prosio at the start
	//   --far             with --near: five metres off, to throw at
	//   --pebbles         start with six pebbles, chosen in the sack
	//   --choose Spear    this is chosen in the sack at the start, if he has any (a
	//                     thing by its name in the code: Apple, Apple_Pie, Wood, Rod...)
	//   --built           start with things built: a turkey in a pen beside him, a
	//                     scarecrow, a spear in the ground, wood and tools in the sack
	//   --bruises 50      start bruised: this many points off the top of his stamina
	//   --near fox        one animal (turkey, goat, billy or fox) within reach in
	//                     front of him, and no others anywhere
	//   --stock           start with a sack full of food
	//   --outfit 23101211 what he wears: one digit per row (hat, glasses, face,
	//                     earrings, shirt, on top, legs, feet), 0 the first choice
	//   --detail 4        pixel size: 1 chunkiest ... 9 finest (default 4)
	//   --lang pl         the language of the texts: a file in data/text (en, pl)
	//   --agent FILE      played by a program, a step at a time: commands are read
	//                     from FILE as lines are added to it (- for standard
	//                     input), answers are printed; see agent.odin and tools/play.sh
	opts: game.Options
	agent_path: string
	args := os.args
	for i := 1; i < len(args); i += 1 {
		switch args[i] {
		case "--kg":
			if i + 1 < len(args) {
				opts.start_kg, _ = strconv.parse_f32(args[i + 1])
				i += 1
			}
		case "--pos":
			if i + 2 < len(args) {
				opts.start_pos.x, _ = strconv.parse_f32(args[i + 1])
				opts.start_pos.y, _ = strconv.parse_f32(args[i + 2])
				opts.has_pos = true
				i += 2
			}
		case "--shot":
			if i + 1 < len(args) {
				opts.shot_path = strings.clone_to_cstring(args[i + 1])
				i += 1
			}
		case "--hold":
			if i + 1 < len(args) {
				opts.hold = buttons(args[i + 1])
				i += 1
			}
		case "--tap-at":
			if i + 1 < len(args) {
				opts.tap_frame, _ = strconv.parse_int(args[i + 1])
				i += 1
			}
		case "--release-at":
			if i + 1 < len(args) {
				opts.release_at, _ = strconv.parse_int(args[i + 1])
				i += 1
			}
		case "--tap2":
			if i + 1 < len(args) {
				opts.tap2 = buttons(args[i + 1])
				i += 1
			}
		case "--tap2-at":
			if i + 1 < len(args) {
				opts.tap2_frame, _ = strconv.parse_int(args[i + 1])
				i += 1
			}
		case "--detail":
			if i + 1 < len(args) {
				opts.detail, _ = strconv.parse_int(args[i + 1])
				i += 1
			}
		case "--lang":
			if i + 1 < len(args) {
				opts.language = args[i + 1]
				i += 1
			}
		case "--crowd":
			opts.crowd = true
		case "--seed":
			// Builds a different meadow.
			if i + 1 < len(args) {
				seed, _ := strconv.parse_uint(args[i + 1])
				opts.seed = u32(seed)
				i += 1
			}
		case "--bodies":
			opts.bodies = true
		case "--swimmers":
			opts.swimmers = true
		case "--stock":
			opts.stock = true
		case "--traits":
			// Seven levels, 0 to 1 (the first two may go down to -1), with
			// commas: arms, legs, lungs, hide, gut, hooves, cooking.
			if i + 1 < len(args) {
				for part, k in strings.split(args[i + 1], ",") {
					if k < len(opts.traits) {
						opts.traits[k], _ = strconv.parse_f32(part)
					}
				}
				opts.has_traits = true
				i += 1
			}
		case "--needs":
			// Six levels, 0 to 100, with commas: carbs, protein, fibre,
			// water, vitamins, electrolytes.
			if i + 1 < len(args) {
				for part, k in strings.split(args[i + 1], ",") {
					if k < len(opts.needs) {
						opts.needs[k], _ = strconv.parse_f32(part)
					}
				}
				opts.has_needs = true
				i += 1
			}
		case "--outfit":
			if i + 1 < len(args) {
				for ch, k in args[i + 1] {
					if k < len(opts.outfit) {
						opts.outfit[k] = u8(ch - '0')
					}
				}
				opts.has_outfit = true
				i += 1
			}
		case "--menu":
			opts.menu = true
		case "--far":
			opts.far = true
		case "--pebbles":
			opts.pebbles = true
		case "--built":
			opts.built = true
		case "--choose":
			if i + 1 < len(args) {
				opts.choose, opts.has_choose = reflect.enum_from_name(game.Item, args[i + 1])
				i += 1
			}
		case "--bruises":
			if i + 1 < len(args) {
				opts.bruises, _ = strconv.parse_f32(args[i + 1])
				i += 1
			}
		case "--near":
			if i + 1 < len(args) {
				switch args[i + 1] {
				case "turkey":
					opts.near = .Turkey
				case "goat":
					opts.near = .Goat
				case "billy":
					opts.near = .Billy
				case "fox":
					opts.near = .Fox
				}
				opts.has_near = true
				i += 1
			}
		case "--agent":
			if i + 1 < len(args) {
				agent_path = args[i + 1]
				opts.agent = true
				opts.no_save = true // a program playing never touches the saved game
				i += 1
			}
		case "--tap":
			if i + 1 < len(args) {
				opts.tap = buttons(args[i + 1])
				i += 1
			}
		case "--frame":
			if i + 1 < len(args) {
				opts.shot_frame, _ = strconv.parse_int(args[i + 1])
				i += 1
			}
		}
	}

	game.init(opts)
	if opts.agent {
		agent_run(agent_path)
		game.shutdown()
		return
	}
	for game.running() {
		game.frame()
	}
	if opts.shot_path != nil {
		print_state()
	}
	game.shutdown()
}

// A scripted run ends by printing how Prosio is when the picture is taken,
// so that a test can read numbers and not only look at pixels.
print_state :: proc() {
	g := &game.g
	p := &g.prosio
	fmt.printf("frame %d, time %.2f s, at (%.2f, %.2f), height %.2f, game over: %v\n", g.frame, g.time, p.pos.x, p.pos.y, p.height, p.fail)
	fmt.printf("weighs %.2f kg:", p.kg)
	for part in game.Part {
		fmt.printf(" %v %.2f", part, game.part_kg(part))
	}
	fmt.print("\nlevels:")
	for n in game.Need {
		fmt.printf(" %v %.0f (%v)", n, p.need[n], game.need_state(n))
	}
	fmt.print("\ntraits:")
	for t in game.Trait {
		fmt.printf(" %v %.2f", t, p.trait[t])
	}
	fmt.printf("\nstamina %.0f, carrying %v, says: %s\n", p.stamina, p.carry, p.bubble_t > 0 ? string(p.bubble) : "(nothing)")
	fmt.print("sack:")
	for n, item in p.sack {
		if n > 0 {
			fmt.printf(" %v %d", item, n)
		}
	}
	fmt.println()
}

buttons :: proc(letters: string) -> (set: bit_set[game.Button]) {
	for ch in letters {
		switch ch {
		case 'l':
			set += {.Left}
		case 'r':
			set += {.Right}
		case 'u':
			set += {.Up}
		case 'd':
			set += {.Down}
		case 'b':
			set += {.Bump}
		case 'a':
			set += {.Action}
		case 'j':
			set += {.Jump}
		case 's':
			set += {.Sprint}
		case 'g':
			set += {.Grab}
		case 'q':
			set += {.Eat}
		case 'c':
			set += {.Sack_Next}
		case 'z':
			set += {.Sack_Prev}
		case 'e':
			set += {.Confirm}
		case 'm':
			set += {.Bag}
		case 'w':
			set += {.Gas}
		case 'p':
			set += {.Menu}
		case 'x':
			set += {.Restart}
		}
	}
	return
}
