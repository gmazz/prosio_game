package game

// Made by tools/gen_data from data/tuning/animals.json: do not edit; edit that file.

// The turkeys, the goats, the billy goat and the foxes: their size, speed and strength, how they hunt, flee, swim and drown, what a blow does to them, and how the animals from the animal pack move, fall and are dragged.

// ---- all_animals ----
// room for this many animals at once, a count: turkeys, goats, the billy goat and foxes together
MAX_ENEMIES :: 40
// animals further than this from Prosio rest
AWAKE :: f32(42)
// A bump hits with Prosio's momentum: his weight times his speed. An enemy digs in and soaks up the first part of that (its grip); only what is left over throws it: launch speed = BUMP_GAIN * (weight * speed - grip) / enemy's weight So a lean Prosio just bounces off, and the throw grows quickly with weight.
when WORKBENCH {
	BUMP_GAIN: f32 = 0.479
} else {
	BUMP_GAIN :: f32(0.479)
}
// How hard an enemy shoves Prosio: speed = BONK * enemy's weight / Prosio's weight
BONK :: f32(31)
// A big farm turkey, a goat, and the billy goat, who weighs more than an ordinary Prosio.
ENEMY_KG := [Enemy_Kind]f32{.Turkey = 16, .Goat = 55, .Billy = 95, .Fox = 20}
// how big each kind is: its radius on the ground in metres, which also sets how big it is drawn; raise it and it is bigger and bumps into things sooner
ENEMY_RADIUS := [Enemy_Kind]f32{.Turkey = 0.42, .Goat = 0.62, .Billy = 0.78, .Fox = 0.45}
// (faster than a turkey: a goat is a runner)
ENEMY_SPEED := [Enemy_Kind]f32{.Turkey = 2.8, .Goat = 3.2, .Billy = 2.9, .Fox = 3.4}
// how many times its own speed a goat charges at
GOAT_CHARGE :: f32(1.8)
// its grip in the bump above: how much of his momentum (kg times m/s) it soaks up before it moves at all; raise it and a bump throws it less
ENEMY_GRIP := [Enemy_Kind]f32{.Turkey = 560, .Goat = 450, .Billy = 500, .Fox = 600}
// Knocked out, a turkey or a goat is dead: its body lies where it fell for BODY_LIFE, and chopped up at the fire (CHOP_TIME a cut) it gives this share of its weight in cuts of meat, ITEM_KG[.Meat] each (food.json), to the nearest cut: a turkey (16 kg) 3 cuts, about 900 kcal; a goat (55 kg) 12; the billy goat (95 kg) 20. (Gio's 4%: a real carcass gives about ten times as much; this is for balance, so one turkey is a few days' protein, not a week's.) Raise it and every kind gives more meat
MEAT_SHARE :: f32(0.04)
// which kinds give meat; nobody eats a fox: knocked out, it only slinks off for a while
MEAT_FROM := [Enemy_Kind]bool{.Turkey = true, .Goat = true, .Billy = true, .Fox = false}
// seconds, at random in this range, before another takes the place of an animal that was killed (chopped up, rotted away or drowned): about two days of play; raise it and the flocks take longer to come back
KILLED_BACK :: Vec2{1.75 * DAY_SECONDS, 2.25 * DAY_SECONDS}
// seconds, at random in this range, before another of each kind takes the place of one that is gone but was not killed: lost in the fog, or a fox that slunk off (as it was, times MEADOW_SLOW: a turkey 75 to 120 minutes, a fox 15 to 30)
RESPAWN := [Enemy_Kind]Vec2{.Turkey = {300 * MEADOW_SLOW, 480 * MEADOW_SLOW}, .Goat = {480 * MEADOW_SLOW, 720 * MEADOW_SLOW}, .Billy = {600 * MEADOW_SLOW, 900 * MEADOW_SLOW}, .Fox = {60 * MEADOW_SLOW, 120 * MEADOW_SLOW}}
// seconds a dead body lies where it fell before it is gone; the longer it has lain, the poorer its meat
BODY_LIFE :: f32(240)
// An animal that has chased him this far from its home gives up, and ambles back for GIVE_UP seconds whatever he does.
LEASH := [Enemy_Kind]f32{.Turkey = 30, .Goat = 26, .Billy = 26, .Fox = 1000}
// seconds it ambles back home once it has gone past its LEASH, whatever he does
GIVE_UP :: f32(8)

