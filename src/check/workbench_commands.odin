package check

import game "../game"
import cmd "../workbench/commands"
import "core:fmt"
import "core:os"
import "core:strings"

// The workbench's commands (src/workbench/commands), which replaced the Test
// Meadow: each changes the game as the game itself would, so what is set up
// with them is played with the real controls. (The check program may use
// them: it is not the game the players get.)
rules_workbench_commands :: proc() {
	section("the workbench's commands")
	fresh()
	p := &game.g.prosio
	run :: proc(line: string) -> bool {
		_, ok := cmd.run(line)
		return ok
	}
	first_kg := p.kg
	ok := run("fat 85") && run("trait arms 1") && run("trait legs -1") && run("trait lungs 0.75")
	check("the workbench's body commands change his body and weight as the game reckons them",
		ok && p.kg > first_kg && p.kg == game.body_kg() && p.trait[.Arms] == 1 && p.trait[.Legs] == -1 && p.trait[.Lungs] == .75 && p.fat == 85)

	fresh()
	fallen := run("clear animals") && run("put fallen-goat")
	step(1, {}, {.Grab})
	check("a goat put down fallen can be grabbed with the real controls", fallen && p.carry == .Enemy && game.g.enemies[p.carry_index].ko)

	fresh()
	apple := run("clear animals") && run("put apple")
	first_apples := p.sack[.Apple]
	step(1, {}, {.Action})
	check("an apple put down is gathered as any apple, and eating a pumpkin fills his belly",
		apple && p.sack[.Apple] > first_apples && run("eat pumpkin") && p.meal_target > 0)

	fresh()
	rock := run("clear animals") && run("put rock")
	target, close := game.grab_target()
	check("a rock put down is one he can grab", rock && close && target.kind == .Rock)

	fresh()
	answer, loaded := cmd.load_setup("meadow")
	oven := run("go oven")
	step(1, {}, {.Action})
	in_menu := game.scene == .Oven
	game.forced_pressed = {.Action}
	game.update_cook_menu(1.0 / 60)
	game.forced_pressed = {}
	check("the meadow set-up (the Test Meadow's scene) loads, and has what an apple pie needs at the oven",
		loaded && strings.contains(answer, "9 commands") && oven && in_menu && game.g.stations[.Oven].baking, fmt.tprintf("%s; at the oven %v, its menu %v, baking %v; he is at (%.2f, %.2f), the oven at (%.2f, %.2f)", answer, oven, in_menu, game.g.stations[.Oven].baking, p.pos.x, p.pos.y, game.g.stations[.Oven].pos.x, game.g.stations[.Oven].pos.y))

	fresh()
	cmd.reset()
	built := run("kg 110") && run("go hills") && run("put goat") && run("put rock") && run("trait legs 0.5") && run("sack apple 3")
	Snapshot :: struct {
		pos:     game.Vec2,
		kg:      f32,
		animals: int,
		legs:    f32,
		apples:  int,
		last:    game.Vec2,
	}
	snap :: proc() -> Snapshot {
		p := &game.g.prosio
		return {p.pos, p.kg, game.g.enemy_count, p.trait[.Legs], int(p.sack[.Apple]), game.g.enemies[game.g.enemy_count - 1].pos}
	}
	before := snap()
	recorded := strings.contains(cmd.setup_text(), "put goat at ")
	cmd.replay()
	check("a set-up replayed from a fresh scene gives the same scene, each command kept as it can be run again (\"put goat at X Y\")",
		built && recorded && snap() == before, fmt.tprintf("%d commands", len(cmd.setup)))

	unknown: [dynamic]string
	for c in cmd.COMMANDS {
		fresh()
		if said, _ := cmd.run(c.name); strings.has_prefix(said, "not a command") {
			append(&unknown, c.name)
		}
	}
	check("every command the menu lists is one the workbench knows", len(unknown) == 0,
		fmt.tprintf("%v", unknown))

	// Asked for more animals than there is room for, the commands stop at
	// the room the game has. (The first crowd command added its animals to
	// the 33 already there: crowd 12 wrote past the last of the 40 places,
	// and the workbench stopped dead; crash report workbench-...-032025.)
	fresh()
	room_ok := true
	_, _ = cmd.run("put crowd 60")
	room_ok &&= game.g.enemy_count == game.MAX_ENEMIES
	for _ in 0 ..< 20 {
		_, _ = cmd.run("put goat")
		_, _ = cmd.run("put pen")
		_, _ = cmd.run("put fallen-goat")
	}
	check("the workbench's commands never put more animals than the game has room for (put crowd 60, then goats, pens and fallen goats on top)",
		room_ok && game.g.enemy_count <= game.MAX_ENEMIES, fmt.tprintf("%d animals, room for %d", game.g.enemy_count, game.MAX_ENEMIES))

	// A swap is only as safe as what the libraries share and keep. Each
	// library exports only its wb_ procedures: anything else of Odin's runtime
	// it exported would be shared with the host and every earlier library,
	// as its eight thread-local slots were, which filled after seven swaps
	// (crash report workbench-...-031718: "no more thread-local cleaner slots"
	// as the eighth library started). And each library swapped out frees what
	// its runtime kept for the thread (about 11 MB a swap otherwise).
	host, _ := os.read_entire_file("src/workbench/host/main.odin", context.temp_allocator)
	lib, _ := os.read_entire_file("src/workbench/lib.odin", context.temp_allocator)
	h, l := string(host), string(lib)
	exports_only := strings.contains(h, "os.write_entire_file(EXPORTS, \"_wb_*\\n\")") && strings.contains(h, "-exported_symbols_list,")
	release := strings.index(h, "api.release()")
	released := release >= 0 && release < strings.index(h, "\tapi = next") && strings.contains(l, "wb_release :: proc() {\n\truntime.run_thread_local_cleaners()")
	check("each library the workbench swaps in exports only its wb_ procedures, and each one swapped out frees what its runtime kept for the thread",
		exports_only && released, fmt.tprintf("exports only wb_: %v; the old library released before the next takes over: %v", exports_only, released))
}

