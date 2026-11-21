package game

// The only file that talks to raylib.
// The rest of the game uses the small set of procedures below, so the
// library can be swapped later by rewriting this file alone.

import "core:math"
import "core:math/linalg"
import rl "vendor:raylib"
import "vendor:raylib/rlgl"

IS_WEB :: ODIN_ARCH == .wasm32 || ODIN_ARCH == .wasm64p32

Vec2 :: [2]f32
Vec3 :: [3]f32
Mat4 :: linalg.Matrix4f32
Color :: [4]u8

Shape :: enum {
	Sphere,     // radius 1, centred
	Hemisphere, // radius 1, dome rising from y = 0
	Cube,       // side 1, centred
	Cylinder,   // radius 1, from y = 0 to y = 1
	Cone,       // radius 1, base at y = 0, tip at y = 1
	Frustum,    // radius 1 at y = 0, narrowing to FRUSTUM_TOP at y = 1: tapered limbs
	Terrain,    // subdivided ground plane for perspective clipping near the camera
	Plane,      // horizontal 2 x 2 quad, centred
	Torus,      // ring lying in the XY plane
}

Button :: enum {
	Left,
	Right,
	Up,
	Down,
	Jump,
	Sprint,
	Bump,
	Action,
	Grab,
	Eat, // from the sack
	Sack_Prev,
	Sack_Next,
	Bag, // the sack and outfit menu
	Gas, // letting his wind go, once his gut is trained to hold it
	Restart,
	Menu,
	Confirm,
}

// Up to three keys per button.
@(private = "file")
KEYS := [Button][3]rl.KeyboardKey {
	.Left    = {.A, .LEFT, .KEY_NULL},
	.Right   = {.D, .RIGHT, .KEY_NULL},
	.Up      = {.W, .UP, .KEY_NULL},
	.Down    = {.S, .DOWN, .KEY_NULL},
	.Jump    = {.J, .X, .KEY_NULL},
	.Sprint  = {.LEFT_SHIFT, .RIGHT_SHIFT, .KEY_NULL},
	.Bump    = {.SPACE, .KEY_NULL, .KEY_NULL},
	.Action  = {.E, .K, .KEY_NULL},
	.Grab    = {.F, .L, .KEY_NULL},
	.Eat     = {.Q, .KEY_NULL, .KEY_NULL},
	.Sack_Prev = {.Z, .KEY_NULL, .KEY_NULL},
	.Sack_Next = {.C, .KEY_NULL, .KEY_NULL},
	.Bag     = {.M, .KEY_NULL, .KEY_NULL},
	.Gas     = {.G, .V, .KEY_NULL},
	.Restart = {.ENTER, .R, .KEY_NULL},
	.Menu    = {.ESCAPE, .P, .KEY_NULL},
	.Confirm = {.ENTER, .SPACE, .KP_ENTER},
}

// The world is drawn into a small image, which is then enlarged without
// smoothing, so it comes out as crisp pixels.
//
// How fine the pixels are: six levels, picked with the number keys 1 to 6.
// Each is about this many rows of pixels from top to bottom. Each game pixel
// is a whole number of real screen pixels (or, on a fine screen, a whole
// number and a half), so the actual count is the nearest that fits the window.
PIXEL_LEVELS :: 6
PIXEL_ROWS := [PIXEL_LEVELS]f32{180, 240, 320, 360, 420, 560}
pixel_level := 3 // 0 to PIXEL_LEVELS - 1

// The number key (1 to PIXEL_LEVELS) pressed this frame, or 0.
level_key_pressed :: proc() -> int {
	if !keyboard_enabled {
		return 0
	}
	KEYS := [PIXEL_LEVELS]rl.KeyboardKey{.ONE, .TWO, .THREE, .FOUR, .FIVE, .SIX}
	PAD := [PIXEL_LEVELS]rl.KeyboardKey{.KP_1, .KP_2, .KP_3, .KP_4, .KP_5, .KP_6}
	for i in 0 ..< PIXEL_LEVELS {
		if rl.IsKeyPressed(KEYS[i]) || rl.IsKeyPressed(PAD[i]) {
			return i + 1
		}
	}
	return 0
}

