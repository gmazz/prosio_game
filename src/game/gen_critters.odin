package game

// Made by tools/gen_data from data/tuning/critters.json: do not edit; edit that file.

// The small creatures: fish in the pond, the rabbits and crows that raid the crops, and the bees.

// ---- fish ----
// Fish swim about the pond. They are shy of a pig on the move, but one that stands still on the bank makes them curious, and they drift over: then F grabs the nearest, if it is within reach.
MAX_FISH :: 6
// seconds until another fish takes a caught one's place: one to two hours (as it was, times MEADOW_SLOW in world.json)
FISH_BACK :: Vec2{240 * MEADOW_SLOW, 480 * MEADOW_SLOW}
// how far beyond himself he can grab one
FISH_REACH :: f32(1.25)
// seconds a grab into the water keeps the fish away
FISH_FRIGHT :: Vec2{12, 22}
// fish this near a moving Prosio dart away
FISH_SHY :: f32(4.5)
// fish this near a still one drift towards him
FISH_CURIOUS :: f32(7)

// ---- pests ----
// Rabbits after the cabbages, crows after the wheat.

// rabbits and crows on the meadow, a count, each with its own home
MAX_PESTS :: 4
// seconds between raids (as it was, times MEADOW_SLOW: the crops grow that much slower too)
PEST_AWAY :: Vec2{50 * MEADOW_SLOW, 150 * MEADOW_SLOW}
// how fast each comes for the crops, m/s
PEST_SPEED := [Pest_Kind]f32{.Rabbit = 3.2, .Crow = 5}
// and how fast it runs off, m/s
PEST_FLEE := [Pest_Kind]f32{.Rabbit = 7.5, .Crow = 8}
// how near Prosio can get
PEST_SCARE := [Pest_Kind]f32{.Rabbit = 4.5, .Crow = 6}
// which crop each goes for
PEST_CROP := [Pest_Kind]Food_Kind{.Rabbit = .Cabbage, .Crow = .Wheat}
// they leave anything smaller alone
RIPE_ENOUGH :: f32(0.6)
// how much of a crop's growth one raid eats
NIBBLE :: f32(0.7)
// and how long that takes
NIBBLE_TIME :: f32(14)
// how high a crow flies, in metres
CROW_HEIGHT :: f32(4)
// A stone passing or landing this near sends a rabbit or a crow off, and it stays away STONED_AWAY times as long as it would have.
STONE_SCARE :: f32(2.5)
// how many times as long it stays away after a stone frightens it off
STONED_AWAY :: f32(2.5)
// from this far off he hears one start on his crops
PEST_HEARD :: f32(50)

// ---- bees ----
// Bees. Each hive in the bee meadow has a swarm that minds its own business until Prosio comes close: then it is after him, stinging, until he has been out of its reach for a while. His wind sends bees back into the hive and keeps them quiet for a time, and with enough fat on him the stings hardly hurt.
MAX_HIVES :: 3
// combs in one hive
MAX_HONEY :: 2
// seconds until the bees have made another: a comb every hour or two
HONEY_REGROW :: Vec2{240 * MEADOW_SLOW, 480 * MEADOW_SLOW}
// how big a hive is on the ground, in metres
HIVE_RADIUS :: f32(0.42)
// nearer the hive than this, and they come out
HIVE_GUARD :: f32(3.6)
// faster than he walks, slower than a lean sprint
BEE_SPEED :: f32(6.2)
// seconds they stay after him once he is clear
BEE_ANGRY :: f32(5)
// they give up this far from the hive
BEE_LEASH :: f32(32)
// seconds between stings while the swarm is on him; lower it and they sting more often
STING_EVERY :: f32(0.7)
// seconds his wind keeps a hive quiet
GAS_CALM :: f32(14)