// ---- eggs_milk_and_the_fox ----
// a turkey lays an egg every so many seconds, at random in this range: only now and then (as it was, times MEADOW_SLOW)
EGG_EVERY :: Vec2{600 * MEADOW_SLOW, 1200 * MEADOW_SLOW}
// chance that shaking a held turkey shakes an egg out of it: hardly ever
SHAKE_EGG :: f32(0.01)
// a penned turkey, settled and fed, lays far more often: two to four eggs a day
PEN_EGG_EVERY :: Vec2{60 * MEADOW_SLOW, 120 * MEADOW_SLOW}
// seconds until a milked goat has milk again: 45 minutes, so a jug or two a day
MILK_EVERY :: f32(180 * MEADOW_SLOW)
// A goat he has hit will not lick him, however salty he is, until it has not seen him (he is further off than SOUR_SIGHT) for SOUR_FORGET seconds.
SOUR_SIGHT :: f32(22)
// seconds a goat he hit must go without seeing him before it will lick him again; raise it and it bears a grudge longer
SOUR_FORGET :: f32(90)
// how far off a fox scents his sack
FOX_NOTICE :: f32(13)
// seconds a fox keeps away after a theft or a fright
FOX_REST :: f32(25)
// seconds it carries what it took before eating it wherever it is
FOX_PATIENCE :: f32(30)

// ---- swimming ----
// Thrown into the pond, an animal swims for the nearest bank, this fast (m/s) and losing this much health a second while it does: a fox swims well, a goat tires, and a turkey is no swimmer at all, so one that lands far out goes bottoms up (comically: feet in the air, cross eyes, bubbles), then sinks out of sight: nothing of it comes ashore.
SWIM_SPEED := [Enemy_Kind]f32{.Turkey = 0.7, .Goat = 1.1, .Billy = 0.9, .Fox = 1.6}
// health each kind loses every second it swims (out of ENEMY_HEALTH); at 0 it never drowns
DROWN_RATE := [Enemy_Kind]f32{.Turkey = 16, .Goat = 3, .Billy = 5, .Fox = 0}
// how far down it sits in the water
SWIM_SINK := [Enemy_Kind]f32{.Turkey = 0.16, .Goat = 0.62, .Billy = 0.75, .Fox = 0.3}
// seconds a drowned one floats bottoms up,
SINK_WAIT :: f32(1.5)
// then sinks this fast (m/s)
SINK_SPEED :: f32(0.5)
// until it is this deep, and gone
SINK_DEPTH :: f32(1.4)