// Dark cartoon outlines around solid shapes, about one pixel wide.
OUTLINE_COLOR :: Color{52, 40, 44, 255}
outline_width: f32
outlines_enabled := true

@(private = "file")
meshes: [Shape]rl.Mesh
@(private = "file")
material: rl.Material
@(private = "file")
camera: rl.Camera3D

// The world is drawn into this small image first.
@(private = "file")
pixel_view: struct {
	target:     rl.RenderTexture2D,
	shadows:    rl.RenderTexture2D, // the same size: white, and grey where shadows fall
	width:      i32, // size of the image, including a border of PIXEL_MARGIN
	height:     i32,
	scale:      f32, // screen points per image pixel
	offset:     Vec2, // fine shift that keeps scrolling smooth
	clear:      Color,
}
@(private = "file")
PIXEL_MARGIN :: 1

// Share the lighting and paint code between desktop OpenGL and WebGL.
VERTEX_BODY :: #load("shaders/scene.vert", string)
FRAGMENT_BODY :: #load("shaders/scene.frag", string)
when IS_WEB {
	VERTEX_SHADER :: "#version 100\n#define ATTR attribute\n#define VARY varying\n" + VERTEX_BODY + "\x00"
	FRAGMENT_SHADER :: "#version 100\nprecision highp float;\n#define VARY varying\n#define OUT_COLOR gl_FragColor\n#define SAMPLE texture2D\n" + FRAGMENT_BODY + "\x00"
} else {
	VERTEX_SHADER :: "#version 330\n#define ATTR in\n#define VARY out\n" + VERTEX_BODY + "\x00"
	FRAGMENT_SHADER :: "#version 330\n#define VARY in\nout vec4 finalColor;\n#define OUT_COLOR finalColor\n#define SAMPLE texture\n" + FRAGMENT_BODY + "\x00"
}

// How the shader paints a surface. The numbers must match scene.frag.
Surface :: enum i32 { Solid, Meadow, Leaf, Shadow_Mask, Bark, Stone, Jacket, Stripes }
flash_location: i32
surface_location: i32
@(private = "file")
uniforms: struct {
	fade, wind_time, sway: i32,
	fields, field_count, paths, path_count, forest, hills, pond: i32,
}
active_surface: Surface
set_surface :: proc(surface: Surface) {
	if surface != active_surface && !shadow_pass {
		active_surface = surface
		rl.SetShaderValue(material.shader, surface_location, &active_surface, .INT)
	}
}

// Hides part of what follows with a fine see-through pattern (0 = solid,
// 1 = gone). Used for trees standing between the camera and Prosio. Their
// shadows stay whole.
set_fade :: proc(amount: f32) {
	if shadow_pass {
		return
	}
	value := amount
	rl.SetShaderValue(material.shader, uniforms.fade, &value, .FLOAT)
}

// Shadows. Everything is first drawn flattened onto the ground along the
// sunlight, in grey, into an image of its own. The ground is then drawn, and
// that image multiplied over it: so a shadow is the colour of whatever it
// falls on, only darker, whatever its shape, and where shadows overlap they
// are no darker than one.
SUN :: Vec3{-0.62, 0.89, 0.43} // towards the sun; must match scene.frag
SHADOW_INK :: Color{150, 150, 166, 255} // how much of the light a shadow lets through
@(private = "file")
shadow_pass: bool
@(private = "file")
FLATTEN :: Mat4 {
	1, -SUN.x / SUN.y, 0, 0,
	0, 0, 0, 0.02,
	0, -SUN.z / SUN.y, 1, 0,
	0, 0, 0, 1,
}

drawing_shadows :: proc() -> bool {
	return shadow_pass
}

// Where the fields, paths and regions are, for painting the ground. Each
// field and region is {x0, z0, x1, z1} or {centre x, centre z, radius x,
// radius z}; each path is a segment {x0, z0, x1, z1}.
set_ground_uniforms :: proc(fields: [][4]f32, paths: [][4]f32, forest, hills, pond: [4]f32) {
	sh := material.shader
	fc, pc := i32(len(fields)), i32(len(paths))
	if fc > 0 {
		rl.SetShaderValueV(sh, uniforms.fields, raw_data(fields), .VEC4, fc)
	}
	if pc > 0 {
		rl.SetShaderValueV(sh, uniforms.paths, raw_data(paths), .VEC4, pc)
	}
	rl.SetShaderValue(sh, uniforms.field_count, &fc, .INT)
	rl.SetShaderValue(sh, uniforms.path_count, &pc, .INT)
	f, h, w := forest, hills, pond
	rl.SetShaderValue(sh, uniforms.forest, &f, .VEC4)
	rl.SetShaderValue(sh, uniforms.hills, &h, .VEC4)
	rl.SetShaderValue(sh, uniforms.pond, &w, .VEC4)
}

