package main_desktop

// The game played a step at a time by a program: `prosio --agent FILE`.
//
// The game stands still until a command arrives. Commands are lines of text
// read from FILE as they are added to it (or from the keyboard's place,
// standard input, with `--agent -`); the answers are printed. So a program
// that can run shell commands can play: it appends a line, reads the answer,
// thinks for as long as it likes, and appends the next. tools/play.sh wraps
// this up. The window shows the game as it stands, so a person can watch.
//
// The buttons are the game's own, pressed the way a person presses them:
// nothing here reaches round the rules. `help` lists the commands.

import game "../game"
import "core:fmt"
import "core:math"
import "core:os"
import "core:slice"
import "core:strconv"
import "core:strings"
import "core:time"

agent_quit: bool
agent_was_down: bit_set[game.Button] // the buttons held on the frame before
agent_real_pace: bool // draw every frame, so the game runs at the speed a person sees
MAX_STEP :: 3600 // frames in one command: a minute of the game

AGENT_HELP :: `Commands (one a line; a line starting with # is ignored):
  step N [hold LETTERS] [tap LETTERS] [until event]
        The game runs N frames (60 a second, at most 3600). The held buttons
        are down throughout (going down on the first frame, if they were not
        held already); the tapped ones go down on the first frame only.
        With "until event" it stops early when something happens: he says
        something, the line at the bottom of the screen changes, he picks up
        or lets go of something. It always stops when a menu opens or closes
        or the game is over, since the buttons then mean something else.
  hold LETTERS N        the same as: step N hold LETTERS
  tap LETTERS [N]       the same as: step N tap LETTERS   (N is 1 if left out)
  wait N                the same as: step N
  walk X Y [sprint] [max N] [until event]
        Holds the direction buttons towards the place (X, Y) until he is
        there, is blocked, or N frames have passed (600 if left out). It goes
        straight: round a rock or a tree, walk to a point beside it first.
  look [R]              what is on the screen in words: the menu if one is open; otherwise
                        Prosio, the line at the bottom, and everything within R metres (12)
  state                 his body in numbers: weight and its parts, levels, traits, sack
  map                   the parts of the meadow and the fixed places, with where they lie
  shot FILE.png         save a picture of the screen as it stands
  pace real | fast      real: frames are drawn as they run, for someone watching (default fast)
  mark WORD             answers "mark WORD": for telling where one batch of answers ends
  help                  this
  quit                  close the game
Buttons, one letter each:
  l r u d   left, right, up, down (up is away from the camera: smaller y; right is larger x)
  b  bump, and bash with a held animal (SPACE)      j  jump
  s  sprint (hold it, with a direction)             g  grab, and let go or throw (F)
  a  pick up, use, drink, milk, chop (E)            q  eat what is chosen in the sack (a piece
                                                       of fence or a scarecrow: put it up)
  z c  choose in the sack; switch panels in the sack menu
  m  open or close the sack, body, outfit and map menu
  w  let his wind go                                p  pause menu (ESC)
  e  select in a menu (ENTER)                       x  wake up at home after a game over
Places are in metres. A step answers with what he said meanwhile and where he stands now.`

// Reads commands until told to quit, or the window is closed.
agent_run :: proc(path: string) {
	file := os.stdin
	from_file := path != "-"
	if from_file {
		f, err := os.open(path)
		if err != nil {
			fmt.eprintfln("cannot read commands from %s: %v", path, err)
			return
		}
		file = f
	}
	game.agent_frame({}, {}) // so that the game knows where he stands before the first question
	fmt.println("Prosio, a step at a time. The game stands still until you say. 'help' lists the commands, 'look' says what is on the screen.")
	pending: strings.Builder
	buf: [4096]u8
	for game.running() && !agent_quit {
		n, err := os.read(file, buf[:])
		if n > 0 {
			strings.write_bytes(&pending, buf[:n])
		} else if !from_file && err != nil {
			break // nothing more will come
		}
		text := strings.to_string(pending)
		for !agent_quit {
			end := strings.index_byte(text, '\n')
			if end < 0 {
				break
			}
			line := strings.trim_space(text[:end])
			text = text[end + 1:]
			if line != "" && line[0] != '#' {
				agent_command(line)
			}
		}
		if len(text) == strings.builder_len(pending) {
			time.sleep(4 * time.Millisecond) // nothing new: do not spin if the window is hidden and drawing costs no time
		}
		rest := strings.clone(text, context.temp_allocator)
		strings.builder_reset(&pending)
		strings.write_string(&pending, rest)
		free_all(context.temp_allocator)
		game.draw_frame() // the game as it stands; this also paces the loop
	}
}

