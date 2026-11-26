package game

// Made by tools/gen_data from data/tuning/prosio.json: do not edit; edit that file.

// Prosio himself: his fat, his size, what he burns, his bruises, and how his muscles and skills grow and fade.

// ---- fat ----
// Prosio's fat, in kilograms. (His weight is this and the rest of him, added up from his parts.) Running out of it and of his carbs as well, or carrying too much fat, is a fail.

// heart gives up
FAT_MAX :: f32(100)
// kg of fat he starts with
FAT_START :: f32(45)
// below this he is lean
FAT_LEAN :: f32(30)
// above this he is huge
FAT_HUGE :: f32(70)
// warning zone width at each end
FAT_DANGER :: f32(7)
// what he weighs at the start; walking and running burn in proportion to this
KG_START :: f32(80)
// the weight at which he is at his narrowest
KG_SLIM :: f32(35)

// ---- moving ----
// His size, his stamina, and how long a bump, a stoop and a jump take.

// How big Prosio is drawn, against the animals and the meadow: his body is modelled in its own measurements, and everything that comes from them (his size on the ground, where his hands and shoulders are, how long his arms are, how high he lifts and throws) is scaled by this.
PROSIO_SIZE :: f32(0.75)
// the most stamina he can have, in points
STAMINA_MAX :: f32(100)
// seconds a bump carries him forward
DASH_TIME :: f32(0.28)
// stooping to pick something up and putting it in the sack
PICK_TIME :: f32(0.5)
// Ordinary legs put the same energy into every jump, so height = energy / weight: a 40 kg Prosio jumps 0.9 high, a 120 kg Prosio only 0.3. Strong legs put in more (see LEG_SPRING in the skills section).
when WORKBENCH {
	JUMP_ENERGY: f32 = 36
} else {
	JUMP_ENERGY :: f32(36)
}

// ---- lean_to_fat ----
// Everything here gets worse with fat, and the gap is deliberately wide: each pair is his value when lean (no fat) and with all the fat he can carry (FAT_MAX); in between it goes smoothly from one to the other. Strong legs and good lungs make up for some of it (see the skills section).

// how fast he walks, m/s (curving: most of the slowing comes early)
WALK_SPEED :: Vec2{7.2, 2.6}
// how many times faster he sprints than he walks
SPRINT_BOOST :: Vec2{1.7, 1.25}
// stamina a second of sprinting costs
SPRINT_DRAIN :: Vec2{9, 42}
// how fast a bump carries him, m/s
DASH_SPEED :: Vec2{15, 10.5}
// stamina a bump costs
DASH_COST :: Vec2{9, 42}
// stamina a jump costs
JUMP_COST :: Vec2{4, 22}
// stamina that comes back each second (curving like the walk)
STAMINA_REGEN :: Vec2{50, 8}

// ---- burning ----
// Everything he does burns some of his weight, a little for everyday things and more for fighting. Walking and running burn in proportion to his weight: these are for an 80 kg Prosio. Set for a day of 60 minutes (DAY_SECONDS in world.json) in which he eats about 2,000 kcal: an active day (30 minutes walking, 2 sprinting, 150 things picked, 30 jumps, 30 bumps, grabs, bashes or throws) burns about 800 kcal doing things, on top of the 1,200 his muscles burn (BASAL); a day of rest, about 1,200 in all. Each is in kg of his weight (KCAL_PER_KG to the kilogram, in food.json): 0.072 of what it was when a session was a few minutes long, all in the same proportions.

// kg per second of walking: 17 kcal a minute (520 kcal in 30 minutes)
WALK_BURN :: f32(17.0 / KCAL_PER_KG / 60)
// kg per second of sprinting: 52 kcal a minute
SPRINT_BURN :: f32(52.0 / KCAL_PER_KG / 60)
// the share of the sack's weight his legs feel (it is on his back, well packed)
LOAD_EASE :: f32(0.6)
// so with 16 kg in the sack his legs train 1.36 times as fast
LOAD_TRAIN :: f32(3)
// a sack this share of his weight, and he says so
LOAD_HEAVY :: f32(0.3)
// kg per thing picked up: 0.43 kcal
GATHER_BURN :: f32(0.43 / KCAL_PER_KG)
// kg per jump: 0.87 kcal
JUMP_BURN :: f32(0.87 / KCAL_PER_KG)
// kg per bump, grab, bash or throw: 2.9 kcal
FIGHT_BURN :: f32(2.9 / KCAL_PER_KG)

