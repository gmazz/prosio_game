package game

import "core:math"

// Start-up options, used for testing.
Options :: struct {
	start_kg:   f32,
	start_pos:  Vec2,
	has_pos:    bool,
	near:       Enemy_Kind, // with has_near: one animal of this kind within reach in front of him, and no others
	has_near:   bool,
	far:        bool, // with has_near: five metres off, out of reach, to throw at
	pebbles:    bool, // start with six pebbles, chosen in the sack
	choose:     Item, // with has_choose: this is chosen in the sack at the start, if he has any
	has_choose: bool,
	built:      bool, // start with things built: a turkey in a pen beside him, a scarecrow, a spear in the ground, and wood and tools in the sack
	bruises:    f32, // start this bruised (points off the top of his stamina)
	agent:      bool, // played by a program, a step at a time (see main_desktop/agent.odin)
	shot_path:  cstring, // save a picture to this file and quit
	shot_frame: int,
	hold:       bit_set[Button], // buttons pressed on frame 10 and then held
	tap:        bit_set[Button], // buttons pressed once on frame tap_frame (10 if not set)
	tap_frame:  int,
	tap2:       bit_set[Button], // buttons pressed once on frame tap2_frame
	tap2_frame: int,
	release_at: int, // stop holding the --hold buttons on this frame
	menu:       bool, // start on the menu even in a test run
	crowd:      bool, // put a few animals round Prosio at the start
	bodies:     bool, // put a dead turkey, a dead goat and a fox round him at the start
	swimmers:   bool, // put a turkey and a goat swimming in the pond, and a drowned turkey floating
	stock:      bool, // start with a sack full of food
	needs:      [6]f32, // the levels of his stores and needs at the start, in the order of Need
	has_needs:  bool,
	traits:     [len(Trait)]f32, // his muscles and skills at the start, in the order of Trait
	has_traits: bool,
	outfit:     [11]u8, // what he wears, one number per row of the outfit menu
	has_outfit: bool,
	detail:     int, // 1 to 6: pixel density to start with (0 = default)
	seed:       u32, // builds a different meadow (0 = the usual one)
	no_save:    bool, // neither load nor save the saved game
}

Game :: struct {
	prosio:        Prosio,
	enemies:       [MAX_ENEMIES]Enemy,
	enemy_count:   int,
	rounds:        [MAX_ROUNDS]Round,
	round_count:   int,
	foods:         [MAX_FOODS]Food,
	food_count:    int,
	fields:        [MAX_FIELDS]Field,
	field_count:   int,
	burned:        [Burn_For]f32, // kg of fat and carbs burned so far, by what it went on
	grabs:         int, // how many times he has taken hold of something (for the testing tools)
	seen:          [MAP_W * MAP_H]bool, // the squares of the map he has uncovered
	seen_region:   [Region_Kind]bool, // the parts of the meadow he has been to
	decor:         [MAX_DECOR]Decor,
	decor_count:   int,
	particles:     [MAX_PARTICLES]Particle,
	particle_next: int,
	thrown:        [MAX_THROWN]Thrown_Rock,
	stations:      [Station_Kind]Station, // the oven, the fire and the churn
	fish:          [MAX_FISH]Fish,
	pests:         [MAX_PESTS]Pest,
	hives:         [MAX_HIVES]Hive,
	mill:          Mill,
	fences:        [Fence_Way][FENCE_POINTS]bool, // the pieces of fence he has put up (see workshop.odin)
	fence_count:   int,
	gates:         [Fence_Way][FENCE_POINTS]u8, // which pieces are gates, and whether open (GATE_SHUT, GATE_OPEN)
	larders:       [MAX_LARDERS]Larder,
	region:        Region_Kind, // where Prosio is, if in_region
	in_region:     bool,
	region_t:      f32, // how long he has been there
	camera:        Vec2, // the point on the ground the camera looks at
	camera_zoom:   f32, // 1 is the normal distance; larger is further away
	shake:         f32,
	time:          f32,
	frame:         int,
	rng:           u32,
	quit:          bool,
	first_step:    bool, // true during the first physics step of a frame
	opts:          Options,
}