agent_command :: proc(line: string) {
	words := strings.fields(line, context.temp_allocator)
	number :: proc(words: []string, i: int, otherwise: int) -> int {
		if i < len(words) {
			if n, ok := strconv.parse_int(words[i]); ok {
				return n
			}
		}
		return otherwise
	}
	// The options that can follow a step or a walk.
	Tail :: struct {
		hold, tap: bit_set[game.Button],
		until:     bool,
		sprint:    bool,
		limit:     int,
	}
	tail :: proc(words: []string) -> (t: Tail, ok: bool) {
		ok = true
		for i := 0; i < len(words); i += 1 {
			switch words[i] {
			case "hold":
				i += 1
				if i < len(words) {t.hold = buttons(words[i])}
			case "tap":
				i += 1
				if i < len(words) {t.tap = buttons(words[i])}
			case "until":
				i += 1
				t.until = true
			case "sprint":
				t.sprint = true
			case "max":
				i += 1
				t.limit = number(words, i, 0)
			case:
				fmt.printfln("error: I do not know what '%s' means here; see help", words[i])
				return t, false
			}
		}
		return
	}

	switch words[0] {
	case "help":
		fmt.println(AGENT_HELP)
	case "quit":
		agent_quit = true
		fmt.println("bye")
	case "mark":
		fmt.printfln("mark %s", len(words) > 1 ? words[1] : "")
	case "pace":
		agent_real_pace = len(words) > 1 && words[1] == "real"
		fmt.printfln("pace %s", agent_real_pace ? "real" : "fast")
	case "state":
		print_state()
	case "look":
		radius := f32(12)
		if len(words) > 1 {
			if r, ok := strconv.parse_f32(words[1]); ok {
				radius = clamp(r, 2, 60)
			}
		}
		agent_look(radius)
	case "map":
		agent_map()
	case "shot":
		if len(words) < 2 {
			fmt.println("error: shot needs a file name, like shot build/play/now.png")
			return
		}
		game.draw_frame(strings.clone_to_cstring(words[1], context.temp_allocator))
		fmt.printfln("saved %s", words[1])
	case "step", "wait":
		if t, ok := tail(words[min(2, len(words)):]); ok {
			agent_step(number(words, 1, 1), t.hold, t.tap, t.until)
		}
	case "hold":
		if len(words) < 3 {
			fmt.println("error: hold needs buttons and a number of frames, like hold r 30")
			return
		}
		if t, ok := tail(words[3:]); ok {
			agent_step(number(words, 2, 1), buttons(words[1]) + t.hold, t.tap, t.until)
		}
	case "tap":
		if len(words) < 2 {
			fmt.println("error: tap needs buttons, like tap g")
			return
		}
		frames := number(words, 2, -1)
		if t, ok := tail(words[frames < 0 ? 2 : 3:]); ok {
			agent_step(max(frames, 1), t.hold, buttons(words[1]) + t.tap, t.until)
		}
	case "walk":
		if len(words) < 3 {
			fmt.println("error: walk needs a place, like walk -12.5 3")
			return
		}
		x, okx := strconv.parse_f32(words[1])
		y, oky := strconv.parse_f32(words[2])
		if !okx || !oky {
			fmt.println("error: walk needs two numbers, like walk -12.5 3")
			return
		}
		if t, ok := tail(words[3:]); ok {
			agent_walk({x, y}, t.sprint, t.limit > 0 ? t.limit : 600, t.until)
		}
	case:
		fmt.printfln("error: unknown command '%s'; help lists the commands", words[0])
	}
}

// What can change while frames run, to tell when something has happened.
Agent_Moment :: struct {
	scene:  game.Scene,
	fail:   game.Fail,
	carry:  game.Carry,
	bubble: string,
	prompt: string,
}

agent_moment :: proc() -> Agent_Moment {
	p := &game.g.prosio
	prompt := game.scene == .Playing ? game.prompt_text() : nil
	return {
		scene = game.scene,
		fail = p.fail,
		carry = p.carry,
		bubble = p.bubble_t > 0 ? strings.clone(string(game.expand_keys(p.bubble)), context.temp_allocator) : "",
		prompt = prompt != nil ? strings.clone(string(game.expand_keys(prompt)), context.temp_allocator) : "",
	}
}

// What is said back after frames have run.
Agent_Run :: struct {
	frames: int,
	why:    string, // why it stopped early, if it did
	said:   [dynamic]string,
}