// How far what follows sways in the wind at its top (leaves).
set_sway :: proc(amount: f32) {
	value := amount
	rl.SetShaderValue(material.shader, uniforms.sway, &value, .FLOAT)
}

@(private = "file")
flash_value: f32

set_hit_flash :: proc(strength: f32) {
	flash_value = strength
	value := strength
	rl.SetShaderValue(material.shader, flash_location, &value, .FLOAT)
}

platform_init :: proc(title: cstring, width, height: i32) {
	flags := rl.ConfigFlags{.MSAA_4X_HINT, .VSYNC_HINT, .WINDOW_RESIZABLE}
	when !IS_WEB {
		flags += {.WINDOW_HIGHDPI}
	}
	rl.SetConfigFlags(flags)
	rl.SetTraceLogLevel(.WARNING) // no chatter about every file saved
	rl.InitWindow(width, height, title)
	rl.SetExitKey(.KEY_NULL)

	meshes[.Terrain] = rl.GenMeshPlane(2, 2, 80, 56)
	meshes[.Plane] = rl.GenMeshPlane(2, 2, 1, 1)
	meshes[.Sphere] = rl.GenMeshSphere(1, 20, 28)
	meshes[.Hemisphere] = rl.GenMeshHemiSphere(1, 12, 28)
	meshes[.Cube] = rl.GenMeshCube(1, 1, 1)
	meshes[.Cylinder] = rl.GenMeshCylinder(1, 1, 28)
	meshes[.Cone] = rl.GenMeshCone(1, 1, 20)
	meshes[.Frustum] = gen_frustum(FRUSTUM_TOP, 20)
	meshes[.Torus] = rl.GenMeshTorus(0.45, 1, 14, 28)

	material = rl.LoadMaterialDefault()
	material.shader = rl.LoadShaderFromMemory(cstring(raw_data(VERTEX_SHADER)), cstring(raw_data(FRAGMENT_SHADER)))
	surface_location = rl.GetShaderLocation(material.shader, "surface")
	flash_location = rl.GetShaderLocation(material.shader, "hitFlash")
	uniforms.fade = rl.GetShaderLocation(material.shader, "fade")
	uniforms.wind_time = rl.GetShaderLocation(material.shader, "windTime")
	uniforms.sway = rl.GetShaderLocation(material.shader, "sway")
	uniforms.fields = rl.GetShaderLocation(material.shader, "fields")
	uniforms.field_count = rl.GetShaderLocation(material.shader, "fieldCount")
	uniforms.paths = rl.GetShaderLocation(material.shader, "paths")
	uniforms.path_count = rl.GetShaderLocation(material.shader, "pathCount")
	uniforms.forest = rl.GetShaderLocation(material.shader, "forest")
	uniforms.hills = rl.GetShaderLocation(material.shader, "hills")
	uniforms.pond = rl.GetShaderLocation(material.shader, "pond")
}

// How much a tapered limb narrows from one end to the other.
FRUSTUM_TOP :: f32(0.62)