// Where the camera sits, relative to the point it looks at.
CAMERA_OFFSET :: Vec3{0, 8.5, 10.6}

g: Game

// Which screen is showing. Kept outside Game so that starting a new game
// does not reset it.
Scene :: enum {
	Menu,
	Playing,
	Paused,
	Oven, // choosing what to make at the oven, the fire or the churn; the game waits
	Bag, // the sack and outfit menu; the game waits
	Larder, // moving things between the sack and a larder; the game waits
}

scene: Scene
menu_choice: int

init :: proc(opts: Options) {
	platform_init("Prosio", 1280, 720)
	g.opts = opts
	keyboard_enabled = opts.shot_path == nil && !opts.agent
	if opts.detail > 0 {
		pixel_level = clamp(opts.detail - 1, 0, PIXEL_LEVELS - 1)
	}
	if opts.has_outfit {
		for n, row in opts.outfit {
			change_outfit(Outfit_Row(row), int(n))
		}
	}
	continue_game()
	set_ground_layout() // the same in every game
	// Test runs go straight into the game.
	scene = ((opts.shot_path != nil || opts.agent) && !opts.menu) ? .Playing : .Menu
}

// Builds the meadow afresh and puts the saved Prosio in it, if there is one.
continue_game :: proc() {
	new_game()
	load_game()
	explore(g.prosio.pos)
}