// One frame, and whether to go on. Collects what he says.
agent_one :: proc(run: ^Agent_Run, down, tap: bit_set[game.Button], until: bool) -> bool {
	before := agent_moment()
	// A button that was up and is now held has just gone down, as on a keyboard.
	game.agent_frame(down, tap + (down - agent_was_down))
	agent_was_down = down
	if agent_real_pace {
		game.draw_frame()
	}
	run.frames += 1
	now := agent_moment()
	event := false
	if now.bubble != "" && now.bubble != before.bubble {
		if len(run.said) == 0 || run.said[len(run.said) - 1] != now.bubble {
			append(&run.said, now.bubble)
		}
		event = true
	}
	switch {
	case now.scene != before.scene:
		run.why = fmt.tprintf("the screen changed from %v to %v", before.scene, now.scene)
	case now.fail != before.fail && now.fail != .None:
		run.why = fmt.tprintf("the game is over (%v)", now.fail)
	case until && event:
		run.why = "he said something"
	case until && now.carry != before.carry:
		run.why = now.carry == .Nothing ? "he let go" : "he took hold of something"
	case until && now.prompt != before.prompt:
		run.why = "the line at the bottom changed"
	case !game.running():
		run.why = "the window was closed"
	}
	return run.why == ""
}

agent_step :: proc(frames: int, down, tap: bit_set[game.Button], until: bool) {
	run := Agent_Run{said = make([dynamic]string, context.temp_allocator)}
	for f in 0 ..< clamp(frames, 1, MAX_STEP) {
		if !agent_one(&run, down, f == 0 ? tap : {}, until) {
			break
		}
	}
	agent_report(&run)
}

agent_walk :: proc(to: game.Vec2, sprint: bool, limit: int, until: bool) {
	p := &game.g.prosio
	run := Agent_Run{said = make([dynamic]string, context.temp_allocator)}
	from := p.pos
	checked := p.pos
	outcome := ""
	for f in 0 ..< clamp(limit, 1, MAX_STEP) {
		d := to - p.pos
		if math.sqrt(d.x * d.x + d.y * d.y) < 0.35 {
			outcome = "arrived"
			break
		}
		if game.scene != .Playing {
			outcome = "cannot walk: a menu is open (see look)"
			break
		}
		down: bit_set[game.Button]
		// Eight directions: the smaller part is left out when it is small beside the larger.
		if abs(d.x) > 0.12 && abs(d.x) > abs(d.y) * 0.4 {down += d.x > 0 ? {.Right} : {.Left}}
		if abs(d.y) > 0.12 && abs(d.y) > abs(d.x) * 0.4 {down += d.y > 0 ? {.Down} : {.Up}}
		if sprint {down += {.Sprint}}
		if !agent_one(&run, down, {}, until) {
			break
		}
		if f % 60 == 59 {
			m := p.pos - checked
			if math.sqrt(m.x * m.x + m.y * m.y) < 0.25 {
				outcome = "blocked: he pushed for a second and got nowhere (look says what is in the way)"
				break
			}
			checked = p.pos
		}
	}
	if outcome == "" && run.why == "" {
		outcome = "not there yet: the frames ran out"
	}
	moved := p.pos - from
	fmt.printfln("walk: %s; moved %.1f m", outcome != "" ? outcome : "stopped", math.sqrt(moved.x * moved.x + moved.y * moved.y))
	agent_report(&run)
}

agent_report :: proc(run: ^Agent_Run) {
	fmt.printf("ran %d frames (%.2f s)", run.frames, f32(run.frames) / 60)
	if run.why != "" {
		fmt.printf(", stopped because %s", run.why)
	}
	fmt.println()
	if len(run.said) > 0 {
		fmt.print("he said:")
		for line in run.said {
			fmt.printf(" \"%s\"", line)
		}
		fmt.println()
	}
	agent_line()
}

// Where things stand, in a line or two.
agent_line :: proc() {
	g := &game.g
	p := &g.prosio
	if game.scene != .Playing {
		fmt.printfln("now: the %s is open; look says what it shows", agent_scene_name())
		return
	}
	fmt.printf("now: at (%.1f, %.1f)", p.pos.x, p.pos.y)
	if g.in_region {
		fmt.printf(" in %s", game.TEXT.region_name[g.region])
	}
	fmt.printf(", %.1f kg, stamina %.0f, %s", p.kg, p.stamina, agent_carrying())
	if p.height > 0.05 {
		fmt.printf(", %.1f m off the ground", p.height)
	}
	if p.fail != .None {
		fmt.printf(", GAME OVER (%v): tap x to wake up at home", p.fail)
	} else if p.dazed_t > 0 {
		fmt.print(", dizzy")
	}
	fmt.println()
	if prompt := game.prompt_text(); prompt != nil {
		fmt.printfln("bottom line: %s", game.expand_keys(prompt))
	}
}

