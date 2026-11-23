package game

// Made by tools/gen_data from data/tuning/prosio.json: do not edit; edit that file.

// Prosio himself: his fat, his size, what he burns, his bruises, and how his muscles and skills grow and fade.

// ---- fat ----
// Prosio's fat, in kilograms. (His weight is this and the rest of him, added up in diet.odin.) Running out of it and of his carbs as well, or carrying too much fat, is a fail.

// heart gives up
FAT_MAX :: f32(100)
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
STAMINA_MAX :: f32(100)
DASH_TIME :: f32(0.28)
// stooping to pick something up and putting it in the sack
PICK_TIME :: f32(0.5)
// Ordinary legs put the same energy into every jump, so height = energy / weight: a 40 kg Prosio jumps 0.9 high, a 120 kg Prosio only 0.3. Strong legs put in more (see LEG_SPRING in body.odin).
JUMP_ENERGY :: f32(36)

// ---- burning ----
// Everything he does burns some of his weight, a little for everyday things and more for fighting. Walking and running burn in proportion to his weight: these are for an 80 kg Prosio.

// kg per second of walking
WALK_BURN :: f32(0.02)
// kg per second of sprinting
SPRINT_BURN :: f32(0.06)
LOAD_EASE :: f32(0.6) // the share of the sack's weight his legs feel (it is on his back, well packed)
// so with 16 kg in the sack his legs train 1.36 times as fast
LOAD_TRAIN :: f32(3)
// a sack this share of his weight, and he says so
LOAD_HEAVY :: f32(0.3)
// kg per thing picked up
GATHER_BURN :: f32(0.03)
// kg per jump
JUMP_BURN :: f32(0.06)
// kg per bump, grab, bash or throw
FIGHT_BURN :: f32(0.2)

// ---- bruises ----
// A knock from an animal, or a sting, leaves a bruise: no weight is lost, but the top of his stamina comes down by that much until it mends, so a battered Prosio cannot sprint or fight for long and has to get away. The bruises never take more than BRUISE_MOST, which leaves him BRUISE_FLOOR of his stamina to run with; bruised that far, the next thing is that he is knocked out, and wakes up at home.
BRUISE_FLOOR :: f32(0.25)
BRUISE_MOST :: STAMINA_MAX * (1 - BRUISE_FLOOR)
BRUISE := [Enemy_Kind]f32{.Turkey = 3, .Goat = 6, .Billy = 9, .Fox = 0}
BRUISE_STING :: f32(0.8)
BRUISE_MEND :: f32(0.2) // points a second, times 0.5 (lacking protein and vitamins) to 2 (plenty of both)
// seconds after a knock before they start to mend
BRUISE_REST :: f32(5)
// from this share of the most, he says so
BRUISE_WARN :: f32(0.7)

// ---- muscle ----
// A trait's level is 0 when ordinary and 1 at the most it can be; a muscle can go below 0, down to -1, when it has wasted away.

// His muscles, in kg: wasted away, ordinary, and the most they can be.
ARMS_KG :: [3]f32{3, 5, 12}
LEGS_KG :: [3]f32{5, 8, 18}
// the share of a trait lost every second it is not used: half in 18 minutes
FADE :: f32(0.00064)
// how fast muscle wastes each second without protein, or starving: ordinary to wasted in 11 minutes
WASTE :: f32(0.0015)
// and how fast wasted muscle comes back to ordinary once he is fed
RECOVER :: f32(0.002)
// full of protein, muscle builds this much faster
BULK :: f32(2)
// kg of energy each kg of muscle burns every second: 0.18 kg a minute for ordinary muscle, 0.41 at the most, 0.11 wasted
BASAL :: f32(0.00023)

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
COOK_WORK :: f32(0.06) // baking, grilling, dairy: each thing made (half way after 11, nearly all after 50)

// ---- skills ----
// What each trait is worth at its most (and a muscle at its worst).

// arms: how much more he lifts and how much harder he throws,
STRONG :: f32(1.8)
// and with arms wasted away
NOODLE_ARMS :: f32(0.6)
// legs: how much faster he walks and runs,
LEG_SPEED :: f32(1.3)
// and how much more goes into a jump;
LEG_SPRING :: f32(2)
// both, with legs wasted away
WEAK_LEGS :: f32(0.75)
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
COOK_QUICK :: f32(0.5) // baking, grilling, dairy: the share of the usual time it takes at the most (the calories are in COOK_RANGE in kitchen.odin)

// ---- waking_up ----
// Waking up at home after the game was over: his fat is brought back inside these, he has lost this share of the muscle he had built, and his sack is gone. What he has learnt stays.
WAKE_FAT :: Vec2{25, 70}
WAKE_MUSCLE_LOSS :: f32(0.35)

