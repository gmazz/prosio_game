package game

// Made by tools/gen_data from data/tuning/handling.json: do not edit; edit that file.

// What his hooves do: grabbing, lifting, holding, dragging, throwing, swinging and bashing, and what a stone or a slam does.

// ---- throwing ----
// Rocks and stones: his arms put the same energy into every throw, THROW_ENERGY joules for each kilogram of him (times the strength of his arms), so the speed is the square root of twice that over the stone's weight. A heavy rock is a short, slow lob; a light stone would fly faster than an arm can move, and leaves at ARM_SPEED (times the root of his strength) at the most.
THROW_ENERGY :: f32(8)
// the fastest a stone or a spear leaves his hoof, m/s, for arms of ordinary strength
ARM_SPEED :: f32(22)
// what a pebble weighs, in kg
PEBBLE_KG :: f32(0.3)
// how big a pebble is, in metres
PEBBLE_RADIUS :: f32(0.07)
// stamina to throw one
PEBBLE_COST :: f32(3)
// What a thrown stone does to an animal it hits is the blow of an animal of that kind landing with the stone's energy, counted STONE_HARD times over (a stone does not give). A stone under LIGHT_STONE kg knocks nothing over: it stings, startles (the animal runs for PEBBLE_FRIGHT seconds) and makes a fox drop what it stole.
STONE_HARD :: f32(2)
// in kg: a stone lighter than this only stings and startles
LIGHT_STONE :: f32(2)
// seconds, at random in this range, an animal a pebble startles runs off for
PEBBLE_FRIGHT :: Vec2{3, 6}
// how far off he can pick something out to throw at
AIM_RANGE :: f32(16)
// for animals, which he can wind up
ANIMAL_THROW_GAIN :: f32(3.2)
// the fastest anything he throws or swings can go, m/s
MAX_THROW :: f32(22)
// stones and spears in the air at once, a count
MAX_THROWN :: 4
// What F does with something in his hands. A tap (let go within WIND_TAP seconds) puts it down. Held longer, he winds up: the throw has WIND_LEAST of its full speed at first and all of it after WIND_FULL seconds.
WIND_TAP :: f32(0.2)
// seconds of winding up for a throw at full speed
WIND_FULL :: f32(1.0)
// the share of full speed a throw has with no winding up at all
WIND_LEAST :: f32(0.35)

// ---- holding ----
// Grabbing, lifting and holding.

// how far beyond touching he can reach: about an arm
GRAB_REACH :: f32(0.85)
// seconds to lift something of his own weight
LIFT_TIME :: f32(0.35)
// stamina per second for holding his own weight
CARRY_DRAIN :: f32(5)
// he can swing or throw up to this share of his own weight
LIFT_LIMIT :: f32(0.9)
// he can lift a rock of up to twice his own weight
ROCK_LIMIT :: f32(2)
// A rock of radius 0.3 weighs about 10 kg, 0.6 about 82 kg, and the big boulders (0.9) about 280 kg: liftable only by a heavy, rested Prosio.
ROCK_DENSITY :: f32(380)
// an animal on its feet digs in: it resists like this many times its weight
DIG :: f32(1.5)
// a limp animal slides along the grass: it resists like this share of its weight
DRAG_SLIDE :: f32(0.6)
// and Prosio digs his heels in too
PROSIO_GRIP :: f32(1.5)
// how much faster a dragged animal pulls when it lunges
LUNGE_SPEED :: f32(3)
// from his shoulder to his hoof, arm outstretched
ARM_LEN :: f32(0.55) * PROSIO_SIZE

// ---- skipping ----
// A body slammed down spinning skips on along the ground.

// share of forward speed kept at each skip
SKIP_KEEP :: f32(0.82)
// share of falling speed that bounces back up
SKIP_BOUNCE :: f32(0.55)
// share of falling speed the spin turns into forward speed
SKIP_SPIN :: f32(0.18)

// ---- bashing ----
// seconds his arm stays down after a swing lands
FOLLOW_THROUGH :: f32(0.12)
// What a slam takes from a held animal's health: so much, plus so much for each m/s it hit at, and never more than SLAM_MOST. (His arm sets the speed, whatever he holds, so this does not go by how sturdy the animal is.)
SLAM_BLOW :: Vec2{4, 1.2}
// the most health one slam can take
SLAM_MOST :: f32(30)
// seconds an animal bashed about hangs limp, at most
LIMP_MOST :: f32(8)
// Whatever the swung animal hits takes a share of its speed set by their weights, as when two balls collide. But the club is floppy: only part of its body (CLUB_SHARE of its weight) is behind the blow, and it squashes rather than bounces (restitution BASH_BOUNCE). For a club of weight m moving at v, striking something of weight M: it flies off at   (1 + e) * m' / (m' + M) * v,   with m' = CLUB_SHARE * m the club goes on  (m' - e * M) / (m' + M) * v So a turkey swung into a turkey knocks it about half as fast as it was swung, and swung into the billy goat it barely rocks it and bounces back.
CLUB_SHARE :: f32(0.6)
// how bouncy the swung animal is when it strikes (e in the sums above, 0 to 1): raise it and what it hits flies off faster and it bounces back more
BASH_BOUNCE :: f32(0.35)

// ---- rocks ----
// How rocks are drawn: which models, and how tall one may be against its radius.

// A rock of radius r with its middle at m, drawn from one of the rock models (packed from assets/trees/<name>.glb by tools/pack_assets): which one goes by the rock's number in the world (index), so it keeps its shape when he lifts and throws it, and a mossy rock keeps its moss. No taller than ROCK_TALL times its radius.
ROCK_PLAIN := [?]Tree_Model_Kind{.Rock2, .Rock3, .Rock4, .Rock5}
// the models a mossy rock is drawn from
ROCK_MOSSY := [?]Tree_Model_Kind{.Rockmoss1, .Rockmoss2, .Rockmoss3, .Rockmoss4}
// a rock is drawn no taller than this many times its radius
ROCK_TALL :: f32(1.5)