agent_scene_name :: proc() -> string {
	switch game.scene {
	case .Menu:
		return "main menu"
	case .Paused:
		return "pause menu"
	case .Oven:
		return "cooking menu"
	case .Bag:
		return "sack, body, outfit and map menu"
	case .Larder:
		return "larder"
	case .Load:
		return "list of saved games to load"
	case .Playing:
	}
	return "game"
}

agent_carrying :: proc() -> string {
	g := &game.g
	p := &g.prosio
	switch p.carry {
	case .Enemy:
		e := &g.enemies[p.carry_index]
		return fmt.tprintf("holding a %s%v", e.ko ? "dead " : "", e.kind)
	case .Rock:
		return fmt.tprintf("carrying a rock of %.0f kg", p.carry_kg)
	case .Nothing:
	}
	return "hands free"
}

// Where something is from him: how far, which way on the screen, and its place.
agent_where :: proc(pos: game.Vec2) -> string {
	d := pos - game.g.prosio.pos
	dist := math.sqrt(d.x * d.x + d.y * d.y)
	side := d.x >= 0 ? "right" : "left"
	way := d.y >= 0 ? "down" : "up"
	return fmt.tprintf("%5.1f m  (%.1f %s, %.1f %s)  at (%.1f, %.1f)", dist, abs(d.x), side, abs(d.y), way, pos.x, pos.y)
}

Agent_Thing :: struct {
	dist: f32,
	text: string,
}