// A cone with its tip cut off, with smooth sides and flat ends. Raylib has no
// such shape, so it is built here, once, at start-up.
@(private = "file")
gen_frustum :: proc(top: f32, slices: int) -> rl.Mesh {
	triangles := slices * 4 // two per side panel, one per panel on each end
	mesh: rl.Mesh
	mesh.triangleCount = i32(triangles)
	mesh.vertexCount = i32(triangles * 3)
	floats := uint(triangles * 9)
	mesh.vertices = cast([^]f32)rl.MemAlloc(u32(floats * size_of(f32)))
	mesh.normals = cast([^]f32)rl.MemAlloc(u32(floats * size_of(f32)))
	mesh.texcoords = cast([^]f32)rl.MemAlloc(u32(uint(triangles * 6) * size_of(f32)))
	count := 0
	add :: proc(mesh: ^rl.Mesh, count: ^int, a, b, c, na, nb, nc: Vec3) {
		// Wind each triangle so it faces the way its normals point.
		b, c, nb, nc := b, c, nb, nc
		if linalg.dot(linalg.cross(b - a, c - a), na + nb + nc) < 0 {
			b, c = c, b
			nb, nc = nc, nb
		}
		points := [3]Vec3{a, b, c}
		normals := [3]Vec3{na, nb, nc}
		for k in 0 ..< 3 {
			i := count^ * 3
			mesh.vertices[i], mesh.vertices[i + 1], mesh.vertices[i + 2] = points[k].x, points[k].y, points[k].z
			mesh.normals[i], mesh.normals[i + 1], mesh.normals[i + 2] = normals[k].x, normals[k].y, normals[k].z
			mesh.texcoords[count^ * 2], mesh.texcoords[count^ * 2 + 1] = 0, 0
			count^ += 1
		}
	}
	slope := 1 - top // the side leans in by this much over its height
	for i in 0 ..< slices {
		a0 := f32(i) / f32(slices) * math.TAU
		a1 := f32(i + 1) / f32(slices) * math.TAU
		c0, s0 := math.cos(a0), math.sin(a0)
		c1, s1 := math.cos(a1), math.sin(a1)
		b0, b1 := Vec3{c0, 0, s0}, Vec3{c1, 0, s1}
		t0, t1 := Vec3{c0 * top, 1, s0 * top}, Vec3{c1 * top, 1, s1 * top}
		n0 := linalg.normalize(Vec3{c0, slope, s0})
		n1 := linalg.normalize(Vec3{c1, slope, s1})
		add(&mesh, &count, b0, b1, t1, n0, n1, n1)
		add(&mesh, &count, b0, t1, t0, n0, n1, n0)
		add(&mesh, &count, {0, 0, 0}, b1, b0, {0, -1, 0}, {0, -1, 0}, {0, -1, 0})
		add(&mesh, &count, {0, 1, 0}, t0, t1, {0, 1, 0}, {0, 1, 0}, {0, 1, 0})
	}
	rl.UploadMesh(&mesh, false)
	return mesh
}

platform_shutdown :: proc() {
	if pixel_view.width > 0 {
		rl.UnloadRenderTexture(pixel_view.target)
		rl.UnloadRenderTexture(pixel_view.shadows)
	}
	for mesh in meshes {
		rl.UnloadMesh(mesh)
	}
	rl.UnloadMaterial(material)
	rl.CloseWindow()
}

window_should_close :: proc() -> bool {
	when IS_WEB {
		// A browser tab is closed by the browser; asking raylib would stall the page.
		return false
	} else {
		return rl.WindowShouldClose()
	}
}

set_window_size :: proc(width, height: int) {
	rl.SetWindowSize(i32(width), i32(height))
}

frame_time :: proc() -> f32 {
	return rl.GetFrameTime()
}

screen_size :: proc() -> (w, h: f32) {
	return f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight())
}

begin_frame :: proc(clear: Color) {
	rl.BeginDrawing()
	rl.ClearBackground(rl.Color(clear))
	pixel_view.clear = clear
}

end_frame :: proc() {
	rl.EndDrawing()
}

// Starts a frame of the world, with the shadow pass: until begin_ground,
// everything drawn is a shadow.
begin_world :: proc(eye, target: Vec3, fov_y: f32, time: f32) {
	snapped_eye, snapped_target, wide_fov := begin_pixel_view(eye, target, fov_y)
	camera = rl.Camera3D {
		position   = snapped_eye,
		target     = snapped_target,
		up         = {0, 1, 0},
		fovy       = wide_fov,
		projection = .PERSPECTIVE,
	}
	wind := time
	no_fade: f32 = 0
	rl.SetShaderValue(material.shader, uniforms.wind_time, &wind, .FLOAT)
	rl.SetShaderValue(material.shader, uniforms.fade, &no_fade, .FLOAT)
	rl.SetShaderValue(material.shader, uniforms.sway, &no_fade, .FLOAT)

	rl.BeginTextureMode(pixel_view.shadows)
	rl.ClearBackground(rl.WHITE)
	rl.BeginMode3D(camera)
	set_surface(.Shadow_Mask)
	shadow_pass = true
	// Flattened, a shape may face either way: draw both sides.
	rlgl.DisableBackfaceCulling()
}

