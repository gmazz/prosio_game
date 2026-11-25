package game

// Made by tools/gen_data from data/tuning/world.json: do not edit; edit that file.

import "core:math"

_ :: math

// The meadow: its size and layout, the fog round it, what grows and how fast, the forest and its trees, and how much room the game keeps for things.

// ---- meadow ----
// Where everything is, in metres; home is at 0, 0.

// how fast falling things speed up, m/s each second; raise it and jumps and throws come down sooner
GRAVITY :: f32(25)
// The meadow reaches this far from the centre, inside a fence. Prosio's home with its oven is in the middle; each kind of food grows in its own part of the meadow (see REGIONS), so he has to go out and fetch it.
WORLD_HALF :: Vec2{100, 70}
// where his home is, in metres: the middle of the meadow
HOME :: Vec2{0, 0}
// The pond: the only water to drink. It is round, and too deep to walk into.
POND :: Vec2{-26, -48}
// how far the pond reaches from its middle, in metres
POND_RADIUS :: f32(7.5)
// Paths from home out to each region, as straight segments; they wander a little when drawn.
PATH_ENDS := [Region_Kind]Vec2{.Home = HOME, .Forest = {-30, -8}, .Fields = {36, 18}, .Garden = {-10, 34}, .Turkeys = {10, -29}, .Hills = {50, -30}, .Pond = {-21, -39}, .Bees = {-38, 46}}
// What Prosio has seen of the meadow, for the map: it is in squares of MAP_CELL, and everything within SIGHT of him is uncovered as he goes.
MAP_CELL :: f32(2.5)
// 2 * WORLD_HALF.x / MAP_CELL
MAP_W :: 80
// 2 * WORLD_HALF.y / MAP_CELL
MAP_H :: 56
// further with plenty of vitamins, less without (see EAGLE_SIGHT and DIM_SIGHT in diet.json)
SIGHT :: f32(15)

// ---- fog ----
// Beyond the edge of the meadow lies a thick dark fog: it starts FOG_START metres past the edge and is solid FOG_THICK metres further. Nobody walks into it, but an animal thrown far enough flies into it and is lost: it comes back later at home, like any other that is gone.
FOG_START :: f32(-2.5)
// metres from where the fog starts to where it is solid
FOG_THICK :: f32(6)
// how far past the edge a flying animal is lost (or as soon as it comes down beyond it)
FOG_LOST :: f32(3)

// ---- day ----
// The game's day: 60 minutes of play. What he burns, what the meadow grows, how fast his body changes and how fast his stomach empties are all set for days of this length.

// seconds of play in a day: 60 minutes. A game hour is DAY_SECONDS / 24, two and a half minutes
DAY_SECONDS :: f32(3600)
// everything that grows or comes back (crops, fruit, mushrooms, nuts, wood, salt, eggs, milk, honey, fish, rabbits and crows, a fox or an animal lost in the fog) takes this many times as long as it did when a session was a few minutes long; raise it and the meadow gives less a day
MEADOW_SLOW :: f32(15)

// ---- growing ----
// What grows, how much of it there is, and how fast it comes back.

