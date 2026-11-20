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
	toy:        bool, // start in the Toy look
	crowd:      bool, // put a few animals round Prosio at the start
	detail:     int, // 1, 2 or 3: pixel density to start with (0 = default)
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
}

scene: Scene
menu_choice: int

init :: proc(opts: Options) {
	platform_init("Prosio", 1280, 720)
	g.opts = opts
	keyboard_enabled = opts.shot_path == nil
	if opts.toy {
		look = .Toy
	}
	if opts.detail > 0 {
		pixel_detail = Pixel_Detail(clamp(opts.detail - 1, 0, 2))
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
		// For trying out the club: three foxes and a boar close by.
		kinds := [?]Enemy_Kind{.Fox, .Fox, .Boar, .Fox}
		for kind, i in kinds {
			add_enemy(kind, g.prosio.pos + facing_dir(f32(i) * math.TAU / 4 + 0.4) * 3.2)
		}
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
		toggle_look() // stays on the menu
		return
	}
	menu_choice = 0
	switch choice {
	case .Play, .Restart:
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

// Cycles Toy, then the Pixel look from chunky to fine, then back to Toy.
toggle_look :: proc() {
	switch {
	case look == .Toy:
		look = .Pixel
		pixel_detail = .Chunky
	case pixel_detail == .Fine:
		look = .Toy
	case:
		pixel_detail = Pixel_Detail(int(pixel_detail) + 1)
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

	// The look can be switched at any time.
	if button_pressed(.Look) {
		toggle_look()
	}

	switch scene {
	case .Menu, .Paused:
		update_menu()
		if scene == .Menu {
			g.time += dt // the meadow stays alive behind the main menu
		}
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
	draw_snatch_aim()
	draw_particles()
	end_world()
	if scene == .Menu {
		draw_menu()
	} else {
		draw_ui()
		if scene == .Paused {
			draw_menu()
		}
	}

	if g.opts.shot_path != nil && g.frame == max(g.opts.shot_frame, 30) {
		save_screenshot(g.opts.shot_path)
		g.quit = true
	}
	end_frame()
}