// The shadows are done: now the world itself, starting with the ground.
begin_ground :: proc() {
	rl.EndMode3D()
	rl.EndTextureMode()
	rlgl.EnableBackfaceCulling()
	shadow_pass = false
	set_surface(.Solid)
	v := &pixel_view
	rl.BeginTextureMode(v.target)
	rl.ClearBackground(rl.Color(v.clear))
	rl.BeginMode3D(camera)
}

// Darkens the ground drawn so far wherever a shadow falls.
apply_shadows :: proc() {
	rl.EndMode3D()
	v := &pixel_view
	rl.BeginBlendMode(.MULTIPLIED)
	rl.DrawTextureRec(v.shadows.texture, {0, 0, f32(v.width), -f32(v.height)}, {0, 0}, rl.WHITE)
	rl.EndBlendMode()
	rl.BeginMode3D(camera)
}

// Sets up the small image, and returns the camera to draw
// it with.
//
// The camera is snapped to whole pixels of the image, so that the scenery
// does not shimmer as it scrolls; the part of the movement that snapping
// leaves out is made up by shifting the enlarged image by less than a pixel.
@(private = "file")
begin_pixel_view :: proc(eye, target: Vec3, fov_y: f32) -> (Vec3, Vec3, f32) {
	v := &pixel_view
	// Work in real screen pixels: on a high-resolution screen there are more of
	// them than layout points, which allows finer steps between densities.
	_, sh := screen_size()
	rw, rh := f32(rl.GetRenderWidth()), f32(rl.GetRenderHeight())
	// Every level gets its own pixel size, coarser than the level above it,
	// as far as the window allows. Where a game pixel is several real pixels
	// wide (a high-resolution screen), it may also be a whole number and a
	// half: the pixels then alternate by one real pixel, too little to see,
	// and there is room for levels between the whole sizes.
	device: f32 = 1e9
	for level in 0 ..= pixel_level {
		want := rh / PIXEL_ROWS[level]
		size := math.round(want)
		step: f32 = 1
		if want >= 3.5 {
			size = math.round(want * 2) / 2
			step = 0.5
		}
		device = max(1, min(size, device - step))
	}
	v.scale = device * sh / rh // screen points per game pixel
	inner_w := i32(math.ceil(rw / device))
	inner_h := i32(math.ceil(rh / device))
	w, h := inner_w + 2 * PIXEL_MARGIN, inner_h + 2 * PIXEL_MARGIN
	if w != v.width || h != v.height {
		if v.width > 0 {
			rl.UnloadRenderTexture(v.target)
			rl.UnloadRenderTexture(v.shadows)
		}
		v.target = rl.LoadRenderTexture(w, h)
		v.shadows = rl.LoadRenderTexture(w, h)
		rl.SetTextureFilter(v.target.texture, .POINT)
		rl.SetTextureFilter(v.shadows.texture, .POINT)
		v.width, v.height = w, h
	}

	forward := linalg.normalize(target - eye)
	right := linalg.normalize(linalg.cross(forward, Vec3{0, 1, 0}))
	up := linalg.cross(right, forward)
	half_fov := fov_y * math.RAD_PER_DEG / 2
	texel := 2 * linalg.length(target - eye) * math.tan(half_fov) / f32(inner_h)
	a, b := linalg.dot(target, right), linalg.dot(target, up)
	da := math.round(a / texel) * texel - a
	db := math.round(b / texel) * texel - b
	shift := right * da + up * db
	v.offset = {da / texel * v.scale, -db / texel * v.scale}

	// Outlines about one pixel wide, measured where the camera looks.
	outline_width = texel * 0.9

	wide := 2 * math.atan(math.tan(half_fov) * f32(h) / f32(inner_h)) * math.DEG_PER_RAD
	return eye + shift, target + shift, wide
}