// Food is scarce. Of each kind there is never more in the whole meadow than FOOD_BUDGET calories' worth, counted at full size: about a day's food of each (so five pumpkins, six sheaves of wheat, twenty-odd apples, forty bunches of berries); raise it and more stands at once. That is a ceiling, not a promise. What is picked does not come straight back: after a wait a new one sprouts, small, and grows to its full size, which differs a little from one to the next. Picked early it is worth less.
FOOD_BUDGET :: f32(2000)
// mushrooms are so light there would be far too many; raise it and more stand at once
MUSHROOM_BUDGET :: f32(600)
// the share of its calories a thing has when it has only just sprouted
UNRIPE :: f32(0.25)
// how much one thing's full size can differ from the usual, either way
SIZE_SPREAD :: f32(0.15)
// bunches on one bush
MAX_BERRIES :: 2
// seconds until a picked bush starts another bunch (as it was, times MEADOW_SLOW in the day section)
BERRY_REGROW :: Vec2{60 * MEADOW_SLOW, 160 * MEADOW_SLOW}
// seconds for berries to ripen: 30 minutes
BERRY_GROW :: f32(120 * MEADOW_SLOW)
// apples on one tree, with those lying under it
MAX_APPLES :: 3
// seconds between a tree's new apples
APPLE_REGROW :: Vec2{120 * MEADOW_SLOW, 300 * MEADOW_SLOW}
// seconds for apples to ripen on the tree: 50 minutes
APPLE_GROW :: f32(200 * MEADOW_SLOW)
// seconds a fallen apple lies there before it rots away
APPLE_LIFE :: f32(90)
// seconds a laid egg lies there before it is gone
EGG_LIFE :: f32(240)
// eggs lying about at once, all over the meadow: well under the budget
MAX_EGGS :: 10
// Seconds until a new one sprouts where one was picked (somewhere in this range), and then to grow to full size: each as it was, times MEADOW_SLOW. Apples are not replanted: new ones grow on the trees; the turkeys lay new eggs; only he puts spears there. Wood is not food, and falls as often as it did
FOOD_REGROW := [Food_Kind]Vec2{.Apple = {}, .Mushroom = {90 * MEADOW_SLOW, 240 * MEADOW_SLOW}, .Pumpkin = {240 * MEADOW_SLOW, 540 * MEADOW_SLOW}, .Wheat = {240 * MEADOW_SLOW, 540 * MEADOW_SLOW}, .Egg = {}, .Cabbage = {200 * MEADOW_SLOW, 480 * MEADOW_SLOW}, .Nuts = {150 * MEADOW_SLOW, 400 * MEADOW_SLOW}, .Wood = {120, 300}, .Spear = {}}
// seconds to grow from a sprout to full size (a pumpkin 75 minutes); a branch falls whole
FOOD_GROW := [Food_Kind]f32{.Apple = 0, .Mushroom = 100 * MEADOW_SLOW, .Pumpkin = 300 * MEADOW_SLOW, .Wheat = 260 * MEADOW_SLOW, .Egg = 0, .Cabbage = 240 * MEADOW_SLOW, .Nuts = 180 * MEADOW_SLOW, .Wood = 0, .Spear = 0}
// How big each is on the ground. Only a pumpkin is big enough to bump into.
FOOD_SIZE := [Food_Kind]f32{.Apple = 0.12, .Mushroom = 0.14, .Pumpkin = 0.34, .Wheat = 0.22, .Egg = 0.1, .Cabbage = 0.26, .Nuts = 0.16, .Wood = 0.3, .Spear = 0.3}

// ---- salt_and_pebbles ----
// big rocks in the goat hills with rock salt growing on them (salt is no energy, so it has no budget)
SALT_ROCKS :: 4
// lumps on one of them
MAX_SALT :: 2
// seconds until another lump has grown
SALT_REGROW :: Vec2{300 * MEADOW_SLOW, 600 * MEADOW_SLOW}
// how big a salt rock is on the ground, in metres
SALT_ROCK_RADIUS :: f32(1.0)
// Patches of pebbles for throwing: some in the goat hills, by the pond, and one each near home, the turkeys and the fields.
PEBBLE_PATCHES := [Region_Kind]int{.Home = 1, .Forest = 1, .Fields = 1, .Garden = 0, .Turkeys = 1, .Hills = 3, .Pond = 2, .Bees = 0}
// in one patch
MAX_PEBBLES :: 6
// taken at one stoop
PEBBLE_HANDFUL :: 3
// seconds until another has worked its way up
PEBBLE_REGROW :: Vec2{30, 70}
// how big a patch of pebbles is, in metres
PEBBLE_PATCH_RADIUS :: f32(0.45)

// ---- forest ----
// Shaking a tree: standing right at it (no further than TREE_SHAKE_REACH from its trunk) and facing it (within TREE_SHAKE_ANGLE either side) he takes hold of it with both hooves and shakes it, as hard as his arms are strong (STRONG and NOODLE_ARMS in prosio.json, skills). The crown shakes that much, and that many apples come down.