agent_look :: proc(radius: f32) {
	g := &game.g
	p := &g.prosio
	switch game.scene {
	case .Menu, .Paused:
		fmt.printfln("The %s is open. u and d choose, e selects%s.", agent_scene_name(), game.scene == .Paused ? ", p closes it" : "")
		for item, i in game.menu_items() {
			fmt.printfln("  %s %s", i == game.menu_choice ? ">" : " ", game.menu_item_text(item))
		}
		return
	case .Oven:
		buf: [len(game.RECIPES)]^game.Recipe
		recipes := game.station_recipes(game.cook_at, &buf)
		fmt.printfln("The menu of %s is open. u and d choose, l and r change how many, e or a makes it, p or g closes.", game.TEXT.station_name[game.cook_at])
		for r, i in recipes {
			fmt.printf("  %s %s: needs", i == game.cook_choice ? ">" : " ", game.TEXT.item_name[r.dish])
			for need in r.needs {
				if need.count > 0 {
					fmt.printf(" %d %s (has %d)", need.count, game.TEXT.item_name[need.item], p.sack[need.item])
				}
			}
			fmt.printfln("; he can make %d", game.max_batch(r))
		}
		fmt.printfln("  how many: %d", game.cook_count)
		return
	case .Larder:
		l := &g.larders[game.larder_open]
		fmt.println("The larder is open. u and d choose, r puts one in, l takes one out, e moves all of it, p or g closes.")
		buf: [len(game.Item)]game.Item
		for item, i in game.larder_rows(l, &buf) {
			fmt.printfln("  %s %s: %d in the sack, %d in the larder", i == game.larder_choice ? ">" : " ", game.TEXT.item_name[item], p.sack[item], l.stock[item])
		}
		return
	case .Load:
		// (A program playing never sees it: it makes and lists no backups.)
		fmt.println("The list of saved games to load is open. u and d choose, e loads, p closes.")
		for b, i in game.backups[:game.backup_count] {
			fmt.printfln("  %s %s", i == game.load_choice ? ">" : " ", game.backup_when(b.saved))
		}
		return
	case .Bag:
		fmt.printfln("The sack, body, outfit and map menu is open on the %v panel. z and c switch panels, m or p closes.", game.bag_tab)
		#partial switch game.bag_tab {
		case .Sack:
			fmt.printfln("  the arrows choose, e or q eats (or, for a thing to use, chooses it and closes the menu). Chosen: %s (he has %d)", game.TEXT.item_name[game.bag_item], p.sack[game.bag_item])
			fmt.print("  in the sack:")
			for n, item in p.sack {
				if n > 0 {
					fmt.printf(" %s %d,", game.TEXT.item_name[item], n)
				}
			}
			fmt.println()
		case .Outfit:
			fmt.printfln("  u and d choose a row, l and r change it. Row: %v", game.bag_row)
		case .Controls:
			fmt.println("  each action, its controller button and its two keys (the agent's own letters stay as they are):")
			for b, i in game.REMAPPABLE {
				fmt.printfln("  %s %s: %s, %s, %s", i == game.controls_row ? ">" : " ", game.TEXT.control_name[b], game.TEXT.pad_name[game.bindings[b].pad], game.key_name(game.bindings[b].keys[0]), game.key_name(game.bindings[b].keys[1]))
			}
			fmt.printfln("  %s back to the defaults", game.controls_row == len(game.REMAPPABLE) ? ">" : " ")
		case:
			fmt.println("  (state gives the numbers of his body; map gives the meadow)")
		}
		return
	case .Playing:
	}

	agent_line()
	if p.bubble_t > 0 {
		fmt.printfln("he is saying: \"%s\"", game.expand_keys(p.bubble))
	}
	fmt.printf("facing %s; chosen in the sack: ", agent_facing())
	if p.sack[p.sack_sel] > 0 {
		fmt.printfln("%s (%d)", game.TEXT.item_name[p.sack_sel], p.sack[p.sack_sel])
	} else {
		fmt.println("nothing")
	}

	things := make([dynamic]Agent_Thing, context.temp_allocator)
	add :: proc(things: ^[dynamic]Agent_Thing, pos: game.Vec2, reach: f32, text: string) {
		d := pos - game.g.prosio.pos
		dist := math.sqrt(d.x * d.x + d.y * d.y)
		if dist <= reach {
			append(things, Agent_Thing{dist, fmt.tprintf("%-34s %s", text, agent_where(pos))})
		}
	}
	for &e in g.enemies[:g.enemy_count] {
		how := ""
		switch e.state {
		case .Chase:
			how = e.licking ? "licking him" : (e.scared_t > 0 ? "running away" : "on its feet")
		case .Flying:
			how = "in the air"
		case .Dizzy:
			how = "dizzy"
		case .Held:
			how = "in his hands"
		case .Dead:
			how = "dead"
		case .Swimming:
			how = e.ko ? "floating, drowned" : "swimming for the bank"
		case .Gone:
			continue
		}
		extra := ""
		if e.has_loot {
			extra = fmt.tprintf(", carrying his %s", game.TEXT.item_name[e.loot])
		}
		if e.kind == .Goat && e.state != .Dead {
			extra = e.milk_t <= 0 ? ", has milk" : ", no milk yet"
		}
		if e.penned && e.state == .Chase {
			how = "in a pen, quiet"
		}
		add(&things, e.pos, radius, fmt.tprintf("animal: %v, %s%s", e.kind, how, extra))
	}
	for &f in g.foods[:g.food_count] {
		if f.gone || f.respawn > 0 {
			continue
		}
		#partial switch f.kind {
		case .Wood:
			add(&things, f.pos, radius, "a fallen branch (wood)")
		case .Spear:
			add(&things, f.pos, radius, "his spear, in the ground")
		case:
			add(&things, f.pos, radius, fmt.tprintf("food: %v, %s", f.kind, f.fallen ? "lying there" : fmt.tprintf("%.0f%% grown", f.grow * 100)))
		}
	}
	for &rd in g.rounds[:g.round_count] {
		if rd.r <= 0 {
			continue
		}
		#partial switch rd.kind {
		case .Tree:
			if rd.species == .Apple && rd.fruit > 0 {
				add(&things, rd.pos, radius, fmt.tprintf("apple tree, %d apples on it (bump it)", rd.fruit))
			} else {
				add(&things, rd.pos, min(radius, 4), fmt.tprintf("tree (%v), in the way", rd.species))
			}
		case .Rock:
			add(&things, rd.pos, radius, fmt.tprintf("rock, %.0f kg", game.rock_kg(rd.r)))
		case .Bush:
			add(&things, rd.pos, radius, fmt.tprintf("berry bush, %d bunches, %.0f%% ripe", rd.fruit, rd.ripe * 100))
		case .Hive:
			add(&things, rd.pos, radius, "beehive")
		case .Salt_Rock:
			add(&things, rd.pos, radius, fmt.tprintf("salt rock, %d lumps", rd.fruit))
		case .Pebbles:
			add(&things, rd.pos, radius, fmt.tprintf("patch of pebbles, %d on it", rd.fruit))
		case .Stump:
			add(&things, rd.pos, min(radius, 4), rd.variant == 2 ? "a fallen log, in the way (jump it)" : "a mossy stump, in the way (jump it)")
		case .Scarecrow:
			add(&things, rd.pos, radius, "his scarecrow")
		case .Larder:
			if rd.r > 0 {
				add(&things, rd.pos, radius, "his larder")
			}
		}
	}
	// His fences: each piece by its middle, and which way it runs.
	if g.fence_count > 0 {
		for way in game.Fence_Way {
			for there, i in g.fences[way] {
				if there {
					f := game.Fence_At{i % (game.FENCE_W + 1), i / (game.FENCE_W + 1), way}
					a, b := game.fence_ends(f)
					if gate := game.gate_state(f); gate != 0 {
						add(&things, (a + b) / 2, radius, gate == game.GATE_OPEN ? "gate, open" : "gate, shut")
					} else {
						add(&things, (a + b) / 2, radius, way == .East ? "piece of fence, running left-right" : "piece of fence, running up-down")
					}
				}
			}
		}
		if game.fenced_in(p.pos) {
			fmt.println("he is standing inside a pen (fences all round)")
		}
	}
	for st, at in g.stations {
		if !game.station_standing(at) {
			continue
		}
		how := st.ready ? fmt.tprintf("ready: %d %s", st.count, game.TEXT.item_name[st.dish]) : (st.baking ? fmt.tprintf("busy, %.0f s to go", st.bake_t) : "empty")
		add(&things, st.pos, radius, at == .Camp ? fmt.tprintf("his campfire (%s)", how) : fmt.tprintf("the %v (%s)", at, how))
	}
	add(&things, g.mill.pos, radius, fmt.tprintf("the mill (%d sheaves grinding, %d flour ready)", g.mill.grinding, g.mill.ready))
	{
		d := game.POND - p.pos
		dist := math.sqrt(d.x * d.x + d.y * d.y)
		if dist - game.POND_RADIUS <= radius {
			fish := 0
			for f in g.fish {
				if f.away_t <= 0 {
					fish += 1
				}
			}
			bank := game.POND - d / max(dist, 0.01) * game.POND_RADIUS
			append(&things, Agent_Thing{max(dist - game.POND_RADIUS, 0), fmt.tprintf("%-34s %s", fmt.tprintf("the pond's bank (%d fish in it)", fish), agent_where(bank))})
		}
	}
	for c in g.pests {
		if c.state != .Away {
			add(&things, c.pos, radius, fmt.tprintf("%v, %v", c.kind, c.state))
		}
	}
	for h in g.hives {
		if h.angry_t > 0 {
			add(&things, h.swarm, radius, "a swarm of angry bees")
		}
	}
	slice.sort_by(things[:], proc(a, b: Agent_Thing) -> bool {return a.dist < b.dist})
	fmt.printfln("within %.0f m (nearest first; trees only within 4 m):", radius)
	if len(things) == 0 {
		fmt.println("  nothing")
	}
	for thing, i in things {
		if i == 40 {
			fmt.printfln("  ... and %d more, further off", len(things) - 40)
			break
		}
		fmt.printfln("  %s", thing.text)
	}
}