end_world :: proc() {
	rl.EndMode3D()
	v := &pixel_view
	rl.EndTextureMode()
	edge := -PIXEL_MARGIN * v.scale
	source := rl.Rectangle{0, 0, f32(v.width), -f32(v.height)}
	dest := rl.Rectangle{edge + v.offset.x, edge + v.offset.y, f32(v.width) * v.scale, f32(v.height) * v.scale}
	rl.DrawTexturePro(v.target.texture, source, dest, {}, 0, rl.WHITE)
}

draw_shape :: proc(shape: Shape, transform: Mat4, color: Color) {
	if shadow_pass {
		if shape != .Terrain && shape != .Plane {
			material.maps[rl.MaterialMapIndex.ALBEDO].color = rl.Color(SHADOW_INK)
			rl.DrawMesh(meshes[shape], material, rl.Matrix(FLATTEN * transform))
		}
		return
	}
	if outlines_enabled && outline_width > 0 && color.a == 255 && shape != .Torus && shape != .Plane && shape != .Terrain {
		draw_outline(shape, transform)
	}
	material.maps[rl.MaterialMapIndex.ALBEDO].color = rl.Color(color)
	rl.DrawMesh(meshes[shape], material, rl.Matrix(transform))
}

// The outline is the same shape drawn slightly bigger and inside out, so only
// its rim shows around the real one.
@(private = "file")
draw_outline :: proc(shape: Shape, m: Mat4) {
	size := Vec3 {
		linalg.length(Vec3{m[0, 0], m[1, 0], m[2, 0]}),
		linalg.length(Vec3{m[0, 1], m[1, 1], m[2, 1]}),
		linalg.length(Vec3{m[0, 2], m[1, 2], m[2, 2]}),
	}
	if min(size.x, size.y, size.z) < 0.06 {
		return // flat markings and tiny details get no outline
	}
	w := outline_width
	grow: Vec3
	shift: Vec3
	switch shape {
	case .Sphere:
		grow = {1 + w / size.x, 1 + w / size.y, 1 + w / size.z}
	case .Cube:
		grow = {1 + 2 * w / size.x, 1 + 2 * w / size.y, 1 + 2 * w / size.z}
	case .Hemisphere, .Cylinder, .Cone, .Frustum:
		// These stand on their base, so they also grow downwards.
		grow = {1 + w / size.x, 1 + 2 * w / size.y, 1 + w / size.z}
		shift = {0, -w / size.y, 0}
	case .Torus, .Plane, .Terrain:
		return
	}
	hull := m * linalg.matrix4_translate_f32(shift) * linalg.matrix4_scale_f32(grow)
	material.maps[rl.MaterialMapIndex.ALBEDO].color = rl.Color(OUTLINE_COLOR)
	// A hit flash brightens the body, not its outline.
	flash := flash_value
	if flash > 0 {
		set_hit_flash(0)
	}
	rlgl.SetCullFace(.FRONT)
	rl.DrawMesh(meshes[shape], material, rl.Matrix(hull))
	rlgl.SetCullFace(.BACK)
	if flash > 0 {
		set_hit_flash(flash)
	}
}

world_to_screen :: proc(pos: Vec3) -> Vec2 {
	v := &pixel_view
	p := rl.GetWorldToScreenEx(pos, camera, v.width, v.height)
	edge := -PIXEL_MARGIN * v.scale
	return p * v.scale + {edge + v.offset.x, edge + v.offset.y}
}

// Buttons held by a test script instead of the keyboard.
forced_down: bit_set[Button]
forced_pressed: bit_set[Button]
// Test runs switch the real keyboard off so stray key presses cannot disturb them.
keyboard_enabled := true

button_down :: proc(b: Button) -> bool {
	if b in forced_down {
		return true
	}
	if !keyboard_enabled {
		return false
	}
	for key in KEYS[b] {
		if key != .KEY_NULL && rl.IsKeyDown(key) {
			return true
		}
	}
	return false
}

button_pressed :: proc(b: Button) -> bool {
	if b in forced_pressed {
		return true
	}
	if !keyboard_enabled {
		return false
	}
	for key in KEYS[b] {
		if key != .KEY_NULL && rl.IsKeyPressed(key) {
			return true
		}
	}
	return false
}

ui_rect :: proc(x, y, w, h: f32, color: Color) {
	rl.DrawRectangleRec({x, y, w, h}, rl.Color(color))
}

