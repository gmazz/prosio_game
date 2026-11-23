package game

// Made by tools/gen_data from data/tuning/animals.json: do not edit; edit that file.

// The turkeys, the goats, the billy goat and the foxes: their size, speed and strength, how they hunt, flee, swim and drown, what a blow does to them, and how the animals from the animal pack move, fall and are dragged.

// ---- all_animals ----
MAX_ENEMIES :: 40
// animals further than this from Prosio rest
AWAKE :: f32(42)
// A bump hits with Prosio's momentum: his weight times his speed. An enemy digs in and soaks up the first part of that (its grip); only what is left over throws it: launch speed = BUMP_GAIN * (weight * speed - grip) / enemy's weight So a lean Prosio just bounces off, and the throw grows quickly with weight.
BUMP_GAIN :: f32(0.479)
// How hard an enemy shoves Prosio: speed = BONK * enemy's weight / Prosio's weight
BONK :: f32(31)
// A big farm turkey, a goat, and the billy goat, who weighs more than an ordinary Prosio.
ENEMY_KG := [Enemy_Kind]f32{.Turkey = 16, .Goat = 55, .Billy = 95, .Fox = 20}
ENEMY_RADIUS := [Enemy_Kind]f32{.Turkey = 0.42, .Goat = 0.62, .Billy = 0.78, .Fox = 0.45}
// (faster than a turkey: a goat is a runner)
ENEMY_SPEED := [Enemy_Kind]f32{.Turkey = 2.8, .Goat = 3.2, .Billy = 2.9, .Fox = 3.4}
// how many times its own speed a goat charges at
GOAT_CHARGE :: f32(1.8)
ENEMY_GRIP := [Enemy_Kind]f32{.Turkey = 560, .Goat = 450, .Billy = 500, .Fox = 600}
// Knocked out, a turkey or a goat is dead: its body lies where it fell for BODY_LIFE, and chopped up at the fire it gives this many pieces of meat. A fox only slinks off for a while. Another animal takes a dead one's place, but not for a good while (seconds, somewhere in this range): so hunting thins the flock, and with it the eggs.
MEAT_FROM := [Enemy_Kind]int{.Turkey = 2, .Goat = 5, .Billy = 8, .Fox = 0}
RESPAWN := [Enemy_Kind]Vec2{.Turkey = {300, 480}, .Goat = {480, 720}, .Billy = {600, 900}, .Fox = {60, 120}}
BODY_LIFE :: f32(240)
// An animal that has chased him this far from its home gives up, and ambles back for GIVE_UP seconds whatever he does.
LEASH := [Enemy_Kind]f32{.Turkey = 30, .Goat = 26, .Billy = 26, .Fox = 1000}
GIVE_UP :: f32(8)

// ---- eggs_milk_and_the_fox ----
// a turkey lays an egg every so many seconds, at random in this range: only now and then
EGG_EVERY :: Vec2{600, 1200}
// chance that shaking a held turkey shakes an egg out of it: hardly ever
SHAKE_EGG :: f32(0.01)
// a penned turkey, settled and fed, lays far more often
PEN_EGG_EVERY :: Vec2{60, 120}
// seconds until a milked goat has milk again
MILK_EVERY :: f32(180)
// A goat he has hit will not lick him, however salty he is, until it has not seen him (he is further off than SOUR_SIGHT) for SOUR_FORGET seconds.
SOUR_SIGHT :: f32(22)
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
// Every animal has the same measure of health, ENEMY_HEALTH, and every kind of blow takes from it: being thrown, bumped, bashed on the ground, hit by a rock or by another animal, stomped on. What a blow takes goes with the square of its speed, measured against how sturdy that kind is: a blow at its sturdy speed takes HARD_BLOW. A heavy animal is the less sturdy, since it comes down that much harder: a toss a turkey shrugs off would break a billy goat. With no health left it is knocked out for good. Left alone for HEAL_AFTER seconds it starts to mend, HEAL_RATE a second.
ENEMY_HEALTH :: f32(100)
HARD_BLOW :: f32(28)
ENEMY_STURDY := [Enemy_Kind]f32{.Turkey = 14, .Goat = 5.5, .Billy = 3.5, .Fox = 12}
HEAL_RATE :: f32(1.2)
HEAL_AFTER :: f32(8)
// how fast it still goes with almost no health left, as a share
HURT_SLOW :: f32(0.6)
// Prosio comes down on an animal: the blow is his weight times the height he came down from (the top of his jump), times STOMP_K. Every Prosio hits as hard, since a heavy one cannot jump as high: weight times jump height is always 36 (more with a rock in his arms). It takes from the animal's health like any blow: all of it at ENEMY_TOUGH, so a turkey is done for by two stomps, a goat by four and the billy goat by five.
STOMP_K :: f32(1)
ENEMY_TOUGH := [Enemy_Kind]f32{.Turkey = 50, .Goat = 110, .Billy = 160, .Fox = 60}

// ---- boldness_and_alarm ----
// When one of a flock takes a real blow, the others nearby may run for it: each with a chance that goes with how dangerous he is (threat times SCATTER), so from a strong Prosio nearly all of them scatter and from a weak one hardly any. The one that was hit may run too, once it is up.

