package game

// Made by tools/gen_data from data/tuning/building.json: do not edit; edit that file.

// Wood and what he builds of it: the workbench, fences and pens, the scarecrow, the rod, the spear, the larder and the campfire.

// ---- wood_and_bench ----
// branches under the forest trees
WOOD_LYING :: 36
// where the workbench stands, from home: across the yard from the oven, between the paths to the fields and the garden
BENCH_PLACE :: Vec2{1.5, 7}
BENCH_RADIUS :: f32(0.8)

// ---- fences ----
// Fences stand on the lines of a grid of squares FENCE_LEN across, which covers the meadow (FENCE_W by FENCE_H of them: the meadow's size over FENCE_LEN; changing these makes old saves unreadable). He can lift an animal over a fence if it weighs no more than this.

// Fences stand on the lines of a grid of squares FENCE_LEN across, which covers the meadow. A piece runs from a point of the grid to the next one east or south of it.
FENCE_LEN :: f32(2)
// squares across: the meadow's width over FENCE_LEN
FENCE_W :: 100
FENCE_H :: 70
FENCE_POINTS :: (FENCE_W + 1) * (FENCE_H + 1)
// pieces standing at once (as many as are saved)
MAX_FENCES :: 240
// anything with its feet higher than this is over it; a jump this high takes him over (at 80 kg he jumps 0.45 m)
FENCE_TOP :: f32(0.4)
FENCE_THICK :: f32(0.1)
// a piece goes on the line of the grid nearest to the spot this far in front of him (never under his feet),
FENCE_AHEAD :: f32(0.7)
// so it is never further from that spot than this; and F takes down a piece that near it
FENCE_REACH :: f32(1.05)
// how near he must be to a scarecrow to take it down, or to a penned goat to milk it
BUILT_REACH :: f32(0.6)
// squares: an enclosure bigger than this is no pen, it is a field
PEN_MOST :: 40
// seconds between an animal's looks at whether it is penned
PEN_CHECK :: f32(1)
// of his own weight, times the strength of his arms: 28 kg for an ordinary pig, never a goat
HOIST_SHARE :: f32(0.35)
// an animal heavier than this does not go over a fence even thrown: a goat comes in by the gate
FENCE_HEAVY :: f32(30)

// ---- scarecrow_rod_spear ----
// Scarecrows are round things of the world, like trees. One that has been taken down leaves its place free for the next.
MAX_SCARECROWS :: 8
SCARECROW_RADIUS :: f32(0.22)
// crows leave wheat this near one alone
SCARECROW_REACH :: f32(9)
// The rod: how far out it reaches for a fish, from where he stands.
ROD_REACH :: f32(4)
// The spear. It leaves his hoof as a stone of its weight would, and what it takes from an animal's health when thrown as fast as an arm can (ARM_SPEED) is SPEAR_BLOW; slower, less, by the square of the speed. The animal is not bowled over, it staggers for SPEAR_STAGGER seconds.
SPEAR_KG :: f32(1.5)
SPEAR_RADIUS :: f32(0.12)
// stamina to throw one
SPEAR_COST :: f32(6)
SPEAR_LEN :: f32(1.5)
SPEAR_STAGGER :: f32(0.8)
SPEAR_BLOW := [Enemy_Kind]f32{.Turkey = 55, .Goat = 40, .Billy = 28, .Fox = 60}

// ---- larder ----
// food keeps this many times as long in a larder
LARDER_KEEPS :: f32(5)
LARDER_LITRES :: f32(100)
LARDER_RADIUS :: f32(0.6)
MAX_LARDERS :: 4

// ---- campfire ----
// His campfire: one, wherever he sets it up (not in the pond, nor out in the fog), with a ring of stones and a spit, and a stump beside it to chop meat on. While it stands it is a cooking fire like the one by the pond (the station Camp: the same dishes, his same skill at the grill). F packs it up again, once nothing is cooking on it.

// how much clear ground round it it needs
CAMP_ROOM :: f32(1.3)

