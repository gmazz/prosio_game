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

pixel_level := 3 // 0 to PIXEL_LEVELS - 1

// The number key (1 to PIXEL_LEVELS) pressed this frame, or 0.
level_key_pressed :: proc() -> int {
	if !keyboard_enabled {
		return 0
	}
	KEYS := [PIXEL_LEVELS]rl.KeyboardKey{.ONE, .TWO, .THREE, .FOUR, .FIVE, .SIX, .SEVEN, .EIGHT, .NINE}
	PAD := [PIXEL_LEVELS]rl.KeyboardKey{.KP_1, .KP_2, .KP_3, .KP_4, .KP_5, .KP_6, .KP_7, .KP_8, .KP_9}
	for i in 0 ..< PIXEL_LEVELS {
		if rl.IsKeyPressed(KEYS[i]) || rl.IsKeyPressed(PAD[i]) {
			return i + 1
		}
	}
	return 0
}

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
	world_half, fog: i32,
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
set_ground_uniforms :: proc(fields: [][4]f32, paths: [][4]f32, forest, hills, pond: [4]f32, edge: Vec2) {
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
	// The edge of the meadow, and the fog beyond it.
	e := edge
	fog := [2]f32{FOG_START, FOG_THICK}
	rl.SetShaderValue(sh, uniforms.world_half, &e, .VEC2)
	rl.SetShaderValue(sh, uniforms.fog, &fog, .VEC2)
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
	when !FOX_PROCEDURAL {init_fox_meshes()}
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
	uniforms.world_half = rl.GetShaderLocation(material.shader, "worldHalf")
	outline_location = rl.GetShaderLocation(material.shader, "outlineExpansion")
	uniforms.fog = rl.GetShaderLocation(material.shader, "fog")
	init_quad_meshes()
	when PROSIO_BASE { init_prosio_base_mesh() }
	init_tree_meshes()
	init_font()
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
	when !FOX_PROCEDURAL {for mesh in fox_meshes {rl.UnloadMesh(mesh)}}
	if pixel_view.width > 0 {
		rl.UnloadRenderTexture(pixel_view.target)
		rl.UnloadRenderTexture(pixel_view.shadows)
	}
	for mesh in meshes {
		rl.UnloadMesh(mesh)
	}
	for k in Tree_Model_Kind {
		for part in Tree_Part {
			rl.UnloadMesh(tree_meshes[k][part])
			rl.UnloadMesh(tree_hulls[k][part])
		}
	}
	for k in Quad_Kind {
		rl.UnloadMesh(quad_whole[k])
		for i in 0 ..< len(QUAD_MODELS[k].groups) {
			rl.UnloadMesh(quad_parts[k][i])
		}
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

lab_pointer :: proc() -> (pos: Vec2, pressed, down, toggle: bool) {
	if !keyboard_enabled {
		return
	}
	return rl.GetMousePosition(), rl.IsMouseButtonPressed(.LEFT), rl.IsMouseButtonDown(.LEFT), rl.IsKeyPressed(.F1)
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
	// and there is room for levels between the whole sizes. Between two and
	// a half and three and a half real pixels, where the levels a player
	// likes best are, the levels from PIXEL_QUARTERS_FROM on may also be a
	// quarter (3.25, 3, 2.75).
	device: f32 = 1e9
	for level in 0 ..= pixel_level {
		want := rh / PIXEL_ROWS[level]
		size := math.round(want)
		step: f32 = 1
		switch {
		case want >= 3.5:
			size = math.round(want * 2) / 2
			step = 0.5
		case want >= 2.5 && level >= PIXEL_QUARTERS_FROM:
			size = math.round(want * 4) / 4
			step = 0.25
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

// Packed four-legged animals (see quadruped.odin): for each, one mesh of the
// whole animal (for its shadow and its outline) and one for each of its
// materials, each bent anew (on the CPU, into quad_pos and its normals)
// every time it is drawn. Made once at the start.
@(private = "file")
quad_whole: [Quad_Kind]rl.Mesh
@(private = "file")
quad_parts: [Quad_Kind][QUAD_MAX_GROUPS]rl.Mesh
@(private = "file")
quad_hull: [QUAD_MAX_VERTS][3]f32

init_quad_meshes :: proc() {
	for model, k in QUAD_MODELS {
		quad_whole[k] = quad_new_mesh(len(model.mesh))
		for grp, i in model.groups {
			quad_parts[k][i] = quad_new_mesh(grp.count)
		}
	}
}

@(private = "file")
quad_new_mesh :: proc(n: int) -> (mesh: rl.Mesh) {
	mesh.vertexCount = i32(n)
	mesh.triangleCount = i32(n / 3)
	mesh.vertices = cast([^]f32)rl.MemAlloc(u32(n * 3 * size_of(f32)))
	mesh.normals = cast([^]f32)rl.MemAlloc(u32(n * 3 * size_of(f32)))
	rl.UploadMesh(&mesh, true)
	return
}

when PROSIO_BASE {
	@(private = "file")
	prosio_base_mesh: rl.Mesh
	@(private = "file")
	prosio_base_paint_location: i32
	@(private = "file")
	prosio_base_outline_bias_location: i32

	init_prosio_base_mesh :: proc() {
		mesh := &prosio_base_mesh
		mesh.vertexCount = i32(len(PROSIO_BASE_VERTICES))
		mesh.triangleCount = i32(len(PROSIO_BASE_INDICES) / 3)
		bytes := u32(len(PROSIO_BASE_VERTICES) * size_of(Vec3))
		mesh.vertices = cast([^]f32)rl.MemAlloc(bytes)
		mesh.normals = cast([^]f32)rl.MemAlloc(bytes)
		mesh.colors = cast([^]u8)rl.MemAlloc(u32(len(PROSIO_BASE_PAINT) * size_of(Color)))
		mesh.indices = cast([^]u16)rl.MemAlloc(u32(len(PROSIO_BASE_INDICES) * size_of(u16)))
		copy(mesh.indices[:len(PROSIO_BASE_INDICES)], PROSIO_BASE_INDICES)
		copy((cast([^]Color)mesh.colors)[:len(PROSIO_BASE_PAINT)], PROSIO_BASE_PAINT)
		rl.UploadMesh(mesh, true)
		prosio_base_paint_location = rl.GetShaderLocation(material.shader, "useMeshPaint")
		prosio_base_outline_bias_location = rl.GetShaderLocation(material.shader, "outlineDepthBias")
	}

	draw_prosio_base_mesh :: proc(skin: Color) {
		mesh := prosio_base_mesh
		bytes := i32(len(PROSIO_BASE_VERTICES) * size_of(Vec3))
		rl.UpdateMeshBuffer(mesh, 0, &prosio_base_positions[0], bytes, 0)
		if shadow_pass {
			material.maps[rl.MaterialMapIndex.ALBEDO].color = rl.Color(SHADOW_INK)
			rl.DrawMesh(mesh, material, rl.Matrix(FLATTEN))
			return
		}
		rl.UpdateMeshBuffer(mesh, 2, &prosio_base_normals[0], bytes, 0)
		set_surface(.Solid)
		if outlines_enabled && outline_width > 0 {
			width := outline_width * PROSIO_BASE_OUTLINE.x
			bias, zero := PROSIO_BASE_OUTLINE.y, f32(0)
			material.maps[rl.MaterialMapIndex.ALBEDO].color = rl.Color(OUTLINE_COLOR)
			flash := flash_value
			if flash > 0 { set_hit_flash(0) }
			rl.SetShaderValue(material.shader, outline_location, &width, .FLOAT)
			rl.SetShaderValue(material.shader, prosio_base_outline_bias_location, &bias, .FLOAT)
			rlgl.SetCullFace(.FRONT)
			rl.DrawMesh(mesh, material, rl.Matrix(IDENTITY))
			rlgl.SetCullFace(.BACK)
			rl.SetShaderValue(material.shader, outline_location, &zero, .FLOAT)
			rl.SetShaderValue(material.shader, prosio_base_outline_bias_location, &zero, .FLOAT)
			if flash > 0 { set_hit_flash(flash) }
		}
		on, off := i32(1), i32(0)
		rl.SetShaderValue(material.shader, prosio_base_paint_location, &on, .INT)
		tint := skin
		base_color := COLOR_SKIN
		for channel in 0..<3 {
			tint[channel] = u8(clamp(f32(skin[channel]) * 255 / f32(base_color[channel]), 0, 255))
		}
		material.maps[rl.MaterialMapIndex.ALBEDO].color = rl.Color(tint)
		rl.DrawMesh(mesh, material, rl.Matrix(IDENTITY))
		rl.SetShaderValue(material.shader, prosio_base_paint_location, &off, .INT)
	}
}

// Draws the bent animal: its shadow; or its outline (the whole of it pushed
// out along its smooth normals, drawn inside out) and then each part in its
// colour.
draw_quad_mesh :: proc(k: Quad_Kind, count: int, colors: []Color, shown: []bool) {
	whole := quad_whole[k]
	bytes :: proc(n: int) -> i32 {
		return i32(n * size_of([3]f32))
	}
	if shadow_pass {
		rl.UpdateMeshBuffer(whole, 0, &quad_pos[0], bytes(count), 0)
		material.maps[rl.MaterialMapIndex.ALBEDO].color = rl.Color(SHADOW_INK)
		rl.DrawMesh(whole, material, rl.Matrix(FLATTEN))
		return
	}
	if outlines_enabled && outline_width > 0 {
		for grp, gidx in QUAD_MODELS[k].groups {
			for i in grp.first ..< grp.first + grp.count {
				// Collapse hidden eye triangles so they leave no outline.
				quad_hull[i] = shown[gidx] ? quad_pos[i] + quad_smooth[i] * outline_width : quad_pos[grp.first]
			}
		}
		rl.UpdateMeshBuffer(whole, 0, &quad_hull[0], bytes(count), 0)
		rl.UpdateMeshBuffer(whole, 2, &quad_smooth[0], bytes(count), 0)
		material.maps[rl.MaterialMapIndex.ALBEDO].color = rl.Color(OUTLINE_COLOR)
		flash := flash_value
		if flash > 0 {
			set_hit_flash(0)
		}
		rlgl.SetCullFace(.FRONT)
		rl.DrawMesh(whole, material, rl.Matrix(IDENTITY))
		rlgl.SetCullFace(.BACK)
		if flash > 0 {
			set_hit_flash(flash)
		}
	}
	for grp, i in QUAD_MODELS[k].groups {
		if !shown[i] {
			continue
		}
		part := quad_parts[k][i]
		rl.UpdateMeshBuffer(part, 0, &quad_pos[grp.first], bytes(grp.count), 0)
		rl.UpdateMeshBuffer(part, 2, &quad_flat[grp.first], bytes(grp.count), 0)
		material.maps[rl.MaterialMapIndex.ALBEDO].color = rl.Color(colors[i])
		rl.DrawMesh(part, material, rl.Matrix(IDENTITY))
	}
}

// Trees from models (see trees.odin): the bark and the leaves of each, made
// once at the start; and one mesh for an outline, refilled for each part
// drawn.
@(private = "file")
tree_meshes: [Tree_Model_Kind][Tree_Part]rl.Mesh
@(private = "file")
tree_hulls: [Tree_Model_Kind][Tree_Part]rl.Mesh
@(private = "file")
outline_location: i32 // the shader's outlineExpansion: how far it pushes corners out along their normals

init_tree_meshes :: proc() {
	for model, k in TREE_MODELS {
		for part in Tree_Part {
			first, count := part == .Bark ? 0 : model.bark, part == .Bark ? model.bark : model.leaves
			mesh := quad_new_mesh(count)
			for i in 0 ..< count {
				v := model.mesh[first + i]
				for c in 0 ..< 3 {
					mesh.vertices[i * 3 + c] = v[c]
					mesh.normals[i * 3 + c] = v[3 + c]
				}
			}
			rl.UpdateMeshBuffer(mesh, 0, mesh.vertices, i32(count * 3 * size_of(f32)), 0)
			rl.UpdateMeshBuffer(mesh, 2, mesh.normals, i32(count * 3 * size_of(f32)), 0)
			tree_meshes[k][part] = mesh
			// Its outline: the same corners, with the smooth normals the
			// shader pushes them out along (see outlineExpansion in
			// scene.vert), so nothing is redone on the CPU each frame.
			hull := quad_new_mesh(count)
			for i in 0 ..< count {
				v := model.mesh[first + i]
				for c in 0 ..< 3 {
					hull.vertices[i * 3 + c] = v[c]
					hull.normals[i * 3 + c] = v[6 + c]
				}
			}
			rl.UpdateMeshBuffer(hull, 0, hull.vertices, i32(count * 3 * size_of(f32)), 0)
			rl.UpdateMeshBuffer(hull, 2, hull.normals, i32(count * 3 * size_of(f32)), 0)
			tree_hulls[k][part] = hull
		}
	}
}

// Draws a part of a tree: its shadow; or its outline, then itself.
draw_tree_part :: proc(model: Tree_Model_Kind, part: Tree_Part, m: Mat4, color: Color) {
	mesh := tree_meshes[model][part]
	if shadow_pass {
		material.maps[rl.MaterialMapIndex.ALBEDO].color = rl.Color(SHADOW_INK)
		rl.DrawMesh(mesh, material, rl.Matrix(FLATTEN * m))
		return
	}
	if outlines_enabled && outline_width > 0 {
		width, zero := outline_width, f32(0)
		rl.SetShaderValue(material.shader, outline_location, &width, .FLOAT)
		material.maps[rl.MaterialMapIndex.ALBEDO].color = rl.Color(OUTLINE_COLOR)
		rlgl.SetCullFace(.FRONT)
		rl.DrawMesh(tree_hulls[model][part], material, rl.Matrix(m))
		rlgl.SetCullFace(.BACK)
		rl.SetShaderValue(material.shader, outline_location, &zero, .FLOAT)
	}
	material.maps[rl.MaterialMapIndex.ALBEDO].color = rl.Color(color)
	rl.DrawMesh(mesh, material, rl.Matrix(m))
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
// Test runs switch the real keyboard (and controller) off so stray key presses cannot disturb them.
keyboard_enabled := true

// The controller as it was read this frame and the one before, how far its
// left stick is pushed, and the first key and controller button that went
// down this frame (for the Controls panel).
@(private = "file")
pad_now, pad_before: bit_set[Pad]
@(private = "file")
stick: Vec2
@(private = "file")
key_hit, key_hit_frame: Key
@(private = "file")
pad_hit: Pad

// Reads the keyboard queue and the controller, once at the start of a frame.
poll_input :: proc() {
	pad_before = pad_now
	pad_now = {}
	key_hit = KEY_NONE
	pad_hit = .None
	if !keyboard_enabled {
		stick = forced_stick
		return
	}
	for k := rl.GetKeyPressed(); k != .KEY_NULL; k = rl.GetKeyPressed() {
		if key_hit == KEY_NONE {
			key_hit = Key(k)
		}
		pad_in_use = false
	}
	stick = {}
	raw: Vec2
	if down, left, ok := system_pad_read(); ok {
		// On a Mac, through Apple's own framework (see pad_darwin.odin).
		pad_now = down
		raw = left
	} else {
		pad := i32(-1)
		for i in i32(0) ..< 4 {
			if rl.IsGamepadAvailable(i) {
				pad = i
				break
			}
		}
		if pad < 0 {
			return
		}
		BUTTONS := [Pad]rl.GamepadButton {
			.None        = .UNKNOWN,
			.A           = .RIGHT_FACE_DOWN,
			.B           = .RIGHT_FACE_RIGHT,
			.X           = .RIGHT_FACE_LEFT,
			.Y           = .RIGHT_FACE_UP,
			.LB          = .LEFT_TRIGGER_1,
			.RB          = .RIGHT_TRIGGER_1,
			.LT          = .LEFT_TRIGGER_2,
			.RT          = .RIGHT_TRIGGER_2,
			.View        = .MIDDLE_LEFT,
			.Start       = .MIDDLE_RIGHT,
			.L_Stick     = .LEFT_THUMB,
			.R_Stick     = .RIGHT_THUMB,
			.D_Up        = .LEFT_FACE_UP,
			.D_Down      = .LEFT_FACE_DOWN,
			.D_Left      = .LEFT_FACE_LEFT,
			.D_Right     = .LEFT_FACE_RIGHT,
			.Stick_Up    = .UNKNOWN,
			.Stick_Down  = .UNKNOWN,
			.Stick_Left  = .UNKNOWN,
			.Stick_Right = .UNKNOWN,
		}
		for button, p in BUTTONS {
			if button != .UNKNOWN && rl.IsGamepadButtonDown(pad, button) {
				pad_now += {p}
			}
		}
		// The triggers are read as how far they are pulled as well, since not
		// every system reports them as buttons (at rest they read 0 or -1).
		if rl.GetGamepadAxisMovement(pad, .LEFT_TRIGGER) > TRIGGER_PRESS {pad_now += {.LT}}
		if rl.GetGamepadAxisMovement(pad, .RIGHT_TRIGGER) > TRIGGER_PRESS {pad_now += {.RT}}

		raw = {rl.GetGamepadAxisMovement(pad, .LEFT_X), rl.GetGamepadAxisMovement(pad, .LEFT_Y)}
	}
	if amount := length2(raw); amount > STICK_DEAD {
		stick = raw / amount * min((amount - STICK_DEAD) / (1 - STICK_DEAD), 1)
	}
	if raw.x < -STICK_PRESS {pad_now += {.Stick_Left}}
	if raw.x > STICK_PRESS {pad_now += {.Stick_Right}}
	if raw.y < -STICK_PRESS {pad_now += {.Stick_Up}}
	if raw.y > STICK_PRESS {pad_now += {.Stick_Down}}

	went_down := pad_now - pad_before
	if went_down != {} || stick != {} {
		pad_in_use = true
	}
	for p in Pad {
		if p in went_down && (p in PAD_ASSIGNABLE || p == .Start) {
			pad_hit = p
			break
		}
	}
	// A stick click for sprinting starts a sprint (see sprint_latched).
	sprint := bindings[.Sprint].pad
	if (sprint == .L_Stick || sprint == .R_Stick) && sprint in went_down {
		sprint_latched = !sprint_latched
	}
}

// How far the left stick is pushed (0 to 1 each way), past its dead middle.
move_stick :: proc() -> Vec2 {
	return keyboard_enabled ? stick : forced_stick
}

// The first key, and the first controller button, that went down this frame.
key_hit_now :: proc() -> Key {
	return key_hit
}

pad_hit_now :: proc() -> Pad {
	return pad_hit
}

// The stick pushed one way stands for that direction button.
@(private = "file")
STICK_DIRECTION := #partial [Button]Pad {
	.Left = .Stick_Left,
	.Right = .Stick_Right,
	.Up = .Stick_Up,
	.Down = .Stick_Down,
}

button_down :: proc(b: Button) -> bool {
	if b in forced_down || b in forced_pressed { // a button that has just gone down is down
		return true
	}
	if b == .Sprint && sprint_latched {
		return true
	}
	if !keyboard_enabled {
		return false
	}
	for key in bindings[b].keys {
		if key != KEY_NONE && rl.IsKeyDown(rl.KeyboardKey(key)) {
			return true
		}
	}
	if b == .Confirm && rl.IsKeyDown(.KP_ENTER) {
		return true
	}
	pad := bindings[b].pad
	return (pad != .None && pad in pad_now) || (STICK_DIRECTION[b] != .None && STICK_DIRECTION[b] in pad_now)
}

button_pressed :: proc(b: Button) -> bool {
	if b in forced_pressed {
		return true
	}
	if !keyboard_enabled {
		return false
	}
	for key in bindings[b].keys {
		if key != KEY_NONE && rl.IsKeyPressed(rl.KeyboardKey(key)) {
			return true
		}
	}
	if b == .Confirm && rl.IsKeyPressed(.KP_ENTER) {
		return true
	}
	went_down := pad_now - pad_before
	pad := bindings[b].pad
	return (pad != .None && pad in went_down) || (STICK_DIRECTION[b] != .None && STICK_DIRECTION[b] in went_down)
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

// Texts naming buttons in braces ("{Action}: pick it") are written out for
// the keys or the controller (see expand_keys).
ui_text :: proc(text: cstring, x, y, size: f32, color: Color) {
	k := font_scale(size)
	rl.DrawTextEx(pixel_font, expand_keys(text), {snap(x), snap(y)}, f32(pixel_font.baseSize) * k, 0, rl.Color(color))
}

ui_text_width :: proc(text: cstring, size: f32) -> f32 {
	k := font_scale(size)
	return rl.MeasureTextEx(pixel_font, expand_keys(text), f32(pixel_font.baseSize) * k, 0).x
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

// Keeping the saved game, and the controls, from one sitting to the next:
// in files beside the program on the desktop, and in the browser's own
// storage on the web (the page provides the two procedures: see
// index_template.html).
Store :: enum i32 {
	Save,
	Controls,
}
STORE_FILE := [Store]cstring{.Save = "prosio.sav", .Controls = "prosio.controls"}

when IS_WEB {
	foreign import store "prosio_store"
	@(default_calling_convention = "c")
	foreign store {
		store_save :: proc(which: i32, data: [^]u8, size: i32) ---
		store_load :: proc(which: i32, data: [^]u8, room: i32) -> i32 ---
	}
}

store_write :: proc(data: []u8, which: Store = .Save) {
	when IS_WEB {
		store_save(i32(which), raw_data(data), i32(len(data)))
	} else {
		rl.SaveFileData(rl.TextFormat("%s%s", rl.GetApplicationDirectory(), STORE_FILE[which]), raw_data(data), i32(len(data)))
	}
}

// Reads what was saved into data, and says how many bytes there were (0 if
// nothing was saved, or it does not fit).
store_read :: proc(data: []u8, which: Store = .Save) -> int {
	when IS_WEB {
		return int(store_load(i32(which), raw_data(data), i32(len(data))))
	} else {
		path := rl.TextFormat("%s%s", rl.GetApplicationDirectory(), STORE_FILE[which])
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

fox_meshes: [len(FOX_GROUPS)]rl.Mesh
fox_outline_location: i32

init_fox_meshes :: proc() {
	vertices := #load("../../assets/fox/vertices.bin", [][6]f32)
	indices := #load("../../assets/fox/indices.bin", []u16)
	fox_outline_location = rl.GetShaderLocation(material.shader, "outlineExpansion")
	for group, i in FOX_GROUPS {
		mesh := &fox_meshes[i]
		mesh.vertexCount = i32(group.vertex_count)
		mesh.triangleCount = i32(group.index_count/3)
		mesh.vertices = cast([^]f32)rl.MemAlloc(u32(group.vertex_count*3*size_of(f32)))
		mesh.normals = cast([^]f32)rl.MemAlloc(u32(group.vertex_count*3*size_of(f32)))
		mesh.indices = cast([^]u16)rl.MemAlloc(u32(group.index_count*size_of(u16)))
		for v in 0..<group.vertex_count {
			row := vertices[group.first_vertex+v]
			copy(mesh.vertices[v*3:][:3], row[:3])
			copy(mesh.normals[v*3:][:3], row[3:])
		}
		copy(mesh.indices[:group.index_count], indices[group.first_index:][:group.index_count])
		rl.UploadMesh(mesh, false)
	}
}

draw_fox_meshes :: proc(frames: ^[Fox_Joint]Mat4, hide_eyes: bool) {
	draw_groups :: proc(frames: ^[Fox_Joint]Mat4, hide_eyes: bool, outline: bool) {
		for group, i in FOX_GROUPS {
			if hide_eyes && (group.joint == .eye_L || group.joint == .eye_R) {continue}
			m := frames[group.joint]
			color := group.color
			if shadow_pass {
				m = FLATTEN * m
				color = SHADOW_INK
			} else if outline {
				color = OUTLINE_COLOR
			}
			material.maps[rl.MaterialMapIndex.ALBEDO].color = rl.Color(color)
			rl.DrawMesh(fox_meshes[i], material, rl.Matrix(m))
		}
	}
	if !shadow_pass && outlines_enabled && outline_width > 0 {
		zero: f32
		flash := flash_value
		if flash > 0 {set_hit_flash(0)}
		rl.SetShaderValue(material.shader, fox_outline_location, &outline_width, .FLOAT)
		rlgl.SetCullFace(.FRONT)
		draw_groups(frames, hide_eyes, true)
		rlgl.SetCullFace(.BACK)
		rl.SetShaderValue(material.shader, fox_outline_location, &zero, .FLOAT)
		if flash > 0 {set_hit_flash(flash)}
	}
	draw_groups(frames, hide_eyes, false)
}

// The game's letters, from a font file in assets/fonts, turned into a true
// pixel font when the game starts. Each letter is drawn
// large from the font file, then sampled once for each pixel of the font's
// own grid (FONT_GRID design units a pixel, starting at FONT_ORIGIN), so
// every letter is made of whole pixels; text is then drawn a whole number of
// screen pixels to each of them (see font_scale), never smoothed, so it
// stays crisp at every size.
// The letters are Pixellari (by Zacchary Dempsey-Plante, free, with credit:
// see assets/fonts/Pixellari-LICENSE.txt), used as the file is: narrow for
// their height, so more fits on a line.
// -define:FONT=cutepixel draws them in Cute Pixel instead (the game's first
// font: rounder and wider, by zK4rim), and -define:FONT=pixelify in
// Pixelify Sans (SIL Open Font License), made bold.
FONT_NAME :: #config(FONT, "pixellari")
when FONT_NAME == "pixellari" {
	@(private = "file")
	FONT_FILE :: #load("../../assets/fonts/Pixellari.ttf")
	FONT_GRID :: f32(64) // design units to one pixel of the font
	FONT_ORIGIN :: [2]f32{0, 0} // where its grid starts, in design units
	FONT_EM :: f32(1024) // its ascent and descent together: a line is 16 of its pixels (its capitals are 11 tall)
	FONT_ASCENT :: f32(768)
	FONT_SIZE :: f32(15) // the text size (as the game asks for it) drawn one screen pixel to each pixel of the font
	FONT_BOLD :: i32(0)
	// Its Ż and ż have a slant over them, like Ź and ź's the other way:
	// drawn here with a dot, as Polish writes them.
	FONT_REDRAWN :: [?]Redrawn {
		{'Ż', {"....##....", "..........", "##########", "##########", "......###.", ".....###..", "....###...", "...###....", "..###.....", ".###......", "##########", "##########"}},
		{'ż', {"..##..", "..##..", "......", "######", "######", "...##.", "..##..", "..##..", ".##...", "######", "######"}},
	}
} else when FONT_NAME == "pixelify" {
	@(private = "file")
	FONT_FILE :: #load("../../assets/fonts/PixelifySans.ttf")
	FONT_GRID :: f32(91.43) // design units to one pixel of the font (its capitals are 7 tall)
	FONT_ORIGIN :: [2]f32{60, -12} // where its grid starts, in design units
	FONT_EM :: f32(1200) // its ascent and descent together, in design units
	FONT_ASCENT :: f32(920)
	FONT_SIZE :: f32(11) // the text size (as the game asks for it) drawn one screen pixel to each pixel of the font
	FONT_BOLD :: i32(1) // how many pixels wider each stroke is made than the font's regular weight
} else when FONT_NAME == "cutepixel" {
	@(private = "file")
	FONT_FILE :: #load("../../assets/fonts/CutePixel.ttf")
	FONT_GRID :: f32(64) // design units to one pixel of the font
	FONT_ORIGIN :: [2]f32{0, 0} // where its grid starts, in design units
	FONT_EM :: f32(1024) // its ascent and descent together: a line is 16 of its pixels
	FONT_ASCENT :: f32(768)
	FONT_SIZE :: f32(11) // the text size (as the game asks for it) drawn one screen pixel to each pixel of the font: from 14 it is drawn one and a half to each
	FONT_BOLD :: i32(0)
	// Letters drawn here instead of the font's own, which are too like
	// another: its M is an H with a notch (MEADOW read HEADOW), its a an o
	// with a pixel of tail (and read ond), its ą a q, its ł and Ł a t with
	// a lump. The same height as the font's, starting where its start.
	FONT_REDRAWN :: [?]Redrawn {
		{'M', {"##...##", "###.###", "#######", "##.#.##", "##...##", "##...##", "##...##", "##...##"}},
		{'a', {".####.", "....##", ".#####", "##..##", "##..##", ".#####"}},
		{'ą', {".####.", "....##", ".#####", "##..##", "##..##", ".#####", "....#.", "....##"}},
		{'ł', {".##..", ".##..", ".##.#", ".###.", "###..", ".##..", ".##..", ".##.."}},
		{'Ł', {".##....", ".##....", ".##.#..", ".###...", "###....", ".##....", ".######", ".######"}},
	}
}
pixel_font: rl.Font

// A letter drawn by the game instead of the font's own: its rows from the
// top, # for ink, as tall as the font's and starting where it starts.
Redrawn :: struct {
	letter: rune,
	rows:   []string,
}

// How many screen pixels to each pixel of the font, for text of this size:
// in whole pixels of the display (on a fine screen with two to each of the
// game's, that is in half steps), so it is never smoothed.
font_scale :: proc(size: f32) -> f32 {
	dpi := max(rl.GetWindowScaleDPI().x, 1)
	return max(1, math.round(size / FONT_SIZE * dpi) / dpi)
}

// How tall a line of text of this size is, from its top to the next line's.
text_height :: proc(size: f32) -> f32 {
	return f32(pixel_font.baseSize) * font_scale(size)
}

// A place on the screen, on a whole pixel of the display.
@(private = "file")
snap :: proc(v: f32) -> f32 {
	dpi := max(rl.GetWindowScaleDPI().x, 1)
	return math.round(v * dpi) / dpi
}

init_font :: proc() {
	// (The letters only, with no picture of them all together: the browser's
	// memory is small.)
	HI :: 96 // the size the letters are first drawn at, to be sampled (about 7 pixels to each of the font's)
	ASCII :: 95 // the printable ASCII letters, and after them the others the texts use (ą, ł, ó...)
	COUNT :: ASCII + len(TEXT_LETTERS)
	letters: [COUNT]rune
	for i in 0 ..< ASCII {
		letters[i] = rune(32 + i)
	}
	for r, i in TEXT_LETTERS {
		letters[ASCII + i] = r
	}
	loaded: i32
	big_glyphs := rl.LoadFontData(raw_data(FONT_FILE), i32(len(FONT_FILE)), HI, &letters[0], COUNT, .DEFAULT, &loaded)
	defer rl.UnloadFontData(big_glyphs, loaded)
	per := f32(HI) / FONT_EM // pixels of the large letters to a design unit
	count := int(loaded)
	glyphs := ([^]rl.GlyphInfo)(rl.MemAlloc(u32(count * size_of(rl.GlyphInfo))))
	tallest: i32 = 0 // the most rows a letter has, its tail below the line and all
	widen: [COUNT]i32 // how much wider a redrawn letter is than the font's
	for i in 0 ..< count {
		big := big_glyphs[i]
		w, h := f32(big.image.width), f32(big.image.height)
		// The cells of the grid this letter's picture covers.
		left := (f32(big.offsetX) / per - FONT_ORIGIN.x) / FONT_GRID
		right := ((f32(big.offsetX) + w) / per - FONT_ORIGIN.x) / FONT_GRID
		top := ((FONT_ASCENT - f32(big.offsetY) / per) - FONT_ORIGIN.y) / FONT_GRID
		bottom := ((FONT_ASCENT - (f32(big.offsetY) + h) / per) - FONT_ORIGIN.y) / FONT_GRID
		c0, c1 := i32(math.floor(left)), i32(math.ceil(right))
		r0, r1 := i32(math.floor(bottom)), i32(math.ceil(top))
		cols, rows := max(c1 - c0, 1), max(r1 - r0, 1)
		tallest = max(tallest, rows)
		image := rl.GenImageColor(cols + FONT_BOLD, rows, rl.BLANK)
		if w > 0 && h > 0 {
			for r in r0 ..< r1 {
				for c in c0 ..< c1 {
					// The middle of the cell, in the large picture.
					x := (FONT_ORIGIN.x + FONT_GRID * (f32(c) + 0.5)) * per - f32(big.offsetX)
					y := (FONT_ASCENT - (FONT_ORIGIN.y + FONT_GRID * (f32(r) + 0.5))) * per - f32(big.offsetY)
					if x < 0 || y < 0 || x >= w || y >= h {
						continue
					}
					if rl.GetImageColor(big.image, i32(x), i32(y)).r > 127 { // (a grey picture: its grey is the ink)
						for b in i32(0) ..= FONT_BOLD { // (bold: each stroke a pixel wider)
							rl.ImageDrawPixel(&image, c - c0 + b, r1 - 1 - r, rl.WHITE)
						}
					}
				}
			}
		}
		when FONT_NAME != "pixelify" {
			for fix in FONT_REDRAWN {
				if fix.letter != big.value || i32(len(fix.rows)) != rows {
					continue
				}
				wide := i32(len(fix.rows[0]))
				rl.UnloadImage(image)
				image = rl.GenImageColor(wide, rows, rl.BLANK)
				for line, r in fix.rows {
					for c in 0 ..< len(line) {
						if line[c] == '#' {
							rl.ImageDrawPixel(&image, i32(c), i32(r), rl.WHITE)
						}
					}
				}
				widen[i] = wide - cols
			}
		}
		rl.ImageFormat(&image, .UNCOMPRESSED_GRAYSCALE) // (as the atlas below reads them)
		glyphs[i] = {
			value    = big.value,
			offsetX  = c0 + i32(math.round(FONT_ORIGIN.x / FONT_GRID)),
			offsetY  = i32(math.round((FONT_ASCENT - FONT_ORIGIN.y) / FONT_GRID)) - r1,
			advanceX = i32(math.round(f32(big.advanceX) / per / FONT_GRID)) + (big.value == ' ' ? 0 : FONT_BOLD) + widen[i],
			image    = image,
		}
	}
	size := i32(math.round(FONT_EM / FONT_GRID))
	recs: [^]rl.Rectangle
	// The atlas packs the letters in rows as high as the size it is told: told
	// the font's size, the tails of p, g, y and the comma, which reach below
	// it, would run into the row beneath and be drawn over by the letters
	// there. So it is told the tallest letter.
	atlas := rl.GenImageFontAtlas(glyphs, &recs, i32(count), max(size, tallest), 1, 0)
	pixel_font = {
		baseSize    = size,
		glyphCount  = i32(count),
		glyphPadding = 0,
		texture     = rl.LoadTextureFromImage(atlas),
		recs        = recs,
		glyphs      = glyphs,
	}
	rl.UnloadImage(atlas)
	rl.SetTextureFilter(pixel_font.texture, .POINT)
}