agent_facing :: proc() -> string {
	f := game.facing_dir(game.g.prosio.facing)
	side := abs(f.x) > 0.38 ? (f.x > 0 ? "right" : "left") : ""
	way := abs(f.y) > 0.38 ? (f.y > 0 ? "down" : "up") : ""
	return strings.trim_space(fmt.tprintf("%s %s", way, side))
}

agent_map :: proc() {
	g := &game.g
	fmt.println("The meadow runs from x -100 to 100 and y -70 to 70; home is at (0, 0). Right is larger x, down is larger y.")
	for r, kind in game.REGIONS {
		fmt.printfln("  %-14s %-52s %s%s", game.TEXT.region_name[kind], game.TEXT.region_about[kind], agent_where(r.centre), g.seen_region[kind] ? "" : "  (not been there)")
	}
	fmt.println("Fixed places:")
	for st, at in g.stations {
		if game.station_standing(at) {
			fmt.printfln("  %-14s %s", at == .Camp ? "his campfire" : fmt.tprintf("the %v", at), agent_where(st.pos))
		}
	}
	fmt.printfln("  %-14s %s", "the mill", agent_where(g.mill.pos))
	fmt.printfln("  %-14s %s  (%.1f m across)", "the pond", agent_where(game.POND), game.POND_RADIUS * 2)
}