// ---- health_and_blows ----
// Every animal has the same measure of health, ENEMY_HEALTH, and every blow takes from it: a bump, being thrown, bashed or slammed about, hit by another animal, a stone or a rock, a spear, a stomp. What a blow takes is the energy that reaches the animal in joules (half its mass times its speed squared; for a stomp his weight times FALL_GRAVITY times the height he came down from and STOMP_SINK; a stone or a rock counts part of its momentum instead, STONE_MOMENTUM_SHARE), times BLOW_FACTOR for the kind of blow (and for a spear the animal's ENEMY_HIDE), out of what the animal can take: BLOW_TAKES joules for each kilogram of it, times its ENEMY_TOUGH. With no health left it is knocked out for good. It mends from the moment it is hit, slowly at first and faster the longer it is left alone: HEAL_RATE a second once HEAL_RAMP seconds have gone by without a blow.
ENEMY_HEALTH :: f32(100)
// joules, for each kilogram of an animal, of a blow with BLOW_FACTOR 1 that take all its health. Raise it and every animal is harder to hurt, by every blow alike
when WORKBENCH {
	BLOW_TAKES: f32 = 600
} else {
	BLOW_TAKES :: f32(600)
}
// what each kind can take, as a share of BLOW_TAKES times its weight, against every kind of blow: a goat and the billy goat take less for their weight than a turkey, so that a stomp takes as much from a goat as from a turkey and two thirds as much from the billy goat. Raise one and that kind is harder to hurt by everything
ENEMY_TOUGH := [Enemy_Kind]f32{.Turkey = 1, .Goat = 0.29, .Billy = 0.25, .Fox = 1}
// the share of a spear's harm that gets through each kind's hide: a goat's coat and the billy goat's thick hide turn some of it. Set so that an ordinary Prosio (80 kg) brings down a turkey with four spears, a goat or a fox with five and the billy goat with eight. Lower one and spears do less to that kind, and nothing else changes
ENEMY_HIDE := [Enemy_Kind]f32{.Turkey = 1, .Goat = 0.8, .Billy = 0.71, .Fox = 1}
// how much of a blow's energy harms, by its kind: soft (his belly in a bump, a thrown or bashed animal, one animal into another: they give, and spread it), hard (his hooves in a stomp, a stone, a rock) and sharp (a spear: it puts it all into a small place, and goes deep). Soft: a bump or a bash takes a quarter of what it took before the blows went by energy. Hard: a 2 kg stone takes about a tenth of a turkey, a stomp about a tenth, and the heaviest rock an ordinary Prosio lifts (40 kg) a seventh (a third with STONE_MOMENTUM_SHARE at 0.5). Sharp: a spear at ARM_SPEED takes about 28 in a hundred of a turkey's health. Raise one and every blow of that kind harms more
BLOW_FACTOR := [Blow]f32{.Soft = 0.42, .Hard = 2.1, .Sharp = 7.4}
// the share of a stone's or a rock's harm that goes by its momentum instead of its energy: the joules that count are (1 - share) times half its mass times its speed squared, plus share times its mass times its speed times ARM_SPEED / 2. At 0 a stone harms by its energy alone, as physics has it, and a heavy rock, which he can only lob slowly, does little; at 1 by its momentum alone. A stone thrown at ARM_SPEED harms the same at any share. It starts at 0, as Gio set it. Raise it and heavy, slow rocks harm more
when WORKBENCH {
	STONE_MOMENTUM_SHARE: f32 = 0
} else {
	STONE_MOMENTUM_SHARE :: f32(0)
}
// m/s each second: the gravity the energy of a fall is counted with, in a stomp and in a stone or a rock that comes down on an animal. The things in the meadow fall faster (GRAVITY in world.json, 25, so that jumps are snappy), which would give every fall two and a half times its real energy, while throws are at real-world strength (THROW_ENERGY): this keeps the two at the same scale. Raise it and stomps and dropped rocks harm more
when WORKBENCH {
	FALL_GRAVITY: f32 = 9.8
} else {
	FALL_GRAVITY :: f32(9.8)
}
// health it mends each second at the most, once HEAL_RAMP seconds have gone by since it was last hurt: from nothing to whole in 30 seconds at that speed. Raise it and animals mend faster
when WORKBENCH {
	HEAL_RATE: f32 = ENEMY_HEALTH / 30
} else {
	HEAL_RATE :: f32(ENEMY_HEALTH / 30)
}
// seconds after a blow until it mends at the full HEAL_RATE: it starts mending at once, at a speed that grows with the time since it was last hurt (2 seconds after a hit it has mended 0.3 in a hundred, after 10 seconds 8, after 20 seconds 33). So blows close together keep it from mending, and one that gets away mends quickly. Raise it and an animal mends more slowly after each blow
when WORKBENCH {
	HEAL_RAMP: f32 = 20
} else {
	HEAL_RAMP :: f32(20)
}
// how fast it still goes with almost no health left, as a share
HURT_SLOW :: f32(0.6)
// metres. Prosio comes down on an animal: the energy of the blow is his weight (with what he carries) times FALL_GRAVITY times the height he came down from (the top of his jump), and STOMP_SINK more metres, as he goes on pressing while he sinks into it. A stone or a rock coming down on an animal presses on the same way. A jump puts the same energy into him whatever he weighs (by his legs: see JUMP_ENERGY in prosio.json), so it is the sinking that makes a heavier Prosio stomp harder with the same legs, and stronger legs jump higher and stomp harder. Raise it and every stomp harms more, a heavy Prosio's most
when WORKBENCH {
	STOMP_SINK: f32 = 0.15
} else {
	STOMP_SINK :: f32(0.15)
}
// seconds an animal he stomps on stays flattened for each unit of his momentum as he lands (kg times m/s, his weight times his falling speed, as fast as he really falls, by GRAVITY): an ordinary Prosio pins one for about 2 seconds, a heavier one longer
when WORKBENCH {
	STOMP_PIN: f32 = 0.0053
} else {
	STOMP_PIN :: f32(0.0053)
}

