package game

import "core:math"
import "core:math/linalg"

// Trees made from low-poly tree models (see tools/pack_trees.py): two
// broadleaves, a round one and a lumpy one, and two pines, a layered pine and
// a small fir. Each tree in the meadow takes one of its kind's two models, by
// its number, and is made its own: scaled to its kind's height times its own
// size, narrowed or widened a little, leaning a little, and a shade lighter
// or darker. Its crown, as the meadow's rules see it (what it hides, where
// it fades round him), is measured from the model as drawn.
//
// An apple tree is a broadleaf with paler leaves, its apples hanging at
// spots on the upper slope of its crown; a blossom tree is a broadleaf in
// pink. The models' leaves sway in the wind like the drawn trees did.
PACKED_TREES :: #config(PACKED_TREES, true) // false draws the trees from shapes, as before

Tree_Model :: struct {
	name:                         string,
	bark, leaves:                 int, // corners of each: the bark first in mesh
	height:                       f32,
	crown_low, crown_high, crown_r: f32,
	spots:                        []Vec3, // where apples hang
	mesh:                         [][9]f32, // position, flat normal, smooth normal
}

Tree_Part :: enum {
	Bark,
	Leaves,
}

// Each kind's height (metres, before a tree's own size), how wide its crown
// is (its radius), and its two models.
TREE_HEIGHT := [Tree_Species]f32{.Broadleaf = 6.7, .Apple = 4.6, .Blossom = 6.2, .Pine = 6.4}
TREE_CROWN := [Tree_Species]f32{.Broadleaf = 2.0, .Apple = 1.7, .Blossom = 1.9, .Pine = 1.35}
TREE_PICK := [Tree_Species][2]Tree_Model_Kind {
	.Broadleaf = {.Round, .Lumpy},
	.Apple     = {.Round, .Lumpy},
	.Blossom   = {.Round, .Lumpy},
	.Pine      = {.Pine, .Fir},
}
TREE_WIDTH :: f32(0.12) // how much wider or narrower a tree may be than its kind,
TREE_LEAN :: f32(0.06) // how far it may lean (radians),
TREE_SHADE :: f32(0.1) // and how much lighter or darker its leaves may be

// Leaves for each kind (a tree's own shade is laid over them).
TREE_LEAVES := [Tree_Species]Color {
	.Broadleaf = {92, 150, 72, 255},
	.Apple     = {120, 170, 78, 255},
	.Blossom   = {236, 158, 178, 255},
	.Pine      = {58, 112, 80, 255},
}

// A number from 0 to 1 that belongs to one tree and one purpose.
tree_random :: proc(index: int, purpose: f32) -> f32 {
	return math.mod(f32(index) * 0.6180339 + purpose * 0.3713 + f32(index % 7) * 0.113, 1)
}

// The shape of tree number index, of this kind, drawn from its model.
packed_tree_shape :: proc(species: Tree_Species, index: int, size: f32) -> Tree_Shape {
	model := TREE_PICK[species][tree_random(index, 1) < 0.5 ? 0 : 1]
	md := TREE_MODELS[model]
	tall := TREE_HEIGHT[species] * size / md.height
	wide := TREE_CROWN[species] * size / md.crown_r * (1 + TREE_WIDTH * (2 * tree_random(index, 2) - 1))
	low, high := md.crown_low * tall, md.crown_high * tall
	return {
		species = species,
		size = size,
		canopy = md.crown_r * wide,
		canopy_y = (low + high) / 2,
		model = model,
		low = low,
		high = high,
		scale = {wide, tall, wide},
	}
}

// Draws a tree from its model; the caller has set its fade.
draw_packed_tree :: proc(pos: Vec2, index: int, t: Tree_Shape) {
	lean := Vec2{2 * tree_random(index, 3) - 1, 2 * tree_random(index, 4) - 1} * TREE_LEAN
	m := translate({pos.x, 0, pos.y}) * rot_y(f32(index) * 2.39) * rot_x(lean.x) * rot_z(lean.y)
	// A shaken tree's crown trembles for a moment.
	shake := g.rounds[index].shake_t * g.rounds[index].shake_power
	crown := m * translate({math.sin(g.time * 47) * shake * 0.25, 0, math.cos(g.time * 39) * shake * 0.2})
	shaped := scale(t.scale)

	set_surface(.Bark)
	bark := t.species == .Blossom ? Color{104, 78, 72, 255} : COLOR_TRUNK
	draw_tree_part(t.model, .Bark, m * shaped, bark)

	set_surface(.Leaf)
	set_sway(0.07 * t.size)
	draw_tree_part(t.model, .Leaves, crown * shaped, shade(TREE_LEAVES[t.species], 1 + TREE_SHADE * (2 * tree_random(index, 5) - 1)))
	set_sway(0)

	if t.species == .Apple {
		// Its apples, at spots on the upper slope of its crown.
		set_surface(.Solid)
		spots := TREE_MODELS[t.model].spots
		r := g.rounds[index]
		for k in 0 ..< min(r.fruit, len(spots)) {
			at := (crown * shaped * [4]f32{spots[k].x, spots[k].y, spots[k].z, 1}).xyz
			big := lerp(0.09, 0.17, r.ripe)
			ball(IDENTITY, at, {big, big * 0.95, big}, blend(UNRIPE_GREEN, APPLE_RED, r.ripe * 1.2 - 0.2))
		}
	}
	set_surface(.Solid)
}

// The outline of a tree part: its corners carried into the world, each
// pushed out along its smooth normal by width.
tree_hull :: proc(model: Tree_Model_Kind, part: Tree_Part, m: Mat4, width: f32, out: [][3]f32) -> int {
	md := &TREE_MODELS[model]
	first, count := part == .Bark ? 0 : md.bark, part == .Bark ? md.bark : md.leaves
	turn := linalg.matrix3_from_matrix4(m)
	for i in 0 ..< count {
		v := md.mesh[first + i]
		p := (m * [4]f32{v[0], v[1], v[2], 1}).xyz
		n := linalg.normalize0(turn * Vec3{v[6], v[7], v[8]})
		out[i] = p + n * width
	}
	return count
}
