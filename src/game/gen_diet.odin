package game

// Made by tools/gen_data from data/tuning/diet.json: do not edit; edit that file.

// What Prosio needs, and what being full or lacking each thing does to him. Levels are 0 to 100.

// ---- stores ----
// What he is made of besides fat and muscle.

// kg of him that never change: bones, and the rest (14.9 so that he starts at 80 kg: it was 12.5 when his water store held 5 kg, not 2)
FRAME :: f32(14.9)
// What each store weighs when it is full, in kg. (Vitamins and electrolytes weigh nothing.) His water is light, so drinking and thirst move his weight by a kilogram or so, not by kilograms
STORE_KG := [Need]f32{.Carbs = 6, .Protein = 3, .Fibre = 2, .Water = 2, .Vitamins = 0, .Electrolytes = 0}
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

// where each level but water starts; above it, vitamins and electrolytes go in more slowly the fuller he is: each point taken in closes a share of what is left up to 100 (see need_points), so they go in the same however the food is shared out
NEED_START :: f32(50)
// where his water level starts
WATER_START :: f32(80)
// below this he has run out
NEED_EMPTY :: f32(4)
// below this he lacks it
NEED_LOW :: f32(15)
// above this he is full of it
NEED_HIGH :: f32(70)
// above this it is too much
NEED_OVER :: f32(90)
// below this he lacks water (water has its own line, higher than NEED_LOW)
WATER_LOW :: f32(25)
// the share of his fibre, vitamins and electrolytes used up every second, at rest: half of each in a day (0.6931 is the natural log of 2). Protein has its own, PROTEIN_FADE. Carbs are burned instead (see BASAL in prosio.json), and water has its own THIRST
NEED_FADE :: f32(0.6931 / DAY_SECONDS)
// the share of his protein used up every second, at rest (mending him, and counted as burned for his muscle): half of it in a third of a day, 20 minutes of play, so meat, fish and eggs must be eaten every day or so; raise it and protein goes sooner
PROTEIN_FADE :: f32(0.6931 / (DAY_SECONDS / 3))
// above NEED_OVER the share of it that moves on every second: too much of anything is over in a few minutes, as it was before the day was long (it does not follow NEED_FADE)
SHED :: f32(0.006)
// water level used up every second, at rest: from where it starts (WATER_START) to thirsty (WATER_LOW) in a quarter of the day, 15 minutes of play; a full drink lasts about 20 minutes, three or four drinks a day less what his food waters him (sprinting it goes twice as fast, salty or parched faster still; see SALTY_THIRST and PARCHED_THIRST). Raise it and he drinks more often
THIRST :: f32((WATER_START - WATER_LOW) / (DAY_SECONDS / 4))
// seconds without water, vitamins or electrolytes before the game is over
TOO_LONG :: f32(180)
// seconds a drink takes
DRINK_TIME :: f32(0.9)
// electrolytes the goats lick off him each second
LICK :: f32(0.25)
// electrolytes a drink washes out of him,
DRINK_SALT :: f32(25)
// but no lower than this
DRINK_SALT_FLOOR :: f32(40)

// ---- stomach ----
// His stomach: it limits how much he eats at once, by volume. What he eats takes room in it (its weight in ITEM_KG, food.json, times STOMACH_K) and leaves it at a steady pace. He can eat while it is not full; a big piece (a pumpkin) may fill it past full, and then he must wait. What he eats waits in it, and goes into him as it leaves, all of it in the end: see digest in diet.odin. (Water he drinks goes straight in, without taking room.)

// litres of stomach a kilogram of food takes; raise it and food is bulkier
STOMACH_K :: f32(1)
// litres his stomach holds: about a kilogram and a half of food at once (a pumpkin fills it); raise it and he eats more at a sitting
STOMACH_HOLDS :: f32(1.5)
// he is full from this share of what it holds, and eats nothing more until it is below it again: after a pumpkin, about half a minute; raise it towards 1 and he waits less
STOMACH_FULL :: f32(0.9)
// seconds a full stomach takes to empty: 2 hours of the game's day, 5 minutes of play, so up to 18 litres of food a day (it was 5 hours with a litre, and he waited too long to eat again); raise it and he eats less a day
STOMACH_EMPTIES :: f32(2.0 / 24 * DAY_SECONDS)

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
// lacking vitamins: how far he sees, as a share of the usual,
DIM_SIGHT :: f32(0.6)
// and how far the camera pulls back, as a share of the usual (under 1 brings it in)
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