// Where trees may stand. The camera always looks from the south, and from above (rising VIEW_SLOPE metres back for every metre up): so a tree's leaves hide a strip of ground to the north of its trunk, from under their lowest to beyond their highest, as wide as its crown (see tree_cover). A tall tree hides ground ten metres behind it. Two rules come of that: nothing is planted where it would stand in front of something that has to stay in view: a path, a field, a building, a hive, a salt rock, a berry bush, food on the ground (see hides_something); and what is put down after the trees (bushes, mushrooms, nuts, salt) goes only where no tree stands in front of it (see hidden_by_tree).
VIEW_SLOPE :: f32(1.25)
// trees in the forest (besides the apple trees),
FOREST_TREES :: 300
// each at least this far from the next,
FOREST_SPACING :: f32(3.4)
// thinning to this share of the trees at its edge
FOREST_EDGE :: f32(0.25)
// mossy stumps and fallen logs in the forest
FOREST_STUMPS :: 36
// how big a stump or a fallen log is on the ground, in metres
STUMP_RADIUS :: f32(0.5)
// The forest's clearings, and the trail that joins them to the path from home (PATH_ENDS[.Forest]).
CLEARINGS := [3]Vec2{{-50, -14}, {-71, 8}, {-73, -36}}
// how far each clearing reaches from its middle, in metres
CLEARING_RADIUS :: f32(8)
// the forest's trails, each a straight run from one point to another, in metres
TRAILS := [3][2]Vec2{{{-30, -8}, {-50, -14}}, {{-50, -14}, {-71, 8}}, {{-50, -14}, {-73, -36}}}
// metres between him and the trunk
TREE_SHAKE_REACH :: f32(0.6)
// 30 degrees either side of where he faces
TREE_SHAKE_ANGLE :: f32(math.PI / 6)
// seconds he shakes it
TREE_SHAKE_TIME :: f32(0.9)
// apples that come down for arms of ordinary strength
TREE_SHAKE_APPLES :: f32(2)

// ---- trees ----
// Trees drawn from models: each kind's height and crown width (metres, before a tree's own size), which models it takes, how much one tree differs from the next, and its leaves.

// Each kind's height (metres, before a tree's own size), how wide its crown is (its radius), and its two models.
TREE_HEIGHT := [Tree_Species]f32{.Broadleaf = 5.4, .Apple = 4.6, .Blossom = 5.2, .Pine = 5.8}
// how wide each kind's crown is: its radius, in metres
TREE_CROWN := [Tree_Species]f32{.Broadleaf = 2.0, .Apple = 1.7, .Blossom = 1.9, .Pine = 1.35}
// the models each kind is drawn from; a tree takes one of them by its number
TREE_PICK := [Tree_Species][]Tree_Model_Kind{.Broadleaf = {.Broad1, .Broad2, .Broad3, .Broad4, .Common1, .Common2, .Birch1, .Birch2}, .Apple = {.Round1, .Round2}, .Blossom = {.Round3, .Broad1}, .Pine = {.Pine1, .Pine2, .Pine3, .Pine4, .Pine5}}
// how much wider or narrower a tree may be than its kind,
TREE_WIDTH :: f32(0.12)
// how far it may lean (radians),
TREE_LEAN :: f32(0.06)
// and how much lighter or darker its leaves may be
TREE_SHADE :: f32(0.1)
// Leaves for each kind (a tree's own shade is laid over them).
TREE_LEAVES := [Tree_Species]Color{.Broadleaf = {92, 150, 72, 255}, .Apple = {120, 170, 78, 255}, .Blossom = {236, 158, 178, 255}, .Pine = {58, 112, 80, 255}}

// ---- limits ----
// How many of each thing the game keeps room for (it allocates nothing while playing). Raise one only if the meadow needs more.

// round things standing in the world at once, a count: trees, rocks, bushes, hives, stations and what he builds
MAX_ROUNDS :: 640
// food growing or lying about at once
MAX_FOODS :: 360
// bits of dust, sparks and splashes in the air at once; when it is full the oldest goes
MAX_PARTICLES :: 256
// grass tufts, flowers and ferns, there only to look at
MAX_DECOR :: 5000
// fields of crops
MAX_FIELDS :: 8

// ---- plants ----
// How big the grass clumps, ferns, low bushes and fallen logs are drawn.

// how big a clump of grass is drawn, against its model (0.4 m tall)
GRASS_SIZE :: f32(1.25)
// a low bush under the forest trees (1.2 m tall as modelled)
SHRUB_SIZE :: f32(0.6)
// a fallen log, from end to end
LOG_LENGTH :: f32(1.9)
// and a fern
FERN_SIZE :: f32(0.95)