// Throws the current game away and builds a fresh one, with a new Prosio.
new_game :: proc() {
	opts := g.opts
	g = {}
	g.opts = opts
	g.rng = opts.seed != 0 ? opts.seed : 0x2545f491 // the same meadow every time, unless a test asks for another
	reset_prosio()
	build_world()
	if opts.has_traits {
		for t in Trait {
			g.prosio.trait[t] = opts.traits[int(t)]
		}
		g.prosio.trait_was = g.prosio.trait
		g.prosio.kg = weight_with(g.prosio.fat)
	}
	if opts.has_pos {
		g.prosio.pos = opts.start_pos
	}
	if opts.crowd {
		// For trying out the club: turkeys and goats close by, the first
		// turkey within reach.
		kinds := [?]Enemy_Kind{.Turkey, .Turkey, .Billy, .Goat}
		for kind, i in kinds {
			add_enemy(kind, g.prosio.pos + facing_dir(f32(i) * math.TAU / 4 + 0.4) * (i == 0 ? 1.15 : 2.6))
		}
	}
	if opts.bruises > 0 {
		bruise(opts.bruises)
	}
	if opts.has_near {
		// For looking at one animal, and at how he holds it.
		g.enemy_count = 0
		add_enemy(opts.near, g.prosio.pos + facing_dir(0.9) * (opts.far ? 5 : prosio_radius(g.prosio.kg) + ENEMY_RADIUS[opts.near] + 0.3))
		if opts.far {
			g.enemies[0].timer = 600 // it stands where it is
			g.prosio.facing = 0.9
		}
	}
	if opts.pebbles {
		for _ in 0 ..< 6 {
			sack_add(.Pebble, 0)
		}
		g.prosio.sack_sel = .Pebble
	}
	if opts.built {
		// For looking at what he builds: a turkey in a pen of one square
		// beside him (its near side a gate), a larder with cheese and fish in it, a scarecrow, a spear in the ground, and wood and
		// tools in the sack with a piece of fence chosen.
		x, y := fence_cell(g.prosio.pos + {3, 0})
		for f in ([4]Fence_At{{x, y, .East}, {x, y + 1, .East}, {x, y, .South}, {x + 1, y, .South}}) {
			set_fence(f, true)
		}
		set_gate({x, y + 1, .East}, GATE_SHUT) // the side nearest the camera is a gate
		corner, _ := fence_ends({x, y, .East})
		g.enemy_count = 0
		add_enemy(.Turkey, corner + {FENCE_LEN, FENCE_LEN} / 2)
		add_scarecrow(g.prosio.pos + {-2.2, 0.6})
		add_larder(g.prosio.pos + {0.9, 3.6})
		g.larders[0].stock[.Cheese], g.larders[0].kcal[.Cheese], g.larders[0].fresh[.Cheese] = 2, 600, 1
		g.larders[0].stock[.Fish], g.larders[0].kcal[.Fish], g.larders[0].fresh[.Fish] = 3, 450, 0.6
		if f := add_food(.Spear, g.prosio.pos + {-1.2, 2.4}); f != nil {
			f.fallen, f.life, f.size = true, 1e9, 1
		}
		for it in ([?]Item{.Wood, .Fence, .Rod, .Spear, .Gate}) { // (14 litres: the sack holds 60)
			sack_add(it, 0)
		}
		g.prosio.sack_sel = .Fence
		g.prosio.facing = math.PI // towards the top of the screen
	}
	if opts.bodies {
		// For looking at bodies: a dead turkey within reach, a dead goat,
		// and a fox with something stolen in its mouth.
		kinds := [?]Enemy_Kind{.Turkey, .Goat, .Fox}
		for kind, i in kinds {
			add_enemy(kind, g.prosio.pos + facing_dir(f32(i) * 1.9 + 0.5) * (i == 0 ? 1.15 : 2.6))
			e := &g.enemies[g.enemy_count - 1]
			if kind == .Fox {
				// Its den is a long way off, so it is still making for it,
				// apple in mouth, when the picture is taken.
				e.has_loot, e.loot = true, .Apple
				e.home = e.pos + {-40, 40}
			} else {
				e.state, e.ko, e.body_t = .Dead, true, BODY_LIFE
			}
		}
	}
	if opts.bodies {
		// And a rabbit and a crow, caught close by and making off.
		for i in ([2]int{0, 2}) {
			c := &g.pests[i]
			c.pos = g.prosio.pos + (i == 0 ? Vec2{-2.4, 1.2} : Vec2{2.6, 2.2})
			c.state = .Fleeing
			c.y = i == 0 ? 0 : 1.2
		}
	}
	if opts.swimmers {
		// For looking at the pond: a turkey and a goat swimming for the bank
		// nearest him, and a turkey bottoms up.
		kinds := [3]Enemy_Kind{.Turkey, .Goat, .Turkey}
		spots := [3]Vec2{{2.8, 3}, {-1.5, 3.2}, {0.5, 0}}
		for kind, i in kinds {
			add_enemy(kind, POND + spots[i])
			e := &g.enemies[g.enemy_count - 1]
			e.state = .Swimming
			e.facing = 0
			if i == 2 {
				e.ko, e.health = true, 0
			}
		}
	}
	if opts.has_needs {
		for n in Need {
			g.prosio.need[n] = opts.needs[int(n)]
		}
		g.prosio.kg = body_kg()
	}
	if opts.start_kg > 0 {
		set_weight(opts.start_kg) // last, so it is the weight asked for whatever else was set
	}
	if opts.stock {
		for it in Item {
			for _ in 0 ..< (it < FIRST_DISH || it == .Wood ? 3 : 1) {
				sack_add(it, item_kcal(it))
			}
		}
		g.prosio.sack_sel = .Apple_Pie
	}
	if opts.has_choose && g.prosio.sack[opts.choose] > 0 {
		g.prosio.sack_sel = opts.choose
	}
	g.camera = g.prosio.pos
	g.camera_zoom = 1
	explore(g.prosio.pos)
}

