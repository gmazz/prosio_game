package game

import "core:math"

// Start-up options, used for testing.
Options :: struct {
	start_kg:   f32,
	start_pos:  Vec2,
	has_pos:    bool,
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
	stock:      bool, // start with a sack full of food
	last_truffle: bool, // four truffles found, the fifth at his feet
	detail:     int, // 1 to 6: pixel density to start with (0 = default)
}

Game :: struct {
	prosio:        Prosio,
	enemies:       [MAX_ENEMIES]Enemy,
	enemy_count:   int,
	walls:         [MAX_WALLS]Wall,
	wall_count:    int,
	rounds:        [MAX_ROUNDS]Round,
	round_count:   int,
	foods:         [MAX_FOODS]Food,
	food_count:    int,
	truffles:      [5]Truffle,
	truffle_count: int,
	decor:         [MAX_DECOR]Decor,
	decor_count:   int,
	platforms:     [MAX_PLATFORMS]Platform,
	platform_count: int,
	tower:         int, // which platform is the catapult's jumping tower
	particles:     [MAX_PARTICLES]Particle,
	particle_next: int,
	door_pos:      Vec2,
	plate_pos:     Vec2,
	gates:         [2]Gate, // 0: the vault's, opened by the plate; 1: the cage's, opened by the lever
	seesaws:       [2]Seesaw,
	boulder:       Boulder,
	thrown:        [MAX_THROWN]Thrown_Rock,
	crate_pos:     Vec2,
	crate_round:   int,
	crate_broken:  bool,
	oven:          Oven,
	camera:        Vec2, // the point on the ground the camera looks at
	camera_zoom:   f32, // 1 is the normal distance; larger is further away
	shake:         f32,
	win_t:         f32,
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
	Oven, // choosing what to bake; the game waits
	Won, // all the truffles found
}

scene: Scene
menu_choice: int

init :: proc(opts: Options) {
	platform_init("Prosio", 1280, 720)
	g.opts = opts
	keyboard_enabled = opts.shot_path == nil
	if opts.detail > 0 {
		pixel_level = clamp(opts.detail - 1, 0, PIXEL_LEVELS - 1)
	}
	new_game()
	// Test runs go straight into the game.
	scene = (opts.shot_path != nil && !opts.menu) ? .Playing : .Menu
}

// Throws the current game away and builds a fresh one.
new_game :: proc() {
	opts := g.opts
	g = {}
	g.opts = opts
	g.rng = 0x2545f491
	reset_prosio()
	build_world()
	if opts.start_kg > 0 {
		g.prosio.kg = opts.start_kg
	}
	if opts.has_pos {
		g.prosio.pos = opts.start_pos
	}
	g.prosio.height, _ = ground_at(g.prosio.pos)
	if opts.crowd {
		// For trying out the club: turkeys and goats close by.
		kinds := [?]Enemy_Kind{.Turkey, .Turkey, .Billy, .Goat}
		for kind, i in kinds {
			add_enemy(kind, g.prosio.pos + facing_dir(f32(i) * math.TAU / 4 + 0.4) * (i == 0 ? 1.15 : 2.6)) // the first, a turkey, within reach
		}
	}
	if opts.stock {
		for it in Item {
			g.prosio.sack[it] = it < FIRST_DISH ? 3 : 1
		}
		g.prosio.sack_sel = .Apple_Pie
	}
	if opts.last_truffle {
		for &t, i in g.truffles {
			t.visible = true
			t.taken = i < 4
		}
		g.truffle_count = 4
		g.truffles[4].pos = g.prosio.pos + {0.9, 0}
	}
	g.camera_zoom = 1
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
	case .Play, .Restart, .Play_Again:
		new_game()
		scene = .Playing
	case .Resume:
		scene = .Playing
	case .Exit_To_Menu:
		new_game()
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
		update_oven_menu(dt)
	case .Won:
		update_menu()
		// Golden sparkles rain round the champion.
		g.time += dt
		g.win_t += dt
		for _ in 0 ..< 2 {
			p := g.prosio.pos
			a := random_range(0, math.TAU)
			at := Vec3{p.x + math.cos(a) * random_range(0.5, 2.5), random_range(2.5, 4), p.y + math.sin(a) * random_range(0.5, 2.5)}
			spawn_particle(at, {0, -0.5, 0}, random_range(1, 1.8), random_range(0.05, 0.09), random() < 0.3 ? COLOR_WHITE : COLOR_GOLD, 1.5)
		}
		update_particles(dt)
	case .Playing:
		if button_pressed(.Menu) {
			scene = .Paused
			menu_choice = 0
			break
		}
		g.time += dt
		// Physics runs in small fixed-size steps, so fast things cannot skip
		// through thin ones on a slow frame.
		steps := clamp(int(math.ceil(dt * 120)), 1, 6)
		for i in 0 ..< steps {
			g.first_step = i == 0
			step := dt / f32(steps)
			update_prosio(step)
			update_drag(step)
			update_seesaws(step)
			update_thrown(step)
			update_enemies(step)
			update_world(step)
			update_particles(step)
		}
		// All five truffles: a moment to enjoy it, then the end.
		if g.truffle_count == len(g.truffles) && g.win_t > 2.5 && g.prosio.fail == .None {
			scene = .Won
			menu_choice = 0
		}
	}

	// The camera follows Prosio smoothly from above and behind.
	// Near the catapult it pulls back to show the crate and the landing spot too.
	focus := g.prosio.pos
	zoom: f32 = 1
	if scene == .Menu {
		// A slow drift over the meadow.
		focus += {math.sin(g.time * 0.15) * 6, -3}
		zoom = 1.25
	}
	if scene == .Won {
		zoom = 0.8 // in close on the hero
	}
	catapult := g.seesaws[CATAPULT].pivot
	if !g.crate_broken && (length2(g.prosio.pos - catapult) < 8 || g.boulder.state == .Flying) {
		focus = (g.prosio.pos + g.crate_pos) / 2
		zoom = 1.4
	}
	g.camera += (focus - g.camera) * (1 - math.exp(-5 * dt))
	g.camera_zoom += (zoom - g.camera_zoom) * (1 - math.exp(-4 * dt))
	shake := Vec3{math.sin(g.time * 71), math.sin(g.time * 53), 0} * g.shake * 0.25
	target := Vec3{g.camera.x, 0.8, g.camera.y} + shake
	eye := target + CAMERA_OFFSET * g.camera_zoom

	begin_frame(COLOR_SKY)
	begin_world(eye, target, 38, g.time)
	draw_world()
	draw_seesaws()
	draw_oven()
	draw_throw_marker()
	for f, i in g.foods[:g.food_count] {
		draw_food(f, i)
	}
	for t in g.truffles {
		draw_truffle(t)
	}
	for e in g.enemies[:g.enemy_count] {
		draw_enemy(e)
	}
	draw_prosio()
	draw_grab()
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
		draw_oven_menu()
	case .Won:
		draw_won()
	}

	if g.opts.shot_path != nil && g.frame == max(g.opts.shot_frame, 30) {
		save_screenshot(g.opts.shot_path)
		g.quit = true
	}
	end_frame()
}