// ---- boldness_and_alarm ----
// When one of a flock takes a real blow, the others nearby may run for it: each with a chance that goes with how dangerous he is (threat times SCATTER), so from a strong Prosio nearly all of them scatter and from a weak one hardly any. The one that was hit may run too, once it is up.

// A small, weak Prosio they know they can beat, and they press him harder: faster, from further off, more of them at once. This is 1 when he is no danger to them at all (threat under FEARLESS_BELOW) and 0 once he is (RESPECT_ABOVE and over), which the pig he starts as already is.
FEARLESS_BELOW :: f32(0.04)
// the threat (0 to 1) from which they no longer press him; their boldness fades out between FEARLESS_BELOW and this
RESPECT_ABOVE :: f32(0.16)
// how much faster the boldest are
BOLD_SPEED :: f32(0.3)
// and from how much further off they come for him
BOLD_NOTICE :: f32(0.4)
// A big, strong Prosio they fear: from threat WARY_FROM they dart in less, and hardly at all from WARY_FULL.
WARY_FROM :: f32(0.45)
// the threat (0 to 1) from which they hardly dart in at all; their wariness grows between WARY_FROM and this
WARY_FULL :: f32(0.75)
// How dangerous each kind thinks Prosio is (his threat to it, 0 to 1): the square of how fast he could throw one of it (by his weight and arms, wound up fully), over this speed in m/s. It goes by how he looks, not by what a blow would take (see ENEMY_HEALTH): the same as before the blows went by energy, so the pig he starts as is just dangerous enough to turkeys and goats that they do not press him. Raise one and that kind is bolder
ENEMY_DREAD := [Enemy_Kind]f32{.Turkey = 26.5, .Goat = 10.4, .Billy = 6.6, .Fox = 22.7}
// a blow at least this hard is noticed
ALARM_BLOW :: f32(8)
// metres: animals of the same flock within this of the one hit may run
ALARM_RANGE :: f32(11)
// each one's chance of running is his threat times this (never above 0.95); raise it and more of them scatter
SCATTER :: f32(1.6)
// seconds they keep away
FRIGHT :: Vec2{6, 12}

// ---- pack_animals_moving ----
// The goats and the fox drawn from the animal pack: when they walk and gallop, how they turn, and their heads. How it goes from standing to walking to galloping, by its speed (m/s): each blends into the next, on one stride cycle, so nothing jumps. A goat on four legs cannot slide sideways (see quad_steer):