ui_circle :: proc(x, y, r: f32, color: Color) {
	rl.DrawCircleV({x, y}, r, rl.Color(color))
}

ui_round_rect :: proc(x, y, w, h: f32, color: Color, roundness: f32 = 0.5) {
	rl.DrawRectangleRounded({x, y, w, h}, roundness, 8, rl.Color(color))
}

ui_text :: proc(text: cstring, x, y, size: f32, color: Color) {
	rl.DrawText(text, i32(x), i32(y), i32(size), rl.Color(color))
}

ui_text_width :: proc(text: cstring, size: f32) -> f32 {
	return f32(rl.MeasureText(text, i32(size)))
}

// Formats a number into a short text, e.g. ui_format("%d kg", 80).
ui_format :: proc(format: cstring, value: i32) -> cstring {
	return rl.TextFormat(format, value)
}

// The same with a name, e.g. ui_format_name("my %s", "PIE").
ui_format_name :: proc(format: cstring, name: cstring) -> cstring {
	return rl.TextFormat(format, name)
}

// The same with two numbers, e.g. ui_format2("%d/%d", 2, 3).
ui_format2 :: proc(format: cstring, a, b: i32) -> cstring {
	return rl.TextFormat(format, a, b)
}

// Darkens the edges of the screen a little, to draw the eye to the middle.
// reach is how far in the dark comes: 1 is the usual narrow band.
ui_vignette :: proc(strength: u8, reach: f32 = 1) {
	w, h := rl.GetScreenWidth(), rl.GetScreenHeight()
	edge := rl.Color{10, 20, 30, strength}
	none := rl.Color{10, 20, 30, 0}
	band_x, band_y := i32(f32(w) / 6 * reach), i32(f32(h) / 5 * reach)
	rl.DrawRectangleGradientV(0, 0, w, band_y, edge, none)
	rl.DrawRectangleGradientV(0, h - band_y, w, band_y, none, edge)
	rl.DrawRectangleGradientH(0, 0, band_x, h, edge, none)
	rl.DrawRectangleGradientH(w - band_x, 0, band_x, h, none, edge)
}

// Keeping the saved game from one sitting to the next: in a file beside the
// program on the desktop, and in the browser's own storage on the web (the
// page provides the two procedures: see index_template.html).
SAVE_FILE :: "prosio.sav"

when IS_WEB {
	foreign import store "prosio_store"
	@(default_calling_convention = "c")
	foreign store {
		store_save :: proc(data: [^]u8, size: i32) ---
		store_load :: proc(data: [^]u8, room: i32) -> i32 ---
	}
}

store_write :: proc(data: []u8) {
	when IS_WEB {
		store_save(raw_data(data), i32(len(data)))
	} else {
		rl.SaveFileData(rl.TextFormat("%s%s", rl.GetApplicationDirectory(), cstring(SAVE_FILE)), raw_data(data), i32(len(data)))
	}
}

// Reads what was saved into data, and says how many bytes there were (0 if
// nothing was saved, or it does not fit).
store_read :: proc(data: []u8) -> int {
	when IS_WEB {
		return int(store_load(raw_data(data), i32(len(data))))
	} else {
		path := rl.TextFormat("%s%s", rl.GetApplicationDirectory(), cstring(SAVE_FILE))
		if !rl.FileExists(path) {
			return 0
		}
		size: i32
		bytes := rl.LoadFileData(path, &size)
		if bytes == nil {
			return 0
		}
		defer rl.UnloadFileData(bytes)
		if int(size) > len(data) {
			return 0
		}
		copy(data, bytes[:size])
		return int(size)
	}
}

save_screenshot :: proc(path: cstring) {
	// Entering and leaving 2D mode flushes pending UI drawing first.
	rl.BeginMode2D({zoom = 1})
	rl.EndMode2D()
	img := rl.LoadImageFromScreen()
	// On high-resolution screens raylib reads more than was drawn; keep the drawn part.
	rw, rh := rl.GetRenderWidth(), rl.GetRenderHeight()
	if img.width > rw {
		rl.ImageCrop(&img, {0, f32(img.height - rh), f32(rw), f32(rh)})
	}
	rl.ExportImage(img, path)
	rl.UnloadImage(img)
}
