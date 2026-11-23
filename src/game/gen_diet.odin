package game

// Made by tools/gen_data from data/tuning/diet.json: do not edit; edit that file.

// What Prosio needs, and what being full or lacking each thing does to him. Levels are 0 to 100.

// ---- stores ----
// What he is made of besides fat and muscle.

// kg of him that never change: bones, and the rest
FRAME :: f32(12.5)
// What each store weighs when it is full, in kg. (Vitamins and electrolytes weigh nothing.)
STORE_KG := [Need]f32{.Carbs = 6, .Protein = 3, .Fibre = 2, .Water = 5, .Vitamins = 0, .Electrolytes = 0}
// Having run right out of these ends the game, if it lasts.
DEADLY := [Need]bool{.Carbs = false, .Protein = false, .Fibre = false, .Water = true, .Vitamins = true, .Electrolytes = true}
// calories of fibre to a kilogram of his fibre store
FIBRE_KCAL :: f32(60)
// calories of vitamins to a point of his vitamins level
VITAMIN_KCAL :: f32(1)
// and of electrolytes to a point of that level
SALT_KCAL :: f32(1)

// ---- levels ----
// Where each level starts, where lacking, full and too much begin, and how fast levels go down.

NEED_START :: f32(50)
WATER_START :: f32(80)
// below this he has run out
NEED_EMPTY :: f32(4)
// below this he lacks it
NEED_LOW :: f32(15)
// above this he is full of it
NEED_HIGH :: f32(70)
// above this it is too much
NEED_OVER :: f32(90)
WATER_LOW :: f32(25)
// the share of each level used up every second, at rest: half of it in 11 minutes
NEED_FADE :: f32(0.001)
// above NEED_OVER it moves on this many times as fast
SHED :: f32(6)
// water level used up every second: a full drink lasts a good quarter of an hour
THIRST :: f32(0.1)
// seconds without water, vitamins or electrolytes before the game is over
TOO_LONG :: f32(180)
DRINK_TIME :: f32(0.9)
// electrolytes the goats lick off him each second
LICK :: f32(0.25)
// electrolytes a drink washes out of him,
DRINK_SALT :: f32(25)
// but no lower than this
DRINK_SALT_FLOOR :: f32(40)

// ---- full_and_lacking ----
// What full and lacking do, in numbers.

// What full and lacking do, in numbers. sugar rush: how much faster he walks and runs,
RUSH_SPEED :: f32(1.25)
// and the share of the usual stamina a sprint costs
RUSH_DRAIN :: f32(0.3)
// seconds of sugar crash when the rush wears off,
CRASH_TIME :: f32(8)
// and how slow he is meanwhile
CRASH_SPEED :: f32(0.6)
// lacking carbs: the share of his stamina that comes back
NO_FUEL :: f32(0.5)
// seconds between his winds
GAS_EVERY :: Vec2{5, 8}
// animals this near run from it,
GAS_REACH :: f32(7.5)
// for this long
GAS_SCARE :: f32(5)
// the fibre level each one lets out
GAS_COST :: f32(1.5)
// seconds between tummy aches,
ACHE_EVERY :: Vec2{10, 16}
// and how long one stops him
ACHE_TIME :: f32(1)
// eagle eyes: how much further he sees,
EAGLE_SIGHT :: f32(1.8)
// and how far the camera pulls back
EAGLE_ZOOM :: f32(1.3)
DIM_SIGHT :: f32(0.6)
DIM_ZOOM :: f32(0.85)
// salty: how much faster he gets thirsty
SALTY_THIRST :: f32(2.5)
// lacking electrolytes: seconds of sprinting that bring on a cramp,
CRAMP_AFTER :: f32(2.5)
// and the share of his jump he still has
CRAMP_JUMP :: f32(0.6)
// full of protein: how much more everything burns (how much faster muscle builds is BULK in prosio.json, muscle)
BULK_BURN :: f32(1.4)
// thirsty: his stamina only comes back this far
THIRSTY_STAMINA :: f32(50)

// ---- too_much ----
// What too much of each does.

// Too much of each: seconds between hiccups
HICCUP_EVERY :: Vec2{1.5, 3.5}
// seconds between winds in a gas storm, each letting out twice the fibre
GAS_STORM :: Vec2{1.2, 2.5}
// glowing: how much further off the turkeys spot him
GLOW_NOTICE :: f32(1.5)
// parched: how much faster his water goes
PARCHED_THIRST :: f32(5)
// stiff: how much longer a swing or a stoop takes
STIFF :: f32(1.6)