// The index (src/workbench/commands/index.odin): what moves, draws, tunes and
// makes each kind of thing, for the workbench to open. Every kind has an
// entry (the tables are indexed by the game's kinds, so the workbench would
// not build without one), and every entry leads to something that is there.
rules_workbench_index :: proc() {
	bad: [dynamic]string
	kinds := 0
	look :: proc(name: string, entries: []cmd.Entry, bad: ^[dynamic]string, kinds: ^int) {
		kinds^ += 1
		codes := 0
		if len(entries) == 0 {append(bad, fmt.tprintf("%s has no entry", name))}
		for e in entries {
			if e.file == "" {
				codes += 1
				if e.at.line <= 0 || !os.exists(e.at.file_path) {append(bad, fmt.tprintf("%s: %s leads nowhere", name, e.label))}
				continue
			}
			text, err := os.read_entire_file(e.file, context.temp_allocator)
			if err != nil {
				append(bad, fmt.tprintf("%s: %s, %s is not there", name, e.label, e.file))
			} else if e.find != "" && !strings.contains(string(text), e.find) {
				append(bad, fmt.tprintf("%s: %s, %q is not in %s", name, e.label, e.find, e.file))
			}
		}
		if codes == 0 {append(bad, fmt.tprintf("%s has no procedure", name))}
	}
	for k in cmd.Other {look(fmt.tprintf("%v", k), cmd.index_of(k), &bad, &kinds)}
	for k in game.Enemy_Kind {look(fmt.tprintf("%v", k), cmd.index_of(k), &bad, &kinds)}
	for k in game.Round_Kind {look(fmt.tprintf("%v", k), cmd.index_of(k), &bad, &kinds)}
	for k in game.Food_Kind {look(fmt.tprintf("%v", k), cmd.index_of(k), &bad, &kinds)}
	for k in game.Pest_Kind {look(fmt.tprintf("%v", k), cmd.index_of(k), &bad, &kinds)}
	for k in game.Decor_Kind {look(fmt.tprintf("%v", k), cmd.index_of(k), &bad, &kinds)}
	check("the workbench's index says, for every kind of thing in the game, what moves, draws and tunes it, and every entry leads to a procedure or file that is there",
		len(bad) == 0, len(bad) > 0 ? fmt.tprintf("%d wrong, such as %s", len(bad), bad[0]) : fmt.tprintf("%d kinds", kinds))
}

// The workbench's own keys (src/workbench/keys.txt): every line of it reads,
// and as it stands it gives Shift+1 to Shift+5 (! @ # $ %: a compact keyboard
// has no F keys) to the menu, the editor, replaying, pausing and stepping.
// The game is given no keys on the frame one of them acts (menu.odin).
rules_workbench_keys :: proc() {
	text, err := os.read_entire_file("src/workbench/keys.txt", context.temp_allocator)
	keys, trouble := cmd.parse_keys(string(text))
	given := ""
	for action in cmd.Bench_Action {
		given = fmt.tprintf("%s%s%v %s", given, given == "" ? "" : ", ", action, cmd.key_text(keys.keys[action][0]))
	}
	check("src/workbench/keys.txt reads, and gives Shift+1 to Shift+5 to the workbench's menu, editor, replay, pause and step",
		err == nil && trouble == "" && given == "Menu Shift+1, Editor Shift+2, Replay Shift+3, Pause Shift+4, Step Shift+5", trouble != "" ? trouble : given)
	_, bad := cmd.parse_keys("menu Shift+F13\nlook F1")
	check("a key keys.txt cannot read is said, not taken", bad != "", bad)
}