// A small, weak Prosio they know they can beat, and they press him harder: faster, from further off, more of them at once. This is 1 when he is no danger to them at all (threat under FEARLESS_BELOW) and 0 once he is (RESPECT_ABOVE and over), which the pig he starts as already is.
FEARLESS_BELOW :: f32(0.04)
RESPECT_ABOVE :: f32(0.16)
// how much faster the boldest are
BOLD_SPEED :: f32(0.3)
// and from how much further off they come for him
BOLD_NOTICE :: f32(0.4)
// A big, strong Prosio they fear: from threat WARY_FROM they dart in less, and hardly at all from WARY_FULL.
WARY_FROM :: f32(0.45)
WARY_FULL :: f32(0.75)
// a blow at least this hard is noticed
ALARM_BLOW :: f32(8)
ALARM_RANGE :: f32(11)
SCATTER :: f32(1.6)
// seconds they keep away
FRIGHT :: Vec2{6, 12}

// ---- pack_animals_moving ----
// The goats and the fox drawn from the animal pack: when they walk and gallop, how they turn, and their heads. How it goes from standing to walking to galloping, by its speed (m/s): each blends into the next, on one stride cycle, so nothing jumps. A goat on four legs cannot slide sideways (see quad_steer):

// small closed or crossed eye marks in this rig's units
QUAD_EYE_SIZE :: f32(0.047)
QUAD_GRAB_KICK :: f32(0.4)
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
QUAD_REAR_TWIST_MAX :: f32(0.28)
QUAD_BODY_LEAN_MAX :: f32(0.12)
QUAD_YIELD_TIME :: f32(0.38)
QUAD_YIELD_SPEED :: f32(2.2)
QUAD_YIELD_MIN_SPEED :: f32(0.2)
QUAD_YIELD_OVERLAP :: f32(0.035)
// phase radians a second
QUAD_STRUGGLE_RATE :: f32(18)

// ---- dragging ----
// A body dragged along the ground.

// Pitch and roll of the fallen clip, measured so the head, ribs and forelegs share the ground instead of balancing on a low ear.
QUAD_DRAG_SETTLE := [Quad_Kind]Vec2{.Goat = {0.25, 0.3}, .Billy = {0.25, 0.25}, .Packfox = {-0.075, 0.275}}
QUAD_DRAG_HIP_PITCH :: f32(0.48)
QUAD_DRAG_HIP_ROLL :: f32(0.28)
QUAD_DRAG_HIP_PULL :: f32(0.08)
// grip height in fox radii before the hips lift more
QUAD_DRAG_HIGH_TAIL :: f32(1.5)
QUAD_DRAG_TAIL_LIFT :: f32(0.56)
QUAD_DRAG_REACH_MARGIN :: f32(0.995)

// ---- impacts ----
// What a blow does to an animal: by the speed it is knocked at, it is pushed, stumbles, falls or is launched, then tumbles, settles and gets up.

// Speed transferred to the animal, after its grip and mass have absorbed the blow.
IMPACT_STUMBLE_SPEED :: f32(0.9)
IMPACT_FALL_SPEED :: f32(2)
IMPACT_LAUNCH_SPEED :: f32(3)
IMPACT_MIN_PUSH :: f32(0.22)
IMPACT_MAX_RISE :: f32(6.5)
IMPACT_RISE_SHARE :: f32(0.55)
IMPACT_SPIN_PER_SPEED :: f32(1.1)
IMPACT_MAX_SPIN :: f32(7.5)
IMPACT_REBOUND_SPEED :: f32(6)
IMPACT_RESTITUTION :: f32(0.22)
IMPACT_LANDING_KEEP :: f32(0.72)
IMPACT_TUMBLE_TIME :: f32(0.42)
IMPACT_FALL_TIP_TIME :: f32(0.36)
IMPACT_SETTLE_TIME :: f32(0.48)
IMPACT_DOWN_TIME :: f32(0.55)
IMPACT_GET_UP_TIME :: f32(0.72)
IMPACT_TUMBLE_DRAG :: f32(5.5)
IMPACT_SLIDE_DRAG :: f32(1.3)
IMPACT_BRACE_DRAG :: f32(6.5)
IMPACT_SPIN_DRAG :: f32(8)
IMPACT_BRACE_TIME := #partial [Impact_Kind]f32{.Push = 0.33, .Stumble = 0.56}
IMPACT_BRACE_LEAN := #partial [Impact_Kind]f32{.Push = 0.11, .Stumble = 0.42}
IMPACT_BEND_TIME :: f32(0.32)
IMPACT_SIDE_ANGLE :: f32(1.44)
IMPACT_GROUND_BLEND_HEIGHT :: f32(0.75)
IMPACT_SIDE_BIAS :: f32(0.35)

// ---- impact_pose ----
// How a knocked animal's body and legs are drawn while it stumbles and falls.

IMPACT_QUAD_PIVOT :: f32(1.1)
IMPACT_TURKEY_PIVOT :: f32(1.18)
IMPACT_STEP_ANGLE :: f32(0.43)
IMPACT_HIND_TUCK :: f32(-0.7)
IMPACT_FRONT_TUCK :: f32(0.65)
IMPACT_LEG_SPLAY :: f32(0.24)

