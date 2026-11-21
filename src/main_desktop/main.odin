package main_desktop

// Entry point for Mac, Linux and Windows.

import game "../game"
import "core:os"
import "core:strconv"
import "core:strings"

main :: proc() {
	// Testing options:
	//   --kg 120          start at this weight
	//   --pos -11 0       start at this place
	//   --shot name.png   save a picture after a moment, then quit
	//   --frame 90        which frame to take the picture on
	//   --hold ub         hold buttons from frame 10: l r u d, b = bump, a = action,
	//                     j = jump, s = sprint, g = grab or throw, q = eat,
	//                     z c = choose in the sack, e = enter
	//   --tap j           press buttons once on frame 10 (same letters)
	//   --tap-at 40       press the --tap buttons on this frame instead
	//   --release-at 90   let go of the --hold buttons on this frame
	//   --tap2 g          a second set of buttons to press once...
	//   --tap2-at 90      ...on this frame
	//   --menu            show the menu instead of starting the game
	//   --crowd           put turkeys and goats round Prosio at the start
	//   --stock           start with a sack full of food
	//   --last-truffle    four truffles found already, the last one at his feet
	//   --detail 4        pixel size: 1 chunkiest ... 6 finest (default 4)
	opts: game.Options
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
		case "--crowd":
			opts.crowd = true
		case "--stock":
			opts.stock = true
		case "--last-truffle":
			opts.last_truffle = true
		case "--menu":
			opts.menu = true
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
	for game.running() {
		game.frame()
	}
	game.shutdown()
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
		}
	}
	return
}