// small closed or crossed eye marks in this rig's units
QUAD_EYE_SIZE :: f32(0.047)
// an animal out of the picture is not bent or drawn: how much further than at rest any of it may reach in a pose (lying down, held, kicking), as a share of its reach at rest
QUAD_VIEW_ROOM :: f32(1.6)
// how far a held animal's free legs kick out as it struggles, as a share of its radius
QUAD_GRAB_KICK :: f32(0.4)
// how far (radians) a held animal's front half twists and rolls as it struggles
QUAD_GRAB_TWIST :: f32(0.16)
// it starts to walk,
QUAD_WALK_FROM :: f32(0.08)
// and is walking from here;
QUAD_WALK_FULL :: f32(0.4)
// the gallop starts to take over (only a charge is this fast: chasing, backing off or trotting up it walks, briskly),
QUAD_GALLOP_FROM :: f32(3.2)
// and has from here
QUAD_GALLOP_FULL :: f32(4.2)
// a gallop's legs never go slower than this share of their own pace
QUAD_GALLOP_SLOWEST :: f32(0.65)
// going slowly it takes shorter steps: this share of the walk's own, quicker for it,
QUAD_SHORT_STEP :: f32(0.6)
// growing to the full step at this speed (m/s)
QUAD_LONG_STEP_AT :: f32(2.5)
// how far (radians) a packed animal turns its head to watch him,
QUAD_HEAD_TURN :: f32(0.9)
// how fast it turns it (radians a second; with him behind it, it looks ahead)
QUAD_HEAD_SPEED :: f32(3.5)
// how fast it gets up to speed, or stops (m/s each second; the drawn ones 10),
QUAD_GOAT_ACCEL :: f32(12)
// how fast it turns (radians a second),
QUAD_TURN :: f32(4.5)
// how fast it backs off, facing him (m/s),
QUAD_BACKWARDS :: f32(1.1)
// it walks no slower than this (m/s): it stands, or walks;
QUAD_SLOWEST :: f32(0.8)
// standing, it sets off once it wants to go this fast, and walking it stops below
QUAD_SET_OFF :: f32(0.3)
// this (so it does not creep, its legs barely moving),
QUAD_STOP :: f32(0.12)
// turning on the spot, its hooves step as if it walked this far (m) for each radian
QUAD_TURN_STEP :: f32(0.25)

// ---- pack_animals_body ----
// How their bodies follow a turn, give way when pushed, and struggle when held.

// Feed the authored gaits from actual travel and turns after collisions.
QUAD_BODY_FOLLOW :: f32(10)
// the most (radians) its hips swing round behind its chest in a turn or a sideways shove
QUAD_REAR_TWIST_MAX :: f32(0.28)
// the most (radians) its body leans in a turn or a sideways shove
QUAD_BODY_LEAN_MAX :: f32(0.12)
// seconds a goat or a fox gives way, stepping aside, when he pushes into it (a fox also backs off this long after eating what it stole)
QUAD_YIELD_TIME :: f32(0.38)
// how fast it steps aside when it gives way, m/s
QUAD_YIELD_SPEED :: f32(2.2)
// it gives way when he presses into it faster than this, m/s,
QUAD_YIELD_MIN_SPEED :: f32(0.2)
// or when he is this far into it, in metres
QUAD_YIELD_OVERLAP :: f32(0.035)
// phase radians a second
QUAD_STRUGGLE_RATE :: f32(18)

// ---- dragging ----
// A body dragged along the ground.

// Pitch and roll of the fallen clip, measured so the head, ribs and forelegs share the ground instead of balancing on a low ear.
QUAD_DRAG_SETTLE := [Quad_Kind]Vec2{.Goat = {0.25, 0.3}, .Billy = {0.25, 0.25}, .Packfox = {-0.075, 0.275}}
// how far (radians) a dragged body's hips are tipped, against its front half
QUAD_DRAG_HIP_PITCH :: f32(0.48)
// how far (radians) its hips roll over,
QUAD_DRAG_HIP_ROLL :: f32(0.28)
// and how much further (radians) they roll as he pulls it sideways
QUAD_DRAG_HIP_PULL :: f32(0.08)
// grip height in fox radii before the hips lift more
QUAD_DRAG_HIGH_TAIL :: f32(1.5)
// the most (radians) a dragged fox's hips tip further up when he holds it higher than QUAD_DRAG_HIGH_TAIL
QUAD_DRAG_TAIL_LIFT :: f32(0.56)
// the share of a held leg's full length it may stretch to reach his hoof: just under 1, so it never locks straight
QUAD_DRAG_REACH_MARGIN :: f32(0.995)

