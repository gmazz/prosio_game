# Prosio

Prosio is a small 2.5D top-view action game about a pig explorer whose weight is the whole game. Eating makes him fatter, exercise makes him leaner, and almost everything he can do depends on how heavy he is at that moment: how fast he runs, how high he jumps, what fits through a door, how far an enemy flies when he bumps it, and what he can pick up and throw.

It is written in [Odin](https://odin-lang.org) on top of [raylib](https://www.raylib.com), runs natively on the desktop and in the browser through WebAssembly, and is aimed at children of about seven.

This is a proof of concept: one meadow, five golden truffles to find, no story yet.

## Contents

- [Playing](#playing)
- [How weight works](#how-weight-works)
- [Moving, jumping and stamina](#moving-jumping-and-stamina)
- [Fighting](#fighting)
- [Grabbing and throwing](#grabbing-and-throwing)
- [The meadow and its puzzles](#the-meadow-and-its-puzzles)
- [Building](#building)
- [How the code is organised](#how-the-code-is-organised)
- [Testing without playing](#testing-without-playing)
- [Tuning](#tuning)
- [Known gaps](#known-gaps)

## Playing

The goal is to collect all five golden truffles. Each one sits behind a puzzle that needs Prosio to be the right weight, or to use his weight the right way.

### Controls

| Action | Keys |
|---|---|
| Move | `W` `A` `S` `D` or the arrow keys |
| Bump (belly charge) | `Space` |
| Jump | `J` or `X` |
| Sprint | hold `Shift` while moving |
| Grab; press again to throw | `F` or `L` |
| Bash with a held animal | `Space` |
| Eat (next to food) | `E` or `K` |
| Push-ups (anywhere else) | hold `E` or `K` |
| Pause menu | `Esc` or `P` |
| Try again after fainting | `Enter` or `R` |
| Pixel size | `1` (chunkiest) to `5` (finest), any time, or from the menus |
| Menus | up / down to choose, `Enter` or `Space` to select |

There is no gamepad or touch support yet.

### The screen

- **Weight bar** (top left): where Prosio is between 35 and 135 kg. Green is lean, yellow is chubby, orange is huge, and the red ends are danger zones. A yellow `+N` under the number is the weight of whatever he is carrying.
- **Stamina bar**: the notch shows what one bump costs right now. It turns red when he is out of breath.
- **Truffle count** (top right).
- **Prompt** (bottom): what `E` and `F` would do at this spot.

### Menus

The game opens on a main menu (Play, and Quit on the desktop). `Esc` pauses, with Resume, Restart and Exit to menu. Every new game starts from scratch; there is no saving.

## How weight works

Prosio weighs between **35 and 135 kg** and starts at 80 kg.

| Zone | Weight |
|---|---|
| Faints | 35 kg or less |
| Lean | under 65 kg |
| Chubby | 65 to 105 kg |
| Huge | 105 kg or more |
| Heart attack | 135 kg or more |

Fainting and the heart attack both end the attempt; `Enter` puts Prosio back at the start at 80 kg, and the meadow keeps its progress.

### Gaining and losing weight

| What | Change |
|---|---|
| Apple | +3 kg |
| Donut | +8 kg |
| Cake | +15 kg |
| One push-up | -2.5 kg |
| Walking | -0.05 kg per second |
| Sprinting | -0.2 kg per second |
| One bump or throw | -0.3 kg |
| One jump | -0.15 kg |

Food reappears about seven seconds after it is eaten, so no puzzle can be made impossible.

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
| Fits through | narrow gaps | wide ones only |

His body is drawn from simple shapes in code, so it changes smoothly with every kilogram: the belly grows out from under a cropped explorer jacket, and jiggles.

## Moving, jumping and stamina

- **Sprint** drains stamina (9 per second lean, 42 huge). At zero he is winded and cannot sprint again until 30 is back.
- **Jump** always uses the same leg energy, so the height is `36 / weight`. A lean Prosio clears small rocks and can hop over enemies; a huge one barely leaves the ground. Walls are 1.3 high, just above the best possible jump, so jumping never skips a puzzle.
- **Landing on an enemy** stuns it, and a hard enough landing throws it.
- **Stamina** is spent by sprinting, bumping, jumping, push-ups and lifting. It comes back on its own after a short pause, far faster when lean.

## Fighting

The enemies are woodland animals: red foxes (20 kg in game) and one wild boar (190 kg). Weight goes with volume: the boar is about 2.1 times the fox's size, so about 9.4 times as heavy. Both have big kawaii eyes, blushing cheeks and a little smile. Nothing dies; enemies that are knocked out see stars and vanish in a puff, and foxes come back later.

### Bump

A bump hits with Prosio's momentum, weight times speed. The enemy digs in and absorbs the first part of that (its *grip*); only the rest throws it:

```
launch speed = 0.479 x (Prosio's weight x his speed - enemy's grip) / enemy's weight
```

Measured against a fox (grip 600):

| Prosio | Fox leaves at | Result |
|---|---|---|
| 45 kg | 1.2 | Prosio bounces off |
| 60 kg | 5.5 | short hop, fox dizzy |
| 75 kg | 9.2 | flies, dizzy |
| 90 kg | 12.5 | knocked out |
| 105 kg | 15.3 | knocked out |
| 125 kg | 18.3 | knocked out, across the meadow |

The boar (grip 700, knocked out at 1.6) only gives way to a Prosio of about 120 kg or more. A bump out of a sprint keeps the extra speed, so it hits harder.

Flying enemies bounce off walls, sail over low ones, and bowl over any enemy they hit.

### Being shoved

An enemy that reaches Prosio shoves him at `31 x enemy's weight / Prosio's weight` (at most 12), takes 12 stamina and knocks a carried rock out of his hands (a tail he keeps hold of; mid-swing he cannot be pushed off course). After a shove he flashes warm gold and cannot be shoved again for 1.2 seconds. If his stamina reaches zero he is dizzy for under a second, then gets up with 30 stamina and three seconds of safety, so a crowd cannot pin him down.

## Grabbing and throwing

`F` grabs whatever is within about an arm's length (0.85) beyond touching. Nothing has to be held down: `F` again throws it.

- **Animals** are caught by the tail with one hoof and dragged along behind him as he walks.
  - **`Space`: bash with it.** He swings the animal like a club, roughly the way he is walking, and slams it into the ground in front of him and into anything standing there. Each swing goes a different way: over his head, round his side, or backhand across his front, landing somewhere ahead and a little to either side. Press `Space` again during a swing to queue the next one.
  - **`F`: throw it.** A quick wind-up over his head, and it flies off the way he is walking.
- **Rocks**, boulders included, are lifted overhead and held there. `F` again hurls them down in front of him, and they skim across the ground.

**A floppy body.** A held animal is not stiff. Its body is a short chain of three points (the tail tip in his hoof, the middle of its body, its shoulders) that swing, fall and slide on the ground under their own weight, and its back and front halves are drawn between them, so it bends in the middle. Its legs dangle with gravity and trail behind as it moves. While it is still fighting it stands on its feet and scrabbles to get away, with a sudden lunge every second or so; once it has been bashed it goes limp, with a few small pain stars round its head, and it is simply dragged along the grass.

**Dragging is a tug of war.** The tail is a rope. While it is taut, Prosio and the animal are pulled together, and each gives way by the *other's* share of their weight. An animal on its feet digs in (1.5 times its weight), a limp one slides (0.6 times), and Prosio digs his heels in too (1.5 times his). So a fox barely slows him down, while the 190 kg boar drags even a big Prosio about: he leans back with gritted teeth, his free arm flung out, heels ploughing the grass, and keeps facing it while he backs away.

**Only something lighter than 0.9 times his own weight can be swung or thrown.** That is any fox, but never the boar. With the boar, `Space` is a heave: he strains with all he has, lifts its rear a little, and it answers with a lunge. `F` just lets go. He can hang on until his stamina runs out or it pulls free.

Everything else scales with the *ratio* between the animal's weight and Prosio's:

| | Rule |
|---|---|
| Stamina to grab | 6 + 25 x ratio (at most 31) |
| Stamina drain while holding | 5 per second x ratio, a quarter of that once it is limp |
| A struggling animal pulls free after | 9 s / (ratio + 0.4): about 14 s for a fox, 3 to 5 s for the boar |
| Stamina per bash | 3 + 10 x ratio |
| How long a swing takes | 0.22 + 0.5 x ratio seconds: a heavier Prosio swings faster, so he hits harder |
| Throw speed | 3.2 x his weight / its weight (at most 22) |

**Bashing.** His hoof sweeps round from his shoulder, speeding up all the way like the crack of a whip, and drags the animal's body round on the end of its tail; its front half flops along after it. Hitting the ground hard is a slam (WHACK, THUD, SPLAT...): dust, a little shake, and the animal goes limper. Whatever it hits on the way takes `1.6 x its weight / (its + the other's weight)` of its speed, as when two balls collide: struck foxes fly off spinning and skip along, small rocks are batted away, and the boar only rocks on its feet. Trees and walls stop it with a BONK. Enough slams knock it out:

| Bashing a fox | 40 kg Prosio | 80 kg | 125 kg |
|---|---|---|---|
| Knocked out after | more than four bashes | about four | about two |
| Then thrown at | 6.4 | 12.8, knocked out | 20 |

A thrown animal is knocked out if it leaves at its knock-out speed (12 for a fox), or if it was knocked out already. It is spinning, so at every skip it keeps 82% of its forward speed, bounces back up with 55% of its falling speed, and the spin turns another 18% of the fall into forward speed. It knocks over any other animal it hits and bounces off walls, trees and rocks.

**Rocks** weigh `380 x radius cubed`: about 10 kg for a small one (radius 0.3), 82 kg at radius 0.6, and about 280 kg for the big boulders. A thrown rock skims while it is still moving faster than 3, bouncing back with 45% of its falling speed and keeping 80% of its forward speed. It knocks over animals in its path, passing on more of its speed the heavier it is, and comes to rest as an ordinary rock again.

| Throw | 45 kg Prosio | 80 kg | 125 kg |
|---|---|---|---|
| 16 kg rock | 7.4, travels about 6 m | 13.2, about 10.5 m | 20.6, about 16 m |
| 130 kg boulder | too heavy to lift (not enough stamina) | 1.6, drops 1 m in front | 2.5, drops 1.3 m in front |

- **A carried rock's weight is his.** It counts on the pressure plate, on both seesaws and when he lands, and it lowers his jump. A dragged animal stands on its own feet, so it does not count.
- He cannot bump, sprint, eat or do push-ups with his hands full, and cannot jump while holding a tail. He can bash on the move, at half speed.

## The meadow and its puzzles

The meadow is 88 by 60 units inside a fence, with the five sites spread out and trees, rocks, snacks and foxes scattered at random between them. Prosio starts at a picnic blanket near the middle. There is no map yet.

| Truffle | Where | What it takes |
|---|---|---|
| Skinny shack | north-west | The door is 1.2 wide. Prosio fits under about 68 kg. |
| Heavy vault | north-east | A pressure plate opens the gate under 105 kg or more, carried load included. |
| Boar | far north | Knock the boar out; it drops the truffle. |
| Crate | west | Smash a crate with the catapult's boulder (or a heavy thrown rock). |
| Cage | east | Tip the lever to open the gate. |

### The seesaws

Both are simulated as real levers: a plank with an angle and a turning speed.

- **Weight** on the plank pulls its side down with *weight times distance from the pivot*.
- **Landing** on the plank shares Prosio's momentum with it: *weight times falling speed times distance from the pivot*. Falling from higher means more speed, so both his weight and the height of the jump count.
- The plank is harder to get moving the more mass sits far from the pivot (*weight times distance squared*).
- An end that reaches the ground stops dead.

**The catapult.** Prosio's arm of the plank is short and the boulder's is long, so the boulder's end moves much faster than his. Climb the ramp, jump off the tower (the jump is aimed at the landing pad for you), and when his end hits the ground the 15 kg boulder leaves at the speed its end was moving.

| Prosio | Boulder flies |
|---|---|
| 45 kg | 1.8 |
| 70 kg | 4.1 |
| 88 kg | 5.5, onto the crate |
| 105 kg | 6.8 |
| 125 kg | 8.1 |

Too light falls short and too heavy overshoots; roughly 73 to 103 kg hits. A marker on the ground shows where the boulder would land at his current weight and turns green on the crate. The marker comes from the same formulas as the simulation and matched it to within about 3% in tests.

One liberty is taken: the boulder's flight is tilted about 50 degrees forward, as if by its cup. A real seesaw would throw it nearly straight up.

**The lever.** A 520 kg iron weight sits close to the pivot and Prosio's arm is long. Standing on the far end is never enough, at any weight. Jumping there adds the kick that tips it, from about 75 kg up.

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
    game.odin        the Game state, scenes (menu, playing, paused), the frame
                     loop and the camera
    world.odin       walls, platforms, food, scattering, and collide_static,
                     which keeps anything round out of everything solid
    prosio.odin      Prosio: weight, movement, jump, sprint, stamina
    enemies.odin     enemies, bumps, shoves and stomps
    grab.odin        grabbing, dragging, bashing, throwing, the floppy held
                     animal, rocks in flight
    seesaw.odin      the lever physics, catapult and boulder
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
- **Pixel art from 3D.** The scene is lit with three flat tones and a limited palette, with dithered ground and one-pixel outlines, and drawn into a small image that is enlarged without smoothing. There are five pixel sizes (keys `1` to `5`), aiming at about 180, 240, 320 (the default), 420 and 560 rows of pixels. Each game pixel is a whole number of real screen pixels, so the actual count is the nearest that fits the window, and each level is kept at least one step finer than the one below it as far as the window allows (on a small window the finest levels can end up the same). The camera is snapped to whole pixels so scenery does not shimmer as it scrolls, and the image is shifted by less than a pixel to keep scrolling smooth.
- **Surface detail is calculated, not painted:** grass tones and the footpath, leaf clumps, bark grain and moss are all noise in the shader. Leaves sway in the wind.
- **Trees** are a trunk plus clusters of round leafy lumps, in three species (broadleaf, blossom, pine). A tree standing between the camera and Prosio fades to a see-through pattern where it covers him.
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
| `--crowd` | put three foxes and a boar round Prosio at the start, for trying the club |
| `--detail 3` | pixel size: 1 chunkiest to 5 finest (default 3) |

Button letters: `l r u d` to move, `b` bump, `j` jump, `s` sprint, `a` eat or push-ups, `g` grab or throw.

For example, Prosio grabs a fox from the crowd on frame 12, walks off dragging it, bashes on frame 50, and the picture is taken mid-swing:

```bash
./build/desktop/prosio --crowd --tap g --tap-at 12 --hold d --tap2 b --tap2-at 50 --shot bash.png --frame 62
```

## Tuning

Every number that shapes the feel is a named constant or a one-line function near the top of its file:

| To change | Look in |
|---|---|
| Weight limits and zones, food and exercise amounts | `prosio.odin`, `world.odin` (`FOOD_KG`) |
| Speeds, sprint, stamina costs and recovery, jump energy | `prosio.odin` (`walk_speed`, `dash_cost`, `JUMP_ENERGY`, ...) |
| How hard bumps and shoves are, enemy weights and grips | `enemies.odin` |
| Throw and bash strength, lift limit, dragging grip, how fast animals go limp, rock weight | `grab.odin` |
| Seesaw sizes and weights, where the crate stands | `seesaw.odin` |
| World size, door width, plate weight | `world.odin` |
| Colours | `draw.odin`, `ui.odin` |
| Keys | `KEYS` in `platform.odin` |

## Known gaps

- No sound or music.
- No saving, and a single meadow.
- No map or pointer to the truffle sites.
- No gamepad or touch controls.
- Linux and Windows builds are untested.
- Text uses raylib's built-in pixel font.
- The game has been checked mostly through scripted runs and screenshots; balance and feel still need real play.
- The story is deliberately not written yet.