// ---- bruises ----
// A knock from an animal, or a sting, leaves a bruise: no weight is lost, but the top of his stamina comes down by that much until it mends, so a battered Prosio cannot sprint or fight for long and has to get away. The bruises never take more than BRUISE_MOST, which leaves him BRUISE_FLOOR of his stamina to run with; bruised that far, the next thing is that he is knocked out, and wakes up at home.
BRUISE_FLOOR :: f32(0.25)
// the most his bruises can take off the top of his stamina, in points (worked out from BRUISE_FLOOR)
BRUISE_MOST :: STAMINA_MAX * (1 - BRUISE_FLOOR)
// stamina points a knock from each kind bruises off, before his fat and hide soften it
BRUISE := [Enemy_Kind]f32{.Turkey = 3, .Goat = 6, .Billy = 9, .Fox = 0}
// and a bee sting
BRUISE_STING :: f32(0.8)
// points a second, times 0.5 (lacking protein and vitamins) to 2 (plenty of both)
BRUISE_MEND :: f32(0.2)
// seconds after a knock before they start to mend
BRUISE_REST :: f32(5)
// from this share of the most, he says so
BRUISE_WARN :: f32(0.7)

// ---- muscle ----
// A trait's level is 0 when ordinary and 1 at the most it can be; a muscle can go below 0, down to -1, when it has wasted away.

// His muscles, in kg: wasted away, ordinary, and the most they can be.
ARMS_KG :: [3]f32{3, 5, 12}
// his leg muscles, in kg, likewise
LEGS_KG :: [3]f32{5, 8, 18}
// the share of a muscle or a skill of the body lost every second it is not used: half in two days (0.6931 is the natural log of 2)
FADE :: f32(0.6931 / (2 * DAY_SECONDS))
// training, wasting and recovering muscle go at this share of the pace they had when a session was a few minutes long: a seventh. (Training the skills of the body and of the kitchen is not slowed.)
MUSCLE_PACE :: f32(1.0 / 7)
// how fast muscle wastes each second without protein, or starving: ordinary to wasted in 77 minutes
WASTE :: f32(0.0015 * MUSCLE_PACE)
// and how fast wasted muscle comes back to ordinary once he is fed: in about an hour
RECOVER :: f32(0.002 * MUSCLE_PACE)
// full of protein, muscle builds this much faster
BULK :: f32(2)
// kg of energy each kg of muscle burns every second: 92 kcal a day, so 1,200 kcal a day for ordinary muscle (13 kg), 2,770 at the most (30 kg), 740 wasted (8 kg). It is what he burns for being alive, whatever he does
BASAL :: f32(92.0 / KCAL_PER_KG / DAY_SECONDS)

// ---- training ----
// How much each thing he does trains (a trait gains this share of what it still lacks).

// arms: each second of holding something of his own weight
CARRY_WORK :: f32(0.004)
// arms: each bash or throw of something of his own weight
SWING_WORK :: f32(0.02)
// legs and lungs: each second of sprinting
SPRINT_WORK :: f32(0.004)
// legs: each second of walking
WALK_WORK :: f32(0.0006)
// legs: each jump
JUMP_WORK :: f32(0.015)
// legs: each second of dragging a body
DRAG_WORK :: f32(0.002)
// hide: each peck or butt
KNOCK_WORK :: f32(0.04)
// hide: each sting
STING_WORK :: f32(0.01)
// gut: each kg of fibre eaten
GUT_WORK :: f32(0.2)
// hooves: each thing picked
PICK_WORK :: f32(0.02)
// hooves: each grab for a fish
FISH_WORK :: f32(0.04)
// hooves: each milking
MILK_WORK :: f32(0.05)
// baking, grilling, dairy: each thing made (half way after 11, nearly all after 50)
COOK_WORK :: f32(0.06)

// ---- skills ----
// What each trait is worth at its most (and a muscle at its worst).