// Tells the ground shader where the fields, paths and regions are.
set_ground_layout :: proc() {
	fields: [MAX_FIELDS][4]f32
	for f, i in g.fields[:g.field_count] {
		fields[i] = {f.lo.x, f.lo.y, f.hi.x, f.hi.y}
	}
	paths: [len(Region_Kind) + len(TRAILS)][4]f32
	count := 0
	for kind in Region_Kind {
		if kind != .Home {
			paths[count] = {HOME.x, HOME.y, PATH_ENDS[kind].x, PATH_ENDS[kind].y}
			count += 1
		}
	}
	for t in TRAILS {
		paths[count] = {t[0].x, t[0].y, t[1].x, t[1].y}
		count += 1
	}
	forest, hills := REGIONS[.Forest], REGIONS[.Hills]
	set_ground_uniforms(
		fields[:g.field_count],
		paths[:count],
		{forest.centre.x, forest.centre.y, forest.radius.x, forest.radius.y},
		{hills.centre.x, hills.centre.y, hills.radius.x, hills.radius.y},
		{POND.x, POND.y, POND_RADIUS, 0},
	)
}

shutdown :: proc() {
	platform_shutdown()
}

update_menu :: proc() {
	count := menu_length()
	if button_pressed(.Down) {
		menu_choice = (menu_choice + 1) % count
	}
	if button_pressed(.Up) {
		menu_choice = (menu_choice + count - 1) % count
	}
	if scene == .Paused && button_pressed(.Menu) {
		scene = .Playing
		return
	}
	if !button_pressed(.Confirm) {
		return
	}
	choice := menu_items()[menu_choice]
	if choice == .Look {
		pixel_level = (pixel_level + 1) % PIXEL_LEVELS // stays on the menu
		return
	}
	menu_choice = 0
	switch choice {
	case .Play:
		scene = .Playing // the game is already there, behind the menu
	case .Restart:
		// A new Prosio: the old one is forgotten.
		new_game()
		save_game()
		scene = .Playing
	case .Resume:
		scene = .Playing
	case .Exit_To_Menu:
		save_game()
		continue_game()
		scene = .Menu
	case .Quit:
		g.quit = true
	case .Look:
	}
}

// True only on the frame a button goes down, and only once per frame.
pressed :: proc(b: Button) -> bool {
	return g.first_step && button_pressed(b)
}

running :: proc() -> bool {
	return !g.quit && !window_should_close()
}

frame :: proc() {
	dt := min(frame_time(), 1.0 / 20)
	if g.opts.shot_path != nil {
		dt = 1.0 / 60 // test runs behave the same on every screen
	}
	g.frame += 1

	if g.frame >= 10 {
		forced_down = g.opts.hold
		if g.opts.release_at > 0 && g.frame >= g.opts.release_at {
			forced_down = {}
		}
		forced_pressed = g.frame == 10 ? g.opts.hold : {}
		if g.frame == max(g.opts.tap_frame, 10) {
			forced_pressed += g.opts.tap
		}
		if g.opts.tap2 != {} && g.frame == g.opts.tap2_frame {
			forced_pressed += g.opts.tap2
		}
	}

	update_frame(dt)
	draw_frame()
}

// A frame for a player that is a program (see the agent mode of the desktop
// build): these buttons are held, these go down on this frame, and a
// sixtieth of a second passes. Menus work as they do for a person. Nothing
// is drawn; draw_frame does that when a picture is wanted.
agent_frame :: proc(down, tap: bit_set[Button]) {
	g.frame += 1
	forced_down, forced_pressed = down, tap
	update_frame(1.0 / 60)
	forced_pressed = {}
}