// ---- impacts ----
// What a blow does to an animal: by the speed it is knocked at, it is pushed, stumbles, falls or is launched, then tumbles, settles and gets up.

// Speed transferred to the animal, after its grip and mass have absorbed the blow.
IMPACT_STUMBLE_SPEED :: f32(0.9)
// from this speed (m/s) a blow knocks it over; below it, it only stumbles
IMPACT_FALL_SPEED :: f32(2)
// from this speed (m/s) a blow sends it flying
IMPACT_LAUNCH_SPEED :: f32(3)
// even the lightest blow moves it at least this fast, m/s
IMPACT_MIN_PUSH :: f32(0.22)
// the fastest (m/s) a blow sends it upwards
IMPACT_MAX_RISE :: f32(6.5)
// the share of a launch's speed that goes upwards
IMPACT_RISE_SHARE :: f32(0.55)
// how fast it spins when knocked over or flying, radians a second for each m/s of the blow,
IMPACT_SPIN_PER_SPEED :: f32(1.1)
// but never faster than this, radians a second
IMPACT_MAX_SPIN :: f32(7.5)
// coming down faster than this (m/s), it bounces
IMPACT_REBOUND_SPEED :: f32(6)
// the share of its falling speed a bounce sends back up
IMPACT_RESTITUTION :: f32(0.22)
// the share of its speed along the ground it keeps each time it comes down
IMPACT_LANDING_KEEP :: f32(0.72)
// seconds it tumbles once it has landed
IMPACT_TUMBLE_TIME :: f32(0.42)
// seconds it takes to tip over when knocked down without flying
IMPACT_FALL_TIP_TIME :: f32(0.36)
// seconds it takes to settle on its side
IMPACT_SETTLE_TIME :: f32(0.48)
// seconds it lies there before it gets up
IMPACT_DOWN_TIME :: f32(0.55)
// seconds it takes to get back on its feet
IMPACT_GET_UP_TIME :: f32(0.72)
// how fast it slows while it tumbles and lies there, m/s each second,
IMPACT_TUMBLE_DRAG :: f32(5.5)
// and this much more for each m/s it is still going
IMPACT_SLIDE_DRAG :: f32(1.3)
// how fast it slows when only pushed or stumbling, m/s each second
IMPACT_BRACE_DRAG :: f32(6.5)
// how fast its tumbling spin dies away, radians a second each second
IMPACT_SPIN_DRAG :: f32(8)
// seconds it staggers when pushed, or when it stumbles
IMPACT_BRACE_TIME := #partial [Impact_Kind]f32{.Push = 0.33, .Stumble = 0.56}
// how far (radians) it leans with the blow as it staggers
IMPACT_BRACE_LEAN := #partial [Impact_Kind]f32{.Push = 0.11, .Stumble = 0.42}
// seconds its legs take to fold up as it flies or tumbles
IMPACT_BEND_TIME :: f32(0.32)
// how far (radians) it lies over once down: a little short of flat on its side
IMPACT_SIDE_ANGLE :: f32(1.44)
// below this height (metres) a flying body is eased onto the ground, so it does not sink in
IMPACT_GROUND_BLEND_HEIGHT :: f32(0.75)
// how much a fall tips it onto its side rather than over its head or tail
IMPACT_SIDE_BIAS :: f32(0.35)

// ---- impact_pose ----
// How a knocked animal's body and legs are drawn while it stumbles and falls.

// the height, in its radii, a goat or a fox turns about as it falls
IMPACT_QUAD_PIVOT :: f32(1.1)
// and a turkey
IMPACT_TURKEY_PIVOT :: f32(1.18)
// how far (radians) its legs swing as it staggers
IMPACT_STEP_ANGLE :: f32(0.43)
// how far (radians) its hind legs fold once it is down
IMPACT_HIND_TUCK :: f32(-0.7)
// and its front legs
IMPACT_FRONT_TUCK :: f32(0.65)
// how far (radians) its legs splay out sideways once it is down
IMPACT_LEG_SPLAY :: f32(0.24)

