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
	Restart,
	Menu,
	Confirm,
	Look,
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
	.Restart = {.ENTER, .R, .KEY_NULL},
	.Menu    = {.ESCAPE, .P, .KEY_NULL},
	.Confirm = {.ENTER, .SPACE, .KP_ENTER},
	.Look    = {.V, .F1, .KEY_NULL},
}

// The two looks being compared. Both draw the same 3D scene:
//   Toy    soft clay-like shading straight to the screen, no outlines.
//   Pixel  hard cartoon shading with outlines, drawn into a small image that is
//          then enlarged without smoothing, so it comes out as crisp pixels.
Look :: enum i32 {
	Toy,
	Pixel,
}
look: Look = .Pixel

LOOK_NAMES := [Look]cstring {
	.Toy   = "TOY",
	.Pixel = "PIXEL",
}

// How fine the Pixel look is: about how many rows of pixels it has from top
// to bottom. Each game pixel is a whole number of real screen pixels, so the
// actual count is the nearest that fits the window.
Pixel_Detail :: enum {
	Chunky,
	Medium,
	Fine,
}
PIXEL_ROWS := [Pixel_Detail]f32 {
	.Chunky = 240,
	.Medium = 360,
	.Fine   = 480,
}
pixel_detail := Pixel_Detail.Medium

// Dark cartoon outlines around solid shapes. Their width is set each frame
// by the look: none for Toy, about one pixel for Pixel.
OUTLINE_COLOR :: Color{52, 40, 44, 255}
outline_width: f32
outlines_enabled := true

@(private = "file")
meshes: [Shape]rl.Mesh
@(private = "file")
material: rl.Material
@(private = "file")
camera: rl.Camera3D

// The Pixel look draws the world into this small image first.
@(private = "file")
pixel_view: struct {
	target:     rl.RenderTexture2D,
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
Surface :: enum i32 { Solid, Meadow, Leaf, Shadow, Bark, Stone, Jacket, Rect_Shadow }
flash_location: i32
surface_location: i32
@(private = "file")
uniforms: struct {
	look, view, fade, wind_time, sway: i32,
}
active_surface: Surface
set_surface :: proc(surface: Surface) {
	if surface != active_surface {
		active_surface = surface
		rl.SetShaderValue(material.shader, surface_location, &active_surface, .INT)
	}
}

// Hides part of what follows with a fine see-through pattern (0 = solid,
// 1 = gone). Used for trees standing between the camera and Prosio.
set_fade :: proc(amount: f32) {
	value := amount
	rl.SetShaderValue(material.shader, uniforms.fade, &value, .FLOAT)
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
	rl.InitWindow(width, height, title)
	rl.SetExitKey(.KEY_NULL)

	meshes[.Terrain] = rl.GenMeshPlane(2, 2, 44, 30)
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
	uniforms.look = rl.GetShaderLocation(material.shader, "look")
	uniforms.view = rl.GetShaderLocation(material.shader, "viewPos")
	uniforms.fade = rl.GetShaderLocation(material.shader, "fade")
	uniforms.wind_time = rl.GetShaderLocation(material.shader, "windTime")
	uniforms.sway = rl.GetShaderLocation(material.shader, "sway")
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

begin_world :: proc(eye, target: Vec3, fov_y: f32, time: f32) {
	eye, target, fov_y := eye, target, fov_y
	outline_width = 0
	if look == .Pixel {
		eye, target, fov_y = begin_pixel_view(eye, target, fov_y)
	}
	camera = rl.Camera3D {
		position   = eye,
		target     = target,
		up         = {0, 1, 0},
		fovy       = fov_y,
		projection = .PERSPECTIVE,
	}
	rl.BeginMode3D(camera)

	look_value := look
	view := eye
	wind := time
	no_fade: f32 = 0
	rl.SetShaderValue(material.shader, uniforms.look, &look_value, .INT)
	rl.SetShaderValue(material.shader, uniforms.view, &view, .VEC3)
	rl.SetShaderValue(material.shader, uniforms.wind_time, &wind, .FLOAT)
	rl.SetShaderValue(material.shader, uniforms.fade, &no_fade, .FLOAT)
	rl.SetShaderValue(material.shader, uniforms.sway, &no_fade, .FLOAT)
}

// Sets up the small image for the Pixel look, and returns the camera to draw
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
	device := max(1, math.round(rh / PIXEL_ROWS[pixel_detail]))
	v.scale = device * sh / rh // screen points per game pixel
	inner_w := i32(math.ceil(rw / device))
	inner_h := i32(math.ceil(rh / device))
	w, h := inner_w + 2 * PIXEL_MARGIN, inner_h + 2 * PIXEL_MARGIN
	if w != v.width || h != v.height {
		if v.width > 0 {
			rl.UnloadRenderTexture(v.target)
		}
		v.target = rl.LoadRenderTexture(w, h)
		rl.SetTextureFilter(v.target.texture, .POINT)
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

	rl.BeginTextureMode(v.target)
	rl.ClearBackground(rl.Color(v.clear))
	wide := 2 * math.atan(math.tan(half_fov) * f32(h) / f32(inner_h)) * math.DEG_PER_RAD
	return eye + shift, target + shift, wide
}

end_world :: proc() {
	rl.EndMode3D()
	if look == .Pixel {
		v := &pixel_view
		rl.EndTextureMode()
		edge := -PIXEL_MARGIN * v.scale
		source := rl.Rectangle{0, 0, f32(v.width), -f32(v.height)}
		dest := rl.Rectangle{edge + v.offset.x, edge + v.offset.y, f32(v.width) * v.scale, f32(v.height) * v.scale}
		rl.DrawTexturePro(v.target.texture, source, dest, {}, 0, rl.WHITE)
	}
}

draw_shape :: proc(shape: Shape, transform: Mat4, color: Color) {
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
	if look != .Pixel {
		return rl.GetWorldToScreen(pos, camera)
	}
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

// Darkens the edges of the screen a little, to draw the eye to the middle.
ui_vignette :: proc(strength: u8) {
	w, h := rl.GetScreenWidth(), rl.GetScreenHeight()
	edge := rl.Color{10, 20, 30, strength}
	none := rl.Color{10, 20, 30, 0}
	band_x, band_y := w / 6, h / 5
	rl.DrawRectangleGradientV(0, 0, w, band_y, edge, none)
	rl.DrawRectangleGradientV(0, h - band_y, w, band_y, none, edge)
	rl.DrawRectangleGradientH(0, 0, band_x, h, edge, none)
	rl.DrawRectangleGradientH(w - band_x, 0, band_x, h, none, edge)
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