// arms: how much more he lifts and how much harder he throws,
STRONG :: f32(1.8)
// and with arms wasted away
NOODLE_ARMS :: f32(0.6)
// legs: how much faster he walks and runs,
LEG_SPEED :: f32(1.3)
// and how much more goes into a jump;
when WORKBENCH {
	LEG_SPRING: f32 = 2
} else {
	LEG_SPRING :: f32(2)
}
// both, with legs wasted away
when WORKBENCH {
	WEAK_LEGS: f32 = 0.75
} else {
	WEAK_LEGS :: f32(0.75)
}
// lungs: the share of the usual stamina a sprint costs,
LUNG_DRAIN :: f32(0.55)
// and how much faster it comes back
LUNG_REGEN :: f32(1.6)
// the share of a knock he feels with no fat on him,
THIN_SKIN :: f32(1.5)
// with all the fat he can carry,
PADDED :: f32(0.5)
// and, on top of that, with the toughest hide
TOUGH_HIDE :: f32(0.5)
// gut: from this level he holds his wind until G is pressed,
GUT_CONTROL :: f32(0.4)
// seconds between two of them then,
GUT_HOLD :: f32(2)
// and how much further his wind reaches at the most
GUT_REACH :: f32(1.5)
// hooves: the share of the usual time picking takes,
DEFT_PICK :: f32(0.5)
// and how much further he reaches for a fish or a leg
DEFT_REACH :: f32(1.4)
// baking, grilling, dairy: the share of the usual time it takes at the most (the calories are in COOK_RANGE in food.json, making)
COOK_QUICK :: f32(0.5)

// ---- waking_up ----
// Waking up at home after the game was over: his fat is brought back inside these, he has lost this share of the muscle he had built, and his sack is gone. What he has learnt stays.
WAKE_FAT :: Vec2{25, 70}
// the share of his built-up muscle he has lost when he wakes up at home
WAKE_MUSCLE_LOSS :: f32(0.35)

// ---- shape ----
// His shape, in his body's own measurements. Prosio is short and stocky: short legs, a compact body and a big head.

// how far his ears hang over, in radians from straight up: almost straight down
EAR_DROOP :: f32(2.9)
// leg length, as a share of the old, longer legs
LEG_SCALE :: f32(0.86)
// the body from hips to neck, likewise
TORSO_SCALE :: f32(0.84)
// hip height in the body's own measurements
HIP :: f32(0.47)
// the middle of his head, above his feet
HEAD_HEIGHT :: HIP * LEG_SCALE + (1.72 - HIP) * TORSO_SCALE
// above his feet
SHOULDER_HEIGHT :: HIP * LEG_SCALE + (1.30 - HIP) * TORSO_SCALE

// ---- reactions ----
// How his body reacts for a moment: the belly full after a meal, wind, hiccups and tipsiness (see reactions.odin), and how his pose shows them.

// time occupied by taking a bite
PROSIO_MEAL_EAT_TIME :: f32(0.5)
// meal kg for full belly morph, seconds holding its size, and decay rate after the hold
PROSIO_MEAL_VISUAL :: Vec3{1.25, 3.5, 0.72}
// rate at which the belly approaches its current target
PROSIO_MEAL_EASE :: f32(9)
// seconds of wind recoil, hiccup recoil and tipsy preview
PROSIO_REACTION_TIME :: Vec3{0.65, 0.34, 6}
// tipsy sway frequency, its tilt, and the recovery lean for hiccups
PROSIO_REACTION_SWAY :: Vec3{4.4, 0.22, 0.27}
// pitch, hip roll and free-arm bracing when he passes wind
PROSIO_REACTION_WIND :: Vec3{0.32, 0.20, 0.26}
// arm spreading in a stagger, elbow tuck in a hiccup and hand lift in a hiccup
PROSIO_REACTION_ARMS :: Vec3{0.32, 0.32, 0.26}
// forward, sideways and vertical fullness of the procedural belly
PROSIO_MEAL_DRAW :: Vec3{0.09, 0.065, 0.032}
// share of a bite's time still to go when he swallows: the belly starts to fill from then
PROSIO_MEAL_SWALLOW :: f32(0.48)
// relative speed of the tipsy pose ramp-in and fade-out
PROSIO_TIPSY_FADE :: Vec2{12, 6}