// Everything that moves on in a frame: the menus or the game, and the camera.
update_frame :: proc(dt: f32) {
	// The pixel size can be changed at any time with the keys 1 to 6.
	if level := level_key_pressed(); level > 0 {
		pixel_level = level - 1
	}

	switch scene {
	case .Menu, .Paused:
		update_menu()
		if scene == .Menu {
			g.time += dt // the meadow stays alive behind the main menu
		}
	case .Oven:
		update_cook_menu(dt)
	case .Bag:
		update_bag(dt)
	case .Larder:
		update_larder_menu()
	case .Playing:
		if button_pressed(.Menu) {
			scene = .Paused
			menu_choice = 0
			save_game()
			break
		}
		if button_pressed(.Bag) && g.prosio.fail == .None {
			open_bag()
			break
		}
		// He is saved every so often as the game goes on.
		save_t -= dt
		if save_t <= 0 {
			save_t = 15
			save_game()
		}
		simulate(dt)
	}

	// The camera follows Prosio smoothly from above and behind.
	focus := g.prosio.pos
	zoom := view_zoom() // further back when his eyes are sharp, closer when they are dim
	if scene == .Menu {
		// A slow drift over the meadow round home.
		focus += {math.sin(g.time * 0.15) * 6, -3}
		zoom = 1.25
	}
	if scene == .Bag && bag_tab == .Outfit {
		// In close, with Prosio to the right of the menu.
		zoom = 0.42
		focus.x -= 1.3
	}
	g.camera += (focus - g.camera) * (1 - math.exp(-5 * dt))
	g.camera_zoom += (zoom - g.camera_zoom) * (1 - math.exp(-4 * dt))
}

// Draws the game as it stands. With a path, the picture is also saved there.
draw_frame :: proc(shot: cstring = nil) {
	shake := Vec3{math.sin(g.time * 71), math.sin(g.time * 53), 0} * g.shake * 0.25
	target := Vec3{g.camera.x, 0.8, g.camera.y} + shake
	eye := target + CAMERA_OFFSET * g.camera_zoom

	begin_frame(COLOR_SKY)
	// First the shadows: everything that stands in the sun, flattened onto
	// the ground along the sunlight. Then the ground, darkened where they
	// fall, and then everything else on top.
	begin_world(eye, target, 38, g.time)
	draw_things()
	begin_ground()
	draw_ground()
	apply_shadows()
	draw_things()
	draw_particles()
	end_world()
	switch scene {
	case .Menu:
		draw_menu()
	case .Playing:
		draw_ui()
	case .Paused:
		draw_ui()
		draw_menu()
	case .Oven:
		draw_ui()
		draw_cook_menu()
	case .Bag:
		draw_bag()
	case .Larder:
		draw_ui()
		draw_larder_menu()
	}

	if g.opts.shot_path != nil && g.frame == max(g.opts.shot_frame, 30) {
		save_screenshot(g.opts.shot_path)
		g.quit = true
	}
	if shot != nil {
		save_screenshot(shot)
	}
	end_frame()
}

// One frame of the game going on: everything moves on by dt. The tests in
// src/check run the game through this too, so they test what is played.
simulate :: proc(dt: f32) {
	g.time += dt
	// Physics runs in small fixed-size steps, so fast things cannot skip
	// through thin ones on a slow frame.
	steps := clamp(int(math.ceil(dt * 120)), 1, 6)
	for i in 0 ..< steps {
		g.first_step = i == 0
		step := dt / f32(steps)
		update_prosio(step)
		update_drag(step)
		update_thrown(step)
		update_enemies(step)
		update_world(step)
		update_particles(step)
		// His weight is the sum of his parts, whatever just changed them.
		g.prosio.kg = body_kg()
	}
	explore(g.prosio.pos)
	// Which part of the meadow he is in.
	region, inside := region_at(g.prosio.pos)
	if inside != g.in_region || region != g.region {
		g.region, g.in_region, g.region_t = region, inside, 0
	}
	g.region_t += dt
}

// Everything that stands on the ground and casts a shadow.
draw_things :: proc() {
	draw_world()
	draw_oven()
	draw_fire()
	draw_churn()
	draw_mill()
	draw_bench()
	draw_fences()
	for f, i in g.foods[:g.food_count] {
		draw_food(f, i)
	}
	for e in g.enemies[:g.enemy_count] {
		draw_enemy(e)
	}
	draw_pests()
	draw_bees()
	draw_prosio()
	draw_grab()
	draw_cast()
}
