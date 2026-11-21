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
	detail:     int, // 1 to 6: pixel density to start with (0 = default)
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
	decor:         [MAX_DECOR]Decor,
	decor_count:   int,
	particles:     [MAX_PARTICLES]Particle,
	particle_next: int,
	thrown:        [MAX_THROWN]Thrown_Rock,
	oven:          Oven,
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
	Oven, // choosing what to bake; the game waits
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
	set_ground_layout() // the same in every game
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
	if opts.crowd {
		// For trying out the club: turkeys and goats close by, the first
		// turkey within reach.
		kinds := [?]Enemy_Kind{.Turkey, .Turkey, .Billy, .Goat}
		for kind, i in kinds {
			add_enemy(kind, g.prosio.pos + facing_dir(f32(i) * math.TAU / 4 + 0.4) * (i == 0 ? 1.15 : 2.6))
		}
	}
	if opts.stock {
		for it in Item {
			g.prosio.sack[it] = it < FIRST_DISH ? 3 : 1
		}
		g.prosio.sack_sel = .Apple_Pie
	}
	g.camera = g.prosio.pos
	g.camera_zoom = 1
}

// Tells the ground shader where the fields, paths and regions are.
set_ground_layout :: proc() {
	fields: [MAX_FIELDS][4]f32
	for f, i in g.fields[:g.field_count] {
		fields[i] = {f.lo.x, f.lo.y, f.hi.x, f.hi.y}
	}
	paths: [len(Region_Kind)][4]f32
	count := 0
	for kind in Region_Kind {
		if kind != .Home {
			paths[count] = {HOME.x, HOME.y, PATH_ENDS[kind].x, PATH_ENDS[kind].y}
			count += 1
		}
	}
	forest, hills := REGIONS[.Forest], REGIONS[.Hills]
	set_ground_uniforms(
		fields[:g.field_count],
		paths[:count],
		{forest.centre.x, forest.centre.y, forest.radius.x, forest.radius.y},
		{hills.centre.x, hills.centre.y, hills.radius.x, hills.radius.y},
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
			update_thrown(step)
			update_enemies(step)
			update_world(step)
			update_particles(step)
		}
		// Which part of the meadow he is in.
		region, inside := region_at(g.prosio.pos)
		if inside != g.in_region || region != g.region {
			g.region, g.in_region, g.region_t = region, inside, 0
		}
		g.region_t += dt
	}

	// The camera follows Prosio smoothly from above and behind.
	focus := g.prosio.pos
	zoom: f32 = 1
	if scene == .Menu {
		// A slow drift over the meadow round home.
		focus += {math.sin(g.time * 0.15) * 6, -3}
		zoom = 1.25
	}
	g.camera += (focus - g.camera) * (1 - math.exp(-5 * dt))
	g.camera_zoom += (zoom - g.camera_zoom) * (1 - math.exp(-4 * dt))
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
		draw_oven_menu()
	}

	if g.opts.shot_path != nil && g.frame == max(g.opts.shot_frame, 30) {
		save_screenshot(g.opts.shot_path)
		g.quit = true
	}
	end_frame()
}

// Everything that stands on the ground and casts a shadow.
draw_things :: proc() {
	draw_world()
	draw_oven()
	for f, i in g.foods[:g.food_count] {
		draw_food(f, i)
	}
	for e in g.enemies[:g.enemy_count] {
		draw_enemy(e)
	}
	draw_prosio()
	draw_grab()
}
