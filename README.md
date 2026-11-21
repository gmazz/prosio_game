# Prosio

Prosio is a small 2.5D top-view action game about a pig explorer whose weight is the whole game. He roams a big meadow gathering food into his sack and bakes it into pies at his oven. Everything he does burns a little weight and everything he eats puts some back, and almost everything he can do depends on how heavy he is at that moment: how fast he runs, how high he jumps, how far an enemy flies when he bumps it, and what he can pick up and throw.

It is written in [Odin](https://odin-lang.org) on top of [raylib](https://www.raylib.com), runs natively on the desktop and in the browser through WebAssembly, and is aimed at children of about seven.

This is a proof of concept: one meadow, no goal yet beyond keeping Prosio fed and healthy.

## Contents

- [Playing](#playing)
- [How weight works](#how-weight-works)
- [The sack and the oven](#the-sack-and-the-oven)
- [Moving, jumping and stamina](#moving-jumping-and-stamina)
- [Fighting](#fighting)
- [Grabbing and throwing](#grabbing-and-throwing)
- [The meadow](#the-meadow)
- [Building](#building)
- [How the code is organised](#how-the-code-is-organised)
- [Testing without playing](#testing-without-playing)
- [Tuning](#tuning)
- [Known gaps](#known-gaps)

## Playing

Keep Prosio's energy in balance. Walking, picking things up, fighting and being pecked or butted all burn a little of his weight; food puts it back, but slowly, so he has to keep going out to gather it. Each kind of food grows in its own part of the meadow, so he has to know where to look, and the best food is what he bakes from it.

### Controls

| Action | Keys |
|---|---|
| Move | `W` `A` `S` `D` or the arrow keys |
| Bump (belly charge) | `Space` |
| Jump | `J` or `X` |
| Sprint | hold `Shift` while moving |
| Grab; press again to throw | `F` or `L` |
| Bash with a held animal | `Space` |
| Pick up food into the sack (next to food or a berry bush) | `E` or `K` |
| Use the oven (next to it) | `E` or `K` |
| Choose in the sack | `Z` (back) and `C` (on) |
| Eat what is chosen in the sack | `Q` |
| Pause menu | `Esc` or `P` |
| Try again after fainting | `Enter` or `R` |
| Pixel size | `1` (chunkiest) to `6` (finest), any time, or from the menus |
| Menus | up / down to choose, `Enter` or `Space` to select |

There is no gamepad or touch support yet.

### The screen

- **Weight bar** (top left): where Prosio is between 35 and 135 kg. Green is lean, yellow is chubby, orange is huge, and the red ends are danger zones. A yellow `+N` under the number is the weight of a rock he is carrying.
- **Stamina bar**: the notch shows what one bump costs right now. It turns red when he is out of breath.
- **Sack** (top, beside the weight): a box for each kind of thing in the sack, with its picture, and how many under the box. The chosen one is outlined in yellow, with its name and calories above. The panel is always wide enough for the longest name. It grows as new kinds go in, up to six boxes; with more than six, the boxes go round in a circle as `Z` and `C` choose (the chosen one always third, with `<` and `>` either side).
- **Where he is** (top right): the part of the meadow he is in, and what is found there.
- **Prompt** (bottom): what `E` and `F` would do at this spot.

### Menus

The game opens on a main menu (Play, and Quit on the desktop). `Esc` pauses, with Resume, Restart and Exit to menu. The oven's menu also pauses the game. Every new game starts from scratch; there is no saving.

## How weight works

Prosio weighs between **35 and 135 kg** and starts at 80 kg.

| Zone | Weight |
|---|---|
| Faints | 35 kg or less |
| Lean | under 65 kg |
| Chubby | 65 to 105 kg |
| Huge | 105 kg or more |
| Heart attack | 135 kg or more |

Fainting and the heart attack both end the attempt; `Enter` puts Prosio back at home at 80 kg, and the meadow stays as it was. So does his sack.

### Gaining and losing weight

Whatever he eats from his sack puts on weight by its calories, slowly: **1 kg for every 200 kcal** (see [The sack and the oven](#the-sack-and-the-oven) for each food). Everything he does burns some, from very little for walking to more for fighting and most for being hurt. There is no exercise to do: keeping busy is enough.

| What | Change |
|---|---|
| Walking | -0.02 kg per second (about 1.2 kg a minute), times his weight / 80 kg |
| Sprinting | -0.06 kg per second, times his weight / 80 kg |
| Picking something up | -0.08 kg |
| One jump | -0.06 kg |
| One bump, grab, bash or throw | -0.2 kg |
| Being pecked or butted | -0.35 kg |

So a bunch of berries (+0.25 kg) is worth picking but not by much, an apple (+0.47 kg) is better, and a pie (+4 to +6 kg) is best of all. Ten seconds in the middle of an angry flock of turkeys can cost him 2 kg.

## The sack and the oven

Food is not eaten where it is found. `E` next to it and Prosio stoops, picks it up and drops it over his shoulder into the sack on his back (up to nine of each thing). He eats from the sack when he likes: `Z` and `C` choose, `Q` eats.

Each kind of food grows in its own part of the meadow (see [The meadow](#the-meadow)):

- **The forest:** berry bushes, wild apple trees and mushrooms. Bushes grow a new bunch of berries every 9 seconds, up to three. Apple trees grow up to four apples, and now and then one drops; a fallen apple rots away after 45 seconds. **Bump an apple tree** (or slam an animal or throw one into it) and it shakes, and down come some of its apples: the harder the hit, the more. Mushrooms grow in the shade under the trees and come back 25 seconds after being picked.
- **The wheat fields:** wheat, in rows in four ploughed fields; it grows back after 30 seconds.
- **The pumpkin patch:** pumpkins, in three beds; they grow back after 40 seconds and are big enough to bump into.
- **Eggs** come from the turkeys. Each turkey lays one now and then (every 100 to 220 seconds), wherever it is, mostly in Turkey Meadow; an egg lies there for 90 seconds, and no more than ten lie about at once. A turkey held by the legs and shaken with `Space` lets an egg drop one time in five.

Nothing runs out for good.

| Raw food | kcal | Weight |
|---|---|---|
| Bunch of berries | 50 | +0.25 kg |
| Apple | 95 | +0.47 kg |
| Mushroom | 30 | +0.15 kg |
| Pumpkin | 400 | +2.0 kg |
| Wheat (a sheaf, about a cup of flour) | 340 | +1.7 kg |
| Egg | 130 | +0.65 kg |

**The oven** stands at home, by the start: a round brick oven with a chimney. `E` next to it opens its menu (the game waits meanwhile): every recipe, what it needs and what is in the sack, and its calories. `Up`/`Down` choose, `E` or `Enter` bakes, `Esc` closes. Baking takes 6 seconds, with a fire in the oven and smoke from the chimney; then it says "Ding!", and the dish waits in the oven's mouth, where you can see what it is, until Prosio takes it out with `E`, into the sack.

Cooking makes more of the calories in food available to the body, so **a baked dish counts 1.4 times the calories of what went into it**:

| Dish | Needs | Raw | Baked | Weight |
|---|---|---|---|---|
| Apple pie | 3 apples, 1 wheat, 1 egg | 755 | 1057 kcal | +5.3 kg |
| Pumpkin pie | 1 pumpkin, 1 wheat, 1 egg | 870 | 1218 kcal | +6.1 kg |
| Berry muffins | 3 bunches of berries, 1 wheat, 1 egg | 620 | 868 kcal | +4.3 kg |
| Mushroom pie | 3 mushrooms, 1 wheat, 1 egg | 560 | 784 kcal | +3.9 kg |
| Bread | 2 wheat | 680 | 952 kcal | +4.8 kg |

So a trip to the forest, the fields and Turkey Meadow for an apple pie is worth more than eating everything raw on the way.

### What weight changes

Neither end is the "good" one. Each is a tool.

| | Lean | Huge |
|---|---|---|
| Body radius | 0.42 at 35 kg | 0.97 at 135 kg |
| Walking speed | fast (7.2 at 35 kg) | slow (2.6 at 135 kg) |
| Sprint | 1.7 times walking | 1.25 times walking |
| Jump height | high (0.9 at 40 kg) | low (0.3 at 120 kg) |
| Stamina recovery | 50 per second | 8 per second |
| Cost of a bump | 9 stamina | 42 stamina |
| Bump | bounces off enemies | sends them flying |
| Being shoved | flies far | hardly moves |
| Throw | weak | strong |

His body is drawn from simple shapes in code, so it changes smoothly with every kilogram: the belly grows out from under a cropped explorer jacket, and jiggles.

## Moving, jumping and stamina

- **Sprint** drains stamina (9 per second lean, 42 huge). At zero he is winded and cannot sprint again until 30 is back.
- **Jump** always uses the same leg energy, so the height is `36 / weight`. A lean Prosio clears small rocks and can hop over enemies; a huge one barely leaves the ground.
- **Landing on an enemy** stuns it, and a hard enough landing throws it.
- **Stamina** is spent by sprinting, bumping, jumping and lifting. It comes back on its own after a short pause, far faster when lean.

## Fighting

The enemies are farm animals gone bad-tempered: big turkeys (16 kg) all over the meadow, and in the far north a few goats (55 kg) led by a billy goat (95 kg, more than Prosio at the start). They have big kawaii eyes. A cross turkey spreads its barred tail fan and frowns; the billy goat is brown, with a shaggy mane, a long beard and great curling horns. Nothing dies; enemies that are knocked out see stars and vanish in a puff, and all but the billy goat come back later.

**Turkeys hunt like a pack.** The turkeys near Prosio do not run at him in a bunch. Like wolves round their prey, they spread out round him at about three metres, each taking its own place in the order they already stand (so their paths do not cross), with the places drifting round to his back. From time to time one darts in on a curve, flapping, leading him a little: more likely from behind (55% at each try), less from the side (25%) and rarely from in front (6%), and never more than two at once. After a peck, or a miss, it falls back and circles again. Turkeys go round obstacles they bump into, and if one finds itself wedged in a dead end it turns back and tries the other way. When Prosio stands up on the tower they run round to the foot of the ramp and climb it; up there they go straight for him.

**Goats butt.** They graze about their patch, and when Prosio comes within about 8 metres they square up to him a few steps off, facing him, then lower their heads and charge in a straight line at where he was (so he can step aside), and back off again.

### Bump

A bump hits with Prosio's momentum, weight times speed. The enemy digs in and absorbs the first part of that (its *grip*); only the rest throws it:

```
launch speed = 0.479 x (Prosio's weight x his speed - enemy's grip) / enemy's weight
```

Measured against a turkey (grip 560, knocked out at 15):

| Prosio | Turkey leaves at | Result |
|---|---|---|
| 45 kg | 2.8 | Prosio bounces off |
| 60 kg | 8.1 | flies, dizzy |
| 75 kg | 12.9 | flies, dizzy |
| 90 kg | 17.0 | knocked out |
| 105 kg | 20.5 | knocked out |
| 125 kg | 24.2 | knocked out, across the meadow |

A goat (grip 450, knocked out at 6) is knocked out by a Prosio of about 95 kg. The billy goat (grip 500, knocked out at 4) only gives way to one of about 115 kg or more. A bump out of a sprint keeps the extra speed, so it hits harder.

Flying enemies bounce off walls, sail over low ones, and bowl over any enemy they hit.

### Being shoved

An enemy that reaches Prosio shoves him at `31 x enemy's weight / Prosio's weight` (at most 12), takes 12 stamina and knocks a carried rock out of his hands (a held animal he keeps hold of; mid-swing he cannot be pushed off course). After a shove he flashes warm gold and cannot be shoved again for 1.2 seconds. If his stamina reaches zero he is dizzy for under a second, then gets up with 30 stamina and three seconds of safety, so a crowd cannot pin him down.

## Grabbing and throwing

`F` grabs whatever is within about an arm's length (0.85) beyond touching. Nothing has to be held down: `F` again throws it.

- **Animals** are caught by the legs with one hoof. A turkey is held up by both feet, out to his side, and dangles head down, flapping madly (every beat of its wings jerks it about). A goat is caught by a hind leg and dragged along behind him as he walks.
  - **`Space`: bash with it.** He swings the animal like a club, roughly the way he is walking, and slams it into the ground in front of him and into anything standing there. Each swing goes a different way: over his head, round his side, or backhand across his front, landing somewhere ahead and a little to either side. Press `Space` again during a swing to queue the next one.
  - **`F`: throw it.** A quick wind-up over his head, and it flies off the way he is walking.
- **Rocks**, boulders included, are lifted overhead and held there. `F` again hurls them down in front of him, and they skim across the ground.

**A floppy body.** A held animal is not stiff. Its body is a short chain of three points (the feet in his hoof, the middle of its body, its shoulders) that swing, fall and slide on the ground under their own weight, and its back and front halves are drawn between them, so it bends in the middle. Its legs dangle with gravity and trail behind as it moves. While it is still fighting it stands on its feet and scrabbles to get away, with a sudden lunge every second or so; once it has been bashed it goes limp, with a few small pain stars round its head, and it is simply dragged along the grass.

**Dragging is a tug of war.** The held leg is a rope. While it is taut, Prosio and the animal are pulled together, and each gives way by the *other's* share of their weight. An animal on its feet digs in (1.5 times its weight), a limp one slides (0.6 times), and Prosio digs his heels in too (1.5 times his). So a turkey barely slows him down, while the 95 kg billy goat drags an ordinary Prosio about: he leans back with gritted teeth, his free arm flung out, heels ploughing the grass, and keeps facing it while he backs away.

**Only something lighter than 0.9 times his own weight can be swung or thrown.** That is any turkey, a goat from about 61 kg, and the billy goat only from about 106 kg. With something too heavy, `Space` is a heave: he strains with all he has, lifts its rear a little, and it answers with a lunge. `F` just lets go. He can hang on until his stamina runs out or it pulls free.

Everything else scales with the *ratio* between the animal's weight and Prosio's:

| | Rule |
|---|---|
| Stamina to grab | 6 + 25 x ratio (at most 31) |
| Stamina drain while holding | 5 per second x ratio, a quarter of that once it is limp |
| A struggling animal pulls free after | 9 s / (ratio + 0.4): about 15 s for a turkey, 6 to 7 s for the billy goat |
| Stamina per bash | 3 + 10 x ratio |
| How long a swing takes | 0.22 + 0.5 x ratio seconds: a heavier Prosio swings faster, so he hits harder |
| Throw speed | 3.2 x his weight / its weight (at most 22) |

**Bashing.** Each press of `Space` is one swing of a pendulum across his front: from the side the animal is on, round past his front, out to the other side, fastest in the middle. Press again and it swings back. Each swing differs a little: how far out it goes, how high, and how deep it dips in the middle (a deep dip slams it into the ground in front of him). His hoof leads and the animal's body follows on the end of its leg, its front half flopping after it. Hitting the ground hard is a slam (WHACK, THUD, SPLAT...): dust, a little shake, and the animal goes limper.

**The club is floppy.** Whatever it hits is struck as in a collision of two balls, but only part of the swung animal's body is behind the blow (0.6 of its weight, `m'`), and it squashes rather than bounces (restitution `e` = 0.35):

```
struck animal flies off at   (1 + e) x m' / (m' + its weight) x club speed
the club carries on at       (m' - e x its weight) / (m' + its weight) x club speed
```

So a turkey swung into a turkey knocks it at about half the club's speed, mostly sideways (tumbled over, not launched), and swung into the billy goat it only rocks it and bounces back. Small rocks are batted away the same way. Trees and walls stop it with a BONK, and shake the tree. Enough slams knock it out:

| Bashing a turkey | 40 kg Prosio | 80 kg | 125 kg |
|---|---|---|---|
| Knocked out after | many bashes | a handful of bashes | fewer |
| Then thrown at | 8 | 16, knocked out | 22 |

A thrown animal is knocked out if it leaves at its knock-out speed (14 for a turkey, 5.5 for a goat, 3.5 for the billy goat), or if it was knocked out already. It is spinning, so at every skip it keeps 82% of its forward speed, bounces back up with 55% of its falling speed, and the spin turns another 18% of the fall into forward speed. It knocks over any other animal it hits and bounces off walls, trees and rocks.

**Rocks** weigh `380 x radius cubed`: about 10 kg for a small one (radius 0.3), 82 kg at radius 0.6, and about 280 kg for the big boulders. A thrown rock skims while it is still moving faster than 3, bouncing back with 45% of its falling speed and keeping 80% of its forward speed. It knocks over animals in its path, passing on more of its speed the heavier it is, and comes to rest as an ordinary rock again.

| Throw | 45 kg Prosio | 80 kg | 125 kg |
|---|---|---|---|
| 16 kg rock | 7.4, travels about 6 m | 13.2, about 10.5 m | 20.6, about 16 m |
| 130 kg boulder | too heavy to lift (not enough stamina) | 1.6, drops 1 m in front | 2.5, drops 1.3 m in front |

- **A carried rock's weight is his.** It counts when he lands, and it lowers his jump and his speed. A dragged animal stands on its own feet, so it does not count.
- He cannot bump, sprint, eat or pick things up with his hands full, and cannot jump while holding an animal. He can bash on the move, at half speed.

## The meadow

The meadow is 200 by 140 metres inside a fence, more than five times as big as before. Prosio's home is in the middle: a bare yard with the oven, and footpaths winding out from it to each part of the meadow, with a signpost by the yard pointing down each path. Each part has its own food, its own look on the ground, and its name in the top right corner while he is in it.

| Where | Which way from home | What is there |
|---|---|---|
| The forest | west | About 230 trees close together on a darker floor strewn with leaves: berry bushes, wild apple trees and mushrooms |
| The wheat fields | south-east | Four ploughed fields of wheat in rows, and a few shady trees |
| The pumpkin patch | south | Three beds of pumpkins |
| Turkey Meadow | north | Open grass, most of the 22 turkeys, and their eggs |
| Goat hills | north-east | Dry, stony ground with big rocks and pines, the goats and the billy goat |

In between is open meadow with lone trees and rocks, but no food, and a few turkeys wandering about. Animals far from Prosio rest until he comes near.

## Building

### What you need

| For | Tool | Notes |
|---|---|---|
| Any build | Odin | Developed with `dev-2026-11`. On a Mac: `brew install odin`, which also installs raylib 6.2. |
| Web build | Emscripten | `brew install emscripten` (developed with 7.0.0). |
| Web build | `lib/libraylib.web.a` | raylib compiled for the web. Homebrew's Odin leaves it out, so it is kept in this project. It comes from the Odin repository, `vendor/raylib/wasm/libraylib.web.a`, at the commit matching the compiler. |
| Web preview | Python 3 | Only for a local web server. |

### Desktop

```bash
./build_desktop.sh
```

```bash
./build/desktop/prosio
```

The script has only been run on an Apple-silicon Mac. Odin's raylib bindings also cover Linux and Windows, but those builds have not been tried, and each has to be built on its own system.

### Web

```bash
./build_web.sh
```

```bash
python3 -m http.server 8765 --directory build/web
```

Then open `http://localhost:8765` and click the game once so it has the keyboard. There are no image files: everything is drawn in code.

Two things in the web build are worth knowing if you change it:

- `-sDECLARE_ASM_MODULE_EXPORTS=0` stops Emscripten renaming the functions that Odin's runtime needs from the page.
- The web build never asks raylib whether the window should close, because that call stalls a browser page.

## How the code is organised

Everything is built in code from simple shapes; the game loads no image files.

```
src/
  game/              the game itself
    platform.odin    the only file that calls raylib: window, input, shapes,
                     shaders, outlines, text
    shaders/         the scene shader: pixel shading, ground, leaves, bark, stone,
                     fabric, shadows, wind and the see-through fade
    game.odin        the Game state, scenes (menu, playing, paused, oven),
                     the frame loop and the camera
    world.odin       the regions, fields and paths, food, laying out the
                     meadow, and collide_static, which keeps anything round
                     out of everything solid
    prosio.odin      Prosio: weight and what burns it, movement, jump,
                     sprint, stamina
    kitchen.odin     the sack, calories, recipes, the oven, and their menus and
                     pixel icons
    enemies.odin     turkeys and goats, bumps, shoves and stomps
    grab.odin        grabbing, dragging, bashing, throwing, the floppy held
                     animal, rocks in flight
    draw.odin        everything drawn in the world
    ui.odin          bars, prompts, speech bubbles, menus
    util.odin        small maths helpers and a random number generator
  main_desktop/      entry point for desktop, plus the testing options
  main_web/          entry point and page for the browser
build_desktop.sh
build_web.sh
lib/                 raylib compiled for the web
```

A few choices shape the rest:

- **One file touches raylib.** The game draws with a few primitive meshes (sphere, hemisphere, cube, cylinder, cone, torus, planes, and a tapered cylinder built at start-up for limbs) placed by matrices, and asks about a dozen named buttons.
- **Bodies** are built from those shapes. Arms and legs are tapered segments (thigh, shin, upper arm, forearm) that narrow towards the hooves, with round joints between; Prosio's shorts sit high over two small buttocks, so his legs show below them, and his arms are plump with a round biceps. He is built short and stocky: short legs, a compact body and a big head. When he eats, it is his belly that grows, forwards and sideways; his bottom hardly changes. Swapping raylib for another library would mean rewriting `platform.odin` only.
- **No memory allocation in the game.** Everything lives in one `Game` struct of fixed-size arrays, which is also why the web build needs no allocator.
- **Physics on the ground plane, plus height.** Positions are 2D; things that jump or fly also have a height and a vertical speed. Physics runs in fixed steps of at most 1/120 of a second.
- **Pixel art from 3D.** The scene is lit by a warm, low sun in four flat tones (deep shade, shade, light and a sunlit highlight, with dithered edges between them): cool violet shadows, warm highlights, a touch of blue skylight on anything facing up, darkening where things meet the ground, and broad soft patches of sunlight on the grass. A limited palette, dithered ground and one-pixel outlines finish it. Everything is drawn into a small image that is enlarged without smoothing. There are six pixel sizes (keys `1` to `6`), aiming at about 180, 240, 320, 360 (the default), 420 and 560 rows of pixels. Each game pixel is a whole number of real screen pixels (on a high-resolution screen it can also be a whole number and a half, which is what makes room for the level between 320 and 420), so the actual count is the nearest that fits the window, and each level is kept at least one step finer than the one below it as far as the window allows (on a small window the finest levels can end up the same). The camera is snapped to whole pixels so scenery does not shimmer as it scrolls, and the image is shifted by less than a pixel to keep scrolling smooth.
- **Surface detail is calculated, not painted:** grass tones, the forest floor, the stony hills, the paths and the ploughed fields, leaf clumps, bark grain and moss are all noise in the shader. Where the fields, paths and regions are is passed to the shader once, at start-up. Leaves sway in the wind.
- **Shadows are cast, not stamped.** Everything that stands in the sun is first drawn flattened onto the ground along the sunlight, in grey, into an image of its own; the ground is then drawn and that image multiplied over it, and everything else drawn on top. So every shadow has the shape of what casts it (a tree's trunk as well as its crown, a signpost's arm, Prosio mid-jump), falls the same way as the light, and is simply a darker version of whatever it lands on: grass, path, soil or forest floor. Where shadows overlap they are no darker than one.
- **Trees** are tall and slim: a trunk plus clusters of round leafy lumps that are darker underneath, in four species (broadleaf, apple, blossom, pine). A tree standing between the camera and Prosio fades to a see-through pattern where it covers him; its shadow stays whole.
- **Only what is near the camera is drawn.**

## Testing without playing

The desktop build takes options that script a run, save a picture and quit. They ignore the real keyboard and use a fixed time step, so a run is repeatable.

| Option | Meaning |
|---|---|
| `--kg 120` | start at this weight |
| `--pos -24 -8.5` | start at this place |
| `--hold ub` | hold buttons from frame 10 |
| `--tap j` | press buttons once on frame 10 |
| `--tap-at 60` | press the `--tap` buttons on this frame instead |
| `--tap2 g --tap2-at 90` | a second set of buttons, on its own frame |
| `--release-at 90` | let go of the `--hold` buttons on this frame |
| `--shot name.png` | save a picture, then quit |
| `--frame 150` | which frame to take the picture on |
| `--menu` | show the menu instead of starting the game |
| `--crowd` | put turkeys, a goat and the billy goat round Prosio at the start, the first turkey within reach, for trying the club |
| `--stock` | start with a sack full of food (three of each raw thing, one of each dish) |
| `--detail 4` | pixel size: 1 chunkiest to 6 finest (default 4) |

Button letters: `l r u d` to move, `b` bump, `j` jump, `s` sprint, `a` pick up or oven, `g` grab or throw, `q` eat from the sack, `z` `c` choose in the sack, `e` enter.

For example, Prosio grabs a turkey from the crowd on frame 12, walks off dragging it, bashes on frame 50, and the picture is taken mid-swing:

```bash
./build/desktop/prosio --crowd --tap g --tap-at 12 --hold d --tap2 b --tap2-at 50 --shot bash.png --frame 62
```

## Tuning

Every number that shapes the feel is a named constant or a one-line function near the top of its file:

| To change | Look in |
|---|---|
| Weight limits and zones, exercise amounts | `prosio.odin` |
| Calories, recipes, the cooking bonus, sack size, baking time | `kitchen.odin` (`RAW_KCAL`, `RECIPES`, `COOK_BONUS`, `KCAL_PER_KG`) |
| Where food grows and how fast it comes back | `world.odin` (`FOOD_RESPAWN`, `build_world`) |
| Speeds, sprint, stamina costs and recovery, jump energy | `prosio.odin` (`walk_speed`, `dash_cost`, `JUMP_ENERGY`, ...) |
| How hard bumps and shoves are, enemy weights and grips | `enemies.odin` |
| Throw and bash strength, lift limit, dragging grip, how fast animals go limp, rock weight | `grab.odin` |
| World size, regions, fields, paths, how many trees and rocks | `world.odin` (`WORLD_HALF`, `REGIONS`, `PATH_ENDS`, `build_world`) |
| How often turkeys lay, the chance of a shaken-out egg | `enemies.odin` (`EGG_EVERY`, `SHAKE_EGG`) |
| What everything burns | `prosio.odin` (`WALK_BURN`, `GATHER_BURN`, `FIGHT_BURN`, `HURT_BURN`, ...) |
| The sun's direction and how dark shadows are | `platform.odin` (`SUN`, `SHADOW_INK`) and `scene.frag` |
| Colours | `draw.odin`, `ui.odin` |
| Keys | `KEYS` in `platform.odin` |

## Known gaps

- No sound or music.
- No saving, and a single meadow.
- No map; only the signposts by the house and the name of the region he is in.
- No goal beyond keeping Prosio healthy; the puzzles of earlier versions are gone for now.
- No gamepad or touch controls.
- Linux and Windows builds are untested.
- Text uses raylib's built-in pixel font.
- The game has been checked mostly through scripted runs and screenshots; balance and feel still need real play.
- The story is deliberately not written yet.
