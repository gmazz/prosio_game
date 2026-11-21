# Prosio

Prosio is a small 2.5D top-view action game about a pig explorer whose weight is the whole game. He roams a big meadow gathering food into his sack and bakes it into pies at his oven. Everything he does burns a little weight and everything he eats puts some back, and almost everything he can do depends on how heavy he is at that moment: how fast he runs, how high he jumps, how far an enemy flies when he bumps it, and what he can pick up and throw.

It is written in [Odin](https://odin-lang.org) on top of [raylib](https://www.raylib.com), runs natively on the desktop and in the browser through WebAssembly, and is aimed at children of about seven.

This is a proof of concept: one meadow, no goal yet beyond keeping Prosio fed and healthy.

## Contents

- [Playing](#playing)
- [How weight works](#how-weight-works)
- [Body and skills](#body-and-skills)
- [The sack and the oven](#the-sack-and-the-oven)
- [Nutrients and water](#nutrients-and-water)
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

Keep Prosio's energy in balance. Walking, picking things up, fighting and being pecked or butted all burn a little of his weight; food puts it back, but slowly, so he has to keep going out to gather it. Each kind of food grows in its own part of the meadow, so he has to know where to look, and the best food is what he bakes, cooks or churns from it, each in its own place. Calories are not everything: he also needs six nutrients and water, so he has to eat a bit of everything, and drink at the pond. And Prosio becomes what he does: what he keeps doing builds his muscles and his skills, and what he stops doing fades. He is saved as you play, so he is the same pig next time.

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
| Use the oven, the fire, the churn or the mill, or drink at the pond (next to it) | `E` or `K` |
| Grab a fish (on the bank of the pond, with one close) | `F` or `L` |
| Milk a held goat; chop a held body into meat (at the fire) | `E` or `K` |
| Choose in the sack | `Z` (back) and `C` (on) |
| Eat what is chosen in the sack | `Q` |
| Sack, body, outfit and map menu | `M` |
| Let his wind go (once his gut is trained) | `G` or `V` |
| Pause menu | `Esc` or `P` |
| Wake up at home after the game is over | `Enter` or `R` |
| Pixel size | `1` (chunkiest) to `6` (finest), any time, or from the menus |
| Menus | up / down to choose, `Enter` or `Space` to select |

There is no gamepad or touch support yet.

### The screen

- **What he is made of** (top left): one panel. At the top, what he weighs and a bar of that weight made of its parts laid end to end, each in its own colour. Under it one row for each part, with a square of the same colour, a bar, **its kilograms**, and what it is doing to him: fat, muscle, carbs, protein, fibre and water. What he weighs is always exactly the sum of those rows and his bones (see [How weight works](#how-weight-works)). Then the two things he needs that weigh nothing, vitamins and electrolytes; his **stamina** (the notch shows what one bump costs right now; it turns red when he is out of breath); and, when he lacks something, a line saying what to eat. A yellow `+N` beside his weight is a rock he is carrying.
- **Sack** (top, beside the weight): a box for each kind of thing in the sack, with its picture, and how many under the box. The chosen one is outlined in yellow, with its name and calories above. The panel is always wide enough for the longest name. It grows as new kinds go in, up to six boxes; with more than six, the boxes go round in a circle as `Z` and `C` choose (the chosen one always third, with `<` and `>` either side).
- **Where he is** (top right): the part of the meadow he is in, and what is found there.
- **Prompt** (bottom): what `E` and `F` would do at this spot.

### Menus

The game opens on a main menu (Play, and Quit on the desktop). `Esc` pauses, with Resume, Start over and Exit to menu.

**Saving.** Prosio is saved every 15 seconds of play, when the game is paused and when it goes back to the menu: his fat, muscles and skills, his nutrient levels, his sack, his outfit and what he has uncovered of the map. On the desktop this is the file `prosio.sav` beside the program; in the browser it is kept in the browser's own storage for the page. With a saved Prosio the main menu says Continue instead of Play, and has Start over, which begins again with a new pig. The meadow itself starts afresh each sitting: food, animals and what is in the oven are not saved.

 The menus of the oven, the fire and the churn, and the sack, outfit and map menu, also pause the game.

**The sack, body, outfit and map menu** (`M`) has four panels; `Z` and `C` switch between them, `M` or `Esc` closes it.

- **Sack:** everything that can be in the sack, gathered or baked, in a grid: its picture, how many (greyed out when none), and for the chosen one its name, calories and how much weight it puts on. The arrows choose, `E` or `Enter` eats.
- **Body:** what he weighs as the sum of his parts (the same bar, with each part's kilograms), then his arms, his legs and his five skills, each with a bar, whether it is growing or fading, what makes it grow and what it is good for (see [Body and skills](#body-and-skills)).
- **Outfit:** what Prosio wears, one choice in each row; up and down choose a row, left and right change it. The camera comes in close, with Prosio to the right of the menu, slowly turning round so you can see it all. What he wears stays the same in a new game.

Under his clothes Prosio is a whole bare pig, shoulders and all. Clothes go on in layers, each a little bigger than what is under it, so nothing underneath ever pokes through: skin, then what is on his legs and his shirt, then whatever he wears over the shirt. A closed coat covers him front and back down past his hips; an open jacket shows the shirt (or the pig) in the gap down its front.

The first row puts on a whole outfit at once; every other row changes one piece, and any piece goes with any other.

| Whole outfit | What it is |
|---|---|
| Explorer | the one he starts in: headband, kerchief, explorer jacket, shorts, bare hooves |
| Metalhead | long black hair, rings in ears and nose, a black band T-shirt with TOOL across the chest, an open black leather jacket, black leather trousers, tall black boots |
| 80s computer kid | bowl cut, big square glasses, bow tie, a cream T-shirt with C64 and a rainbow, brown cords, white sneakers |
| Black turtleneck | short grey hair, round glasses, grey stubble, black turtleneck, jeans, grey trainers |
| Aviator | leather flying cap with goggles, sunglasses, moustache, white scarf, white shirt, belted trench coat, cords, brown boots |
| Space pirate | long shaggy hair, eyepatch, scar, a black top with a skull and crossed bones, a black cape lined with red, black leather trousers, tall black boots |
| Chef | chef's hat, moustache, kerchief, white chef's jacket, apron, grey checked trousers, sneakers |
| Bare pig | nothing but his tuft of hair |

| Part | Row | Choices |
|---|---|---|
| Head | Hair | a tuft, bald, long and black, long and shaggy, bowl cut, short and grey |
| | Hat | headband, nothing, straw hat, top hat, woolly hat, crown, flying cap, chef's hat |
| | Glasses | none, round glasses, sunglasses, monocle, big square glasses, eyepatch |
| | Face | nothing, moustache, beard, lipstick, scar, grey stubble |
| | Rings | none, earrings, nose ring (through both nostrils), ears and nose |
| Torso | Neck | kerchief, nothing, white scarf, red tie, bow tie |
| | Shirt | explorer jacket, nothing, red T-shirt, sailor shirt, band T-shirt, computer T-shirt, black turtleneck, white shirt, skull and bones, chef's jacket |
| | On top | nothing, gilet, long coat, leather jacket, trench coat, cape, apron |
| Legs | Legs | shorts, nothing, jeans, skirt, black leather, brown cords, grey checks |
| Feet | Feet | bare hooves, white sneakers, grey trainers, brown boots, tall black boots, sandals |

The short shirts (jacket, red T-shirt, sailor shirt) stop above his belly, which pokes out below them as he grows; the others come down over it. The outfits and pieces are named for what they are, not after any film, band or brand.

## How weight works

There is one set of books, in kilograms. **Prosio's weight is nothing but the sum of what he is made of**, and every bar on the screen is one of those parts:

| Part | At the start | What it is |
|---|---|---|
| Bones (and the rest) | 12.5 kg | never changes |
| Fat | 45 kg | his reserve of energy; from none to 100 kg |
| Muscle | 13 kg | arms 5 and legs 8; from 8 kg wasted to 30 kg at the most (see [Body and skills](#body-and-skills)) |
| Carbs | 3 kg | quick fuel: what he has eaten and not yet burned; up to 6 kg |
| Protein | 1.5 kg | what muscle is built from, waiting to be used; up to 3 kg |
| Fibre | 1 kg | roughage on its way through him; up to 2 kg |
| Water | 4 kg | up to 5 kg |
| **He weighs** | **80 kg** | |

Two more things he needs weigh nothing: vitamins and electrolytes.

**Food is made of the same stuff.** A piece's calories are its carbs, fat and protein, 200 kcal to the kilogram; it may hold fibre and water too. Eating puts each into the part of him that is the same thing, so he gets heavier by exactly what the food weighs:

- **Carbs** go into his carbs. What they cannot hold turns to fat: one loaf fills them, and a second goes almost all to fat.
- **Fat** goes straight onto his fat.
- **Protein** goes into his protein. What that cannot hold turns to carbs.
- **Fibre and water** go into his; what will not fit passes through.

**What he burns** comes out of his carbs in proportion to how full they are (all of it when they are full, half when they are half full), and the rest off his fat. **Training** turns protein into muscle, kilogram for kilogram, and muscle that fades or wastes turns back into carbs. Nothing comes from nowhere.

It is his fat that has limits:

| Zone | Fat |
|---|---|
| Faints | none left |
| Lean | under 30 kg |
| Chubby | 30 to 70 kg |
| Huge | 70 kg or more |
| Heart attack | 100 kg |

So a lean, strong, well-fed Prosio (8 kg of fat, 30 of muscle, everything else full) weighs about 66 kg and shows as exactly that: a short yellow piece and a long red one in the weight bar. Fainting and the heart attack both end the game, and so does running right out of water, vitamins or electrolytes for three minutes. `Enter` then wakes him up at home, and it costs him: **his sack is gone**, he has lost about a third of the muscle he had built, and his fat is brought back to between 25 and 70 kg. What he has learnt (his skills) stays, his stores are back in the middle, and the meadow is as it was.

### Burning weight

Everything he does burns some, from very little for walking to more for fighting and most for being hurt. There is no exercise to do: keeping busy is enough.

| What | Burns |
|---|---|
| Walking | 0.02 kg per second (about 1.2 kg a minute), times his weight / 80 kg |
| Sprinting | 0.06 kg per second, times his weight / 80 kg |
| Picking something up | 0.08 kg |
| One jump | 0.06 kg |
| One bump, grab, bash or throw | 0.2 kg |
| Being pecked or butted | 0.35 kg, times how much of it he feels |
| Muscle beyond the ordinary | 0.03 kg a minute for each extra kg, all the time |
| Standing still | his carbs only: a thousandth of them each second |

Five minutes of walking with nothing to eat takes him from 80 to about 73 kg: 4 kg off his fat, 2 off his carbs, and the rest fibre and protein used up. Ten seconds in the middle of an angry flock of turkeys can cost him 2 kg.

## The sack and the oven

Food is not eaten where it is found. `E` next to it and Prosio stoops, picks it up and drops it over his shoulder into the sack on his back (up to nine of each thing). He eats from the sack when he likes: `Z` and `C` choose, `Q` eats.

**Food is scarce.** Of each kind there is never more in the whole meadow than 4,000 kcal's worth, counted at full size (1,200 for mushrooms, which are so light there would be far too many). That is a ceiling, not a promise:

| Food | Where | At most | Comes back |
|---|---|---|---|
| Pumpkins | Two beds in the garden | 10 | A new one sprouts 4 to 9 minutes after one is picked, and takes 5 minutes to grow |
| Wheat | Three small fields | 12 sheaves | Sprouts after 4 to 9 minutes, grows in about 4 |
| Apples | 14 wild apple trees in the forest | 42 (3 a tree, counting those lying under it) | A tree starts a new apple every 2 to 5 minutes; it ripens in about 3 |
| Berries | 40 bushes in the forest | 80 bunches (2 a bush) | A picked bush starts another bunch after 1 to 3 minutes; it ripens in 2 |
| Mushrooms | In the shade of the forest trees | 40 | Sprouts after 1.5 to 4 minutes, grows in under 2 |
| Eggs | Wherever the turkeys are | 10 lying about | Each turkey lays one only every 10 to 20 minutes; an egg lies for 4 minutes |
| Cabbages | A bed in the garden | 16 | Sprouts after 3 to 8 minutes, grows in 4 |
| Nuts | Little heaps under the forest trees | 22 handfuls | A new heap starts after 2.5 to 7 minutes, and more nuts drop on it for 3 |
| Rock salt | Pink crystals standing on four big grey rocks in the goat hills | 8 lumps, 2 a rock (salt has no calories, so no budget) | A rock grows another lump after 5 to 10 minutes |
| Fish | In the pond | 6 | Another swims in 4 to 8 minutes after one is caught |
| Honey | Three hives in the bee meadow | 6 combs (2 a hive) | The bees fill another comb in 4 to 8 minutes |
| Milk | The five goats | a jug from each | A milked goat has milk again after 3 minutes |
| Meat | Turkeys and goats, once dead | 2 pieces from a turkey, 5 from a goat, 8 from the billy goat | Another turkey takes a dead one's place after 5 to 8 minutes, a goat after 8 to 12, the billy goat after 10 to 15 |

**Things grow, and can be picked too early.** A new piece sprouts small and green, with a quarter of its calories, and grows to full size and colour; picked early it is worth less, and the prompt says what it is worth now ("E: pick it now (164 kcal, still growing)"). Each piece's full size also differs by up to 15% either way, so one ripe pumpkin is 350 kcal and the next 450. At the start of a game everything is at a different stage. The sack keeps the real calories of what went into it, and shows what one piece of each kind is worth.

- **Apple trees:** a ripe apple drops now and then, and lies for a minute and a half before it rots. **Bump an apple tree** (or slam an animal or throw one into it) and its apples come down, ripe or not: the harder the hit, the more.
- **A turkey** held by the legs and shaken with `Space` lets an egg drop one time in five.

**Rabbits and crows eat what is left standing.** Two rabbits live in burrows by the garden and two crows circle over the wheat. Every minute or three one comes out for a crop that is at least 60% grown, far from Prosio, and eats it down over 14 seconds: not away altogether, but back to a much smaller size. They run when he comes within about 5 metres (and from his wind), so ripe crops are best picked, or guarded.

**Fish** swim about the pond. They dart away from a pig on the move, but one standing still on the bank makes them curious and they drift over. `F` grabs the nearest if it is within reach (the prompt says when); hit or miss, the splash keeps the rest away for 12 to 22 seconds.

**Honey** is in the three straw hives of the bee meadow, `E` to take a comb. Come within 3.6 m of a hive and its bees are after him, a little faster than he walks, stinging every 0.7 seconds (0.1 kg a sting) until he has been clear of them for 5 seconds. His wind sends them back into the hive and keeps them quiet for 14 seconds, and well padded he hardly feels the stings (see [Nutrients and water](#nutrients-and-water)).

**Milk** comes from a goat (not the billy goat) held by the leg: `E` milks it. Being salty helps, as the goats then come to him.

**Meat** comes from a turkey or a goat that has been knocked out, which now means dead (see [Fighting](#fighting)). The body has to be dragged to the chopping block by the cooking fire, at the pond, and `E` there chops it into pieces of raw meat.

**Some food cannot be eaten as it is.** Raw eggs, raw fish and raw meat have to be cooked on the fire. Wheat has to be ground into flour at the **mill**, a little windmill by the wheat fields: `E` there puts all the wheat in the sack into it, the sails spin while it grinds (2.5 seconds a sheaf), and `E` again takes the flour. Flour cannot be eaten either: it goes into the oven. So bread means a walk to the fields, the mill, and home to the oven.

What is in one ripe piece of the usual size (the kilograms of carbs, fat and protein are its calories; the last column is what it weighs going in, which is what he gains):

| Raw food | kcal | Carbs | Fat | Protein | Fibre | Water | Vitamins | Electrolytes | Weighs |
|---|---|---|---|---|---|---|---|---|---|
| Bunch of berries | 50 | 0.25 | | | 0.04 | 0.15 | 9 | | 0.44 kg |
| Apple | 95 | 0.48 | | | 0.08 | 0.2 | 6 | 1 | 0.75 kg |
| Mushroom | 30 | 0.05 | | 0.1 | 0.06 | 0.05 | 2 | 4 | 0.26 kg |
| Pumpkin | 400 | 1.8 | | 0.2 | 0.2 | 0.3 | 12 | 6 | 2.5 kg |
| Cabbage | 250 | 1.0 | | 0.25 | 0.7 | 0.25 | 12 | 4 | 2.2 kg |
| Handful of nuts | 180 | 0.04 | 0.67 | 0.18 | 0.06 | | | 1 | 0.96 kg |
| Jug of milk | 150 | 0.19 | 0.34 | 0.23 | | 0.5 | 2 | 3 | 1.25 kg |
| Comb of honey | 300 | 1.5 | | | | | 1 | 1 | 1.5 kg |
| Lump of rock salt | 0 | | | | | -0.75 | | 30 | takes 0.75 kg of water out of him |
| Wheat (a sheaf), or its flour | 340 | 1.45 | 0.05 | 0.2 | 0.08 | | | | not edible until baked |
| Egg | 130 | | 0.36 | 0.29 | | | 3 | 1 | not edible until fried, or baked |
| Fish | 200 | | 0.3 | 0.7 | | | 3 | 3 | not edible until grilled |
| Piece of meat | 300 | | 0.6 | 0.9 | | | 1 | 2 | not edible until roasted |

**The oven** stands at home, by the start: a round brick oven with a chimney. `E` next to it opens its menu (the game waits meanwhile): every recipe, what it needs and what is in the sack, and its calories. `Up`/`Down` choose, `E` or `Enter` bakes, `Esc` closes. Baking takes 6 seconds, with a fire in the oven and smoke from the chimney; then it says "Ding!", and the dish waits in the oven's mouth, where you can see what it is, until Prosio takes it out with `E`, into the sack.

Cooking makes more of the calories in food available to the body, so **a baked dish counts 1.4 times the calories of what actually went into it** (unripe ingredients make a poorer pie). With ripe ingredients of the usual size:

| Dish | Needs | Raw | Baked | Carbs | Fat | Protein | Weighs |
|---|---|---|---|---|---|---|---|
| Apple pie | 3 apples, 1 flour, 1 egg | 755 | 1057 kcal | 4.0 | 0.57 | 0.7 | 6.2 kg |
| Pumpkin pie | 1 pumpkin, 1 flour, 1 egg | 870 | 1218 kcal | 4.5 | 0.57 | 1.0 | 6.7 kg |
| Berry muffins | 3 bunches of berries, 1 flour, 1 egg | 620 | 868 kcal | 3.1 | 0.57 | 0.7 | 5.0 kg |
| Mushroom pie | 3 mushrooms, 1 flour, 1 egg | 560 | 784 kcal | 2.2 | 0.57 | 1.1 | 4.3 kg |
| Nut cake | 2 handfuls of nuts, 1 flour, 1 egg | 830 | 1162 kcal | 2.2 | 2.5 | 1.2 | 6.0 kg |
| Bread | 2 flour | 680 | 952 kcal | 4.1 | 0.14 | 0.57 | 4.9 kg |

A dish is the sum of what went into it; the calories cooking adds are shared between its carbs, fat and protein in the same proportions.

So a trip to the forest, the fields, the mill and Turkey Meadow for an apple pie is worth more than eating everything raw on the way.

**The cooking fire** is by the pond, with a spit over it and the chopping block beside it, and **the churn** stands in the goat hills. They work like the oven, each with a menu of its own. In all three menus `Left`/`Right` choose how many to make at once, as many as the sack has the makings of. The fire takes 4 seconds and the churn 5, whatever the number. Cooking on the fire gives the same 1.4 times; churning changes nothing in the calories.

| Made | Where | Needs | kcal | Carbs | Fat | Protein | Weighs |
|---|---|---|---|---|---|---|---|
| Fried egg | fire | 1 egg | 182 | | 0.5 | 0.41 | 0.91 kg |
| Grilled fish | fire | 1 fish | 280 | | 0.42 | 0.98 | 1.4 kg |
| Roast meat | fire | 1 piece of meat | 420 | | 0.84 | 1.26 | 2.1 kg |
| Butter | churn | 2 jugs of milk | 300 | | 1.5 | | 1.5 kg |
| Cheese | churn | 2 jugs of milk, 1 lump of salt | 300 | | 0.83 | 0.67 | 1.5 kg |

### What fat changes

Neither end is the "good" one. Each is a tool.

| | Lean | Huge |
|---|---|---|
| Body radius | 0.42 at 35 kg | 0.97 at 135 kg |
| Walking speed | fast (7.2 with no fat) | slow (2.6 with 100 kg of it) |
| Sprint | 1.7 times walking | 1.25 times walking |
| Jump height | high (0.9 at 40 kg) | low (0.3 at 120 kg) |
| Stamina recovery | 50 per second | 8 per second |
| Cost of a bump | 9 stamina | 42 stamina |
| Bump | bounces off enemies | sends them flying |
| Being shoved | flies far | hardly moves |
| A peck or a butt | he feels 1.5 times of it | he feels half of it |
| Throw | weak | strong |

His body is drawn from simple shapes in code, so it changes smoothly with every kilogram: the belly grows out from under a cropped explorer jacket, and jiggles.

## Body and skills

Prosio becomes what he does. Besides his fat he has **seven traits**: the muscle of his arms and of his legs, and five skills. Each is a level that follows what he has been doing lately:

- **Doing the thing trains it.** Each time, the trait gains a share of what it still lacks, so it rises quickly at first and more slowly near the top.
- **Left alone it fades**, as in real life: it loses half of what he had built in about 18 minutes of play (only play counts, not time with the game closed). So a habit shows on him after a few minutes, and he cannot keep everything up at once.
- **Muscle is built out of protein, kilogram for kilogram.** Training takes it from the protein in him: with little there it builds little, with none it builds nothing. So a goat's five pieces of roast meat are over 6 kg of muscle waiting to be trained, and a pig that eats no protein stays ordinary however hard he works. When he lacks protein (or is starving) his muscles waste away below their ordinary size, in about 11 minutes, and come back in about 8 once he is fed.
- **Muscle is heavy and hungry.** It adds to his weight, and every kilogram beyond the ordinary burns a little all the time. Muscle that fades or wastes is not lost: it turns back into carbs.

| Trait | Grows by | At its most | Shows as |
|---|---|---|---|
| Arms (3 kg wasted, 5 ordinary, 12 at most) | holding rocks and animals, dragging, bashing, throwing | he lifts and throws 1.8 times as much (wasted: 0.6 times) | thick or thin arms |
| Legs (5, 8, 18 kg) | sprinting, jumping, long walks, dragging bodies | he walks and runs 1.3 times as fast, and twice the energy goes into a jump, so into a stomp too (wasted: three quarters) | sturdy or thin legs |
| Lungs | sprinting | a sprint costs 55% of the stamina, and breath comes back 1.6 times as fast | a broader chest |
| Hide | taking pecks, butts and stings | he feels half of every knock, on top of what his fat takes | darker, tougher skin |
| Gut | eating fibre | from level 0.4 he holds his wind until `G` is pressed (ready again after 2 seconds), and it reaches up to 1.5 times as far | the fibre bar says "GASSY: press G" |
| Hooves | picking, fishing, milking | picking takes half the time, and he reaches 1.4 times as far for a fish or a leg | quicker stoop |
| Cooking | baking, cooking, churning | the cooking bonus rises from 1.4 to 1.6, in half the time | the menu shows the bonus |

In scripted runs: sprinting half the time with protein kept up took his legs from 8 to 12.6 kg in 5 minutes (walking 5.7 instead of 4.8 m/s after ten); holding a rock of his own weight half the time took his arms from 5 to 8.6 kg in 6 minutes, enough to swing the billy goat.

The **muscle bar** under the fat shows arms and legs together: wasted to the left of the mark, built up to the right. The player does not steer the two separately except by what Prosio does; the body panel of the `M` menu shows each by itself.

## Nutrients and water

Four of his parts are **stores** that fill and empty as he eats and lives: carbs, protein, fibre and water. Each has a bar that shows how full it is, and its kilograms. Two more things, **vitamins** and **electrolytes**, weigh nothing but have bars of the same kind. (Fats are not a separate level: the fat he eats is the fat on him.)

- **Eating** fills them with what the food contains (see the tables in [The sack and the oven](#the-sack-and-the-oven)).
- **At rest** each loses a thousandth of what is in it every second, so half in about 11 minutes. Carbs are burned; protein turns into carbs; fibre passes.
- **Activity** burns his carbs faster, in proportion to how full they are.
- **Water** runs down steadily: a full drink lasts a good quarter of an hour, less if he sprints. `E` at the pond fills it; juicy food helps a little.

A game starts with everything half full and water at 80%.

**The system is forgiving, and what matters is what he lacks.**

- **Too much of anything never ends the game.** Above 90% a store moves its surplus on six times as fast: too many carbs turn to fat, too much protein turns to carbs, the rest passes, and a drink at the pond washes out too much fibre, vitamins or electrolytes at once. (Only too much *fat* is dangerous.)
- **Running out of carbs, protein or fibre never ends the game either.** His fat keeps him going; he is just the worse for it.
- **Running right out of water, vitamins or electrolytes does**, but slowly: under 4% (for water: none left) the bar's name blinks and a countdown of **three minutes** runs beside it. Eating nothing at all, that point is over 40 minutes away.
- **What to eat is always on the screen:** whenever he lacks something, a line under the bars says what to eat for it ("EAT: eggs, fish, meat, nuts").

A store between 15% and 70% does nothing. Below 15% he **lacks** it, which is a nuisance. Above 70% he is **full of** it, which is funny and useful as well as a nuisance, so it can be worth eating for. Above 90% it is **too much**: funnier, less useful, and soon over.

| | Lacking it (under 15%) | Full of it (over 70%) | Too much (over 90%) |
|---|---|---|---|
| Carbs | **No fuel:** stamina comes back half as fast, and everything he burns comes off his fat | **Sugar rush:** 25% faster, and a sprint costs under a third of the stamina. When it wears off, an 8-second **sugar crash** | **Hiccups:** every few seconds one jerks him into a little jump, while the surplus turns to fat |
| Protein | **Wasting:** his muscles waste away (see [Body and skills](#body-and-skills)) | **Bulking:** training builds muscle twice as fast; but everything burns 1.4 times the weight | **Stiff as a board:** swinging and stooping take 1.6 times as long |
| Fibre | **Tummy ache:** every 10 to 16 seconds he doubles up for a second | **Gassy:** every 5 to 8 seconds he breaks wind with a green cloud and a little hop, and every animal within 7.5 m runs from him for 5 seconds | **A gas storm:** one every second or two, whatever his gut is trained to |
| Water | **Thirsty** (under 25%): his stamina only comes back half way | There is no such thing as too much | |
| Vitamins | **Dim eyes:** the dark closes in round the screen, the camera sits closer, and he uncovers less of the map | **Eagle eyes:** the camera sits 30% further back, and he uncovers the map 1.8 times as far | **Glowing:** he turns orange, and turkeys and goats spot him from half as far again |
| Electrolytes | **Cramps:** he jumps only 60% as high, and 2.5 seconds of sprinting end in a cramp | **Salty:** the goats trot up and lick him instead of butting him; but he gets thirsty 2.5 times as fast | **Parched:** thirsty 5 times as fast |

So bread and honey are the sugar rush (and, past that, fat), cabbage is the gas, eggs, fish and meat are what muscle is made of, nuts and butter are fat, berries are the eagle eyes, and salt, which only the goat hills have, is what makes the goats friendly. The sack panel of the `M` menu shows what one piece of the chosen food would put into him, part by part, and what it weighs in all.

In scripted runs, twenty loaves, eggs, lumps of salt or roasts eaten in four minutes never ended the game.

## Moving, jumping and stamina

- **Sprint** drains stamina (9 per second lean, 42 huge). At zero he is winded and cannot sprint again until 30 is back.
- **Jump** always uses the same leg energy, so the height is `36 / weight`. A lean Prosio clears small rocks and can hop over enemies; a huge one barely leaves the ground.
- **Coming down on an animal** from a jump is a stomp. The damage is **his weight times the height of his jump** (times `STOMP_K`, 1), which is 36 for every Prosio, since a heavy one cannot jump as high. Damage adds up and wears off at 4 a second; it takes 50 to knock out a turkey (two stomps), 110 a goat and 160 the billy goat. An animal that is not knocked out is left dizzy for longer the harder it was hit. He bounces off it, and the bounce does not count as another stomp.

## Fighting

The enemies are farm animals gone bad-tempered: big turkeys (16 kg) all over the meadow, in the north-east a few goats (55 kg) led by a billy goat (95 kg, more than Prosio at the start), and in the forest five foxes (20 kg). They have big kawaii eyes. A cross turkey spreads its barred tail fan and frowns; the billy goat is brown, with a shaggy mane, a long beard and great curling horns.

**A knocked-out turkey or goat is dead.** Its body lies where it fell, limp, with little crosses for eyes, for 4 minutes. `F` takes it by the leg (a turkey is carried by the feet, a goat dragged), and it is as floppy as any held animal: it can still be used as a club, or thrown. Dead weight slows him down: a turkey hardly, a goat to about 70% of his speed, the billy goat to under 60%, and holding it costs stamina. At the chopping block by the fire `E` turns it into meat (see [The sack and the oven](#the-sack-and-the-oven)). Another animal takes its place only after 5 to 15 minutes, so hunting thins the flock, and with it the eggs. A knocked-out fox only vanishes for a minute or two.

**Foxes steal.** A fox does not fight. When Prosio comes within 13 m with anything in his sack, it comes up on him from wherever he is not looking, and stands stock still whenever he turns to face it. If it reaches him it takes the richest thing in the sack and runs for its den, where it eats it. A bump, a grab, a stomp, anything that sends it flying, or his wind, and it drops what it took and he has it back; then it keeps away for 25 seconds.

**Turkeys hunt like a pack.** The turkeys near Prosio do not run at him in a bunch. Like wolves round their prey, they spread out round him at about three metres, each taking its own place in the order they already stand (so their paths do not cross), with the places drifting round to his back. From time to time one darts in on a curve, flapping, leading him a little: more likely from behind (55% at each try), less from the side (25%) and rarely from in front (6%), and never more than two at once. After a peck, or a miss, it falls back and circles again. Turkeys go round obstacles they bump into, and if one finds itself wedged in a dead end it turns back and tries the other way.

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

**Rocks heavier than twice his own weight cannot be lifted at all** ("Way too heavy to lift!"). If a rock slips from his hands before he has it up (he runs out of stamina), he can move again at once.

**Only something lighter than 0.9 times his own weight can be swung or thrown**, with ordinary arms. That is any turkey, a goat from about 61 kg, and the billy goat only from about 106 kg. Built-up arms raise that by up to 1.8 times, and wasted ones lower it to 0.6 (see [Body and skills](#body-and-skills)); rocks and throws go the same way. With something too heavy, `Space` is a heave: he strains with all he has, lifts its rear a little, and it answers with a lunge. `F` just lets go. He can hang on until his stamina runs out or it pulls free.

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

The meadow is 200 by 140 metres inside a fence, more than five times as big as before. Prosio's home is in the middle: a bare yard with the oven, and footpaths winding out from it to each part of the meadow. Each part has its own food, its own look on the ground, and its name in the top right corner while he is in it.

| Where | Which way from home | What is there |
|---|---|---|
| The forest | west | About 135 trees on a darker floor strewn with leaves, standing in a dozen tight groves with open glades between; 14 wild apple trees alone in the glades, 40 berry bushes, mushrooms and heaps of nuts at the foot of the groves, and five foxes |
| The wheat fields | south-east | Three small ploughed fields of wheat, the windmill that grinds it, a few shady trees, and two crows overhead |
| The garden | south | Two beds of pumpkins and a bed of cabbages, and two rabbit burrows |
| Turkey Meadow | north | Open grass, most of the 22 turkeys and their eggs |
| Goat hills | north-east | Dry, stony ground with big rocks and pines, the goats and the billy goat, four big rocks with pink rock salt growing on them, and the churn |
| The pond | north-west | The only water to drink: a round pond with a sandy shore, bulrushes, lily pads and six fish. He cannot walk into it. The cooking fire and its chopping block stand on the east bank |
| Bee meadow | south-west | Flowers everywhere, a few blossom trees, and three hives |

In between is open meadow with lone trees and rocks, but no food, and a few turkeys wandering about. Animals far from Prosio rest until he comes near.

**Where trees may stand.** The camera always looks from the south and from above, so a tree's leaves hide a strip of ground to the north of its trunk: for a tall tree, from about 4 to 10 metres behind it. Two rules follow, and the meadow is built by them:

- No tree is planted where its leaves would stand in front of something that has to stay in view: a path, a field, the oven, mill, fire or churn, a hive, a salt rock, a berry bush, or food lying on the ground.
- What is put down after the trees (bushes, mushrooms, nuts, salt rocks) goes only where no tree is in front of it. Mushrooms and nuts lie at the foot of a grove on the camera's side, and apples fall on that side of their tree.

So the forest is groves and glades rather than trees everywhere: each grove is about ten trees, longer from north to south than it is wide, since that hides the least ground. In the test run no path, building, bush, salt rock or piece of food was behind a tree, and 78% of the forest floor was in view. A tree Prosio does walk behind still fades to a see-through pattern where it covers him, pines included.

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
    prosio.odin      Prosio: the limits of his fat, movement, jump, sprint,
                     stamina
    body.odin        his muscles and skills, which follow what he does; waking
                     up after the game is over; saving
    kitchen.odin     the sack, calories, recipes, the oven, the fire, the churn,
                     the mill, and their menus and pixel icons
    diet.odin        what he is made of, in kilograms, and his weight as the
                     sum of it; what each food is made of; eating, burning,
                     and what too much or too little of each store does; the
                     panel that shows it all
    outfit.odin      Prosio's clothes, how each is drawn, and the sack, outfit
                     and map menu
    enemies.odin     turkeys, goats and foxes, bumps, shoves and stomps, bodies,
                     meat and milk
    critters.odin    fish, rabbits, crows and bees
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
- **Bodies** are built from those shapes. Arms and legs are tapered segments (thigh, shin, upper arm, forearm) that narrow towards the hooves, with round joints between; Prosio's shorts sit high over two small buttocks, so his legs show below them, and his arms are plump with a round biceps. He is built short and stocky, and drawn cute, kawaii style: short legs, a compact body, a big round head with big glossy eyes, rosy cheeks and a small smile, and floppy ears that hang down beside his cheeks, flap as he walks and fly up when he falls. When he eats, it is his belly that grows, forwards and sideways; his bottom hardly changes. Swapping raylib for another library would mean rewriting `platform.odin` only.
- **No memory allocation in the game.** Everything lives in one `Game` struct of fixed-size arrays, which is also why the web build needs no allocator.
- **Physics on the ground plane, plus height.** Positions are 2D; things that jump or fly also have a height and a vertical speed. Physics runs in fixed steps of at most 1/120 of a second.
- **Pixel art from 3D.** The scene is lit by a warm, low sun in four flat tones (deep shade, shade, light and a sunlit highlight, with dithered edges between them): cool violet shadows, warm highlights, a touch of blue skylight on anything facing up, darkening where things meet the ground, and broad soft patches of sunlight on the grass. A limited palette, dithered ground and one-pixel outlines finish it. Everything is drawn into a small image that is enlarged without smoothing. There are six pixel sizes (keys `1` to `6`), aiming at about 180, 240, 320, 360 (the default), 420 and 560 rows of pixels. Each game pixel is a whole number of real screen pixels (on a high-resolution screen it can also be a whole number and a half, which is what makes room for the level between 320 and 420), so the actual count is the nearest that fits the window, and each level is kept at least one step finer than the one below it as far as the window allows (on a small window the finest levels can end up the same). The camera is snapped to whole pixels so scenery does not shimmer as it scrolls, and the image is shifted by less than a pixel to keep scrolling smooth.
- **Surface detail is calculated, not painted:** grass tones, the forest floor, the stony hills, the paths and the ploughed fields, leaf clumps, bark grain and moss are all noise in the shader. Where the fields, paths and regions are is passed to the shader once, at start-up. Leaves sway in the wind.
- **Shadows are cast, not stamped.** Everything that stands in the sun is first drawn flattened onto the ground along the sunlight, in grey, into an image of its own; the ground is then drawn and that image multiplied over it, and everything else drawn on top. So every shadow has the shape of what casts it (a tree's trunk as well as its crown, Prosio mid-jump), falls the same way as the light, and is simply a darker version of whatever it lands on: grass, path, soil or forest floor. Where shadows overlap they are no darker than one.
- **Trees** are tall and slim: a trunk plus clusters of round leafy lumps that are darker underneath, in four species (broadleaf, apple, blossom, pine). A tree standing between the camera and Prosio fades to a see-through pattern where it covers him; its shadow stays whole.
- **Only what is near the camera is drawn.**

## Testing without playing

The desktop build takes options that script a run, save a picture and quit. They ignore the real keyboard and use a fixed time step, so a run is repeatable. They neither load nor save the saved game.

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
| `--bodies` | put a dead turkey (within reach), a dead goat and a fox with a stolen apple round him, and a rabbit and a crow making off |
| `--stock` | start with a sack full of food (three of each raw thing, one of each dish) |
| `--needs 85,45,80,20,45,45` | how full his stores are at the start, in percent: carbs, protein, fibre, water, vitamins, electrolytes |
| `--traits 0.9,0.2,0.8,1,0.5,0.3,0.6` | his muscles and skills at the start, 0 to 1 (the first two may go down to -1): arms, legs, lungs, hide, gut, hooves, cooking |
| `--outfit 1` | what he wears: one digit per row of the outfit menu, 0 being the first choice. The first digit is the whole outfit (`1` is the metalhead, `5` the space pirate); further digits change single rows after it, in the order hair, hat, glasses, face, rings, neck, shirt, on top, legs, feet (`00000002200` is a red T-shirt under a long coat) |
| `--detail 4` | pixel size: 1 chunkiest to 6 finest (default 4) |

Button letters: `l r u d` to move, `b` bump, `j` jump, `s` sprint, `a` pick up, oven, mill or drink, `g` grab or throw, `q` eat from the sack, `z` `c` choose in the sack, `e` enter, `m` the sack and outfit menu, `w` wind.

For example, Prosio grabs a turkey from the crowd on frame 12, walks off dragging it, bashes on frame 50, and the picture is taken mid-swing:

```bash
./build/desktop/prosio --crowd --tap g --tap-at 12 --hold d --tap2 b --tap2-at 50 --shot bash.png --frame 62
```

## Tuning

Every number that shapes the feel is a named constant or a one-line function near the top of its file:

| To change | Look in |
|---|---|
| Fat limits and zones | `prosio.odin` (`FAT_*`) |
| Muscle sizes, how fast traits grow and fade, what each activity trains, what each trait is worth, what waking up costs | `body.odin` (`ARMS_KG`, `LEGS_KG`, `FADE`, `WASTE`, `*_WORK`, `STRONG`, `LEG_SPEED`, `WAKE_*`, ...) |
| Calories, recipes, the cooking bonus, sack size, baking time | `kitchen.odin` (`RAW_KCAL`, `RECIPES`, `COOK_BONUS`, `KCAL_PER_KG`) |
| Speeds, sprint, stamina costs and recovery, jump energy | `prosio.odin` (`walk_speed`, `dash_cost`, `JUMP_ENERGY`, ...) |
| How hard bumps and shoves are, enemy weights and grips | `enemies.odin` |
| Throw and bash strength, lift limit, dragging grip, how fast animals go limp, rock weight | `grab.odin` |
| World size, regions, fields, paths, how many trees and rocks | `world.odin` (`WORLD_HALF`, `REGIONS`, `PATH_ENDS`, `build_world`) |
| How often turkeys lay, the chance of a shaken-out egg | `enemies.odin` (`EGG_EVERY`, `SHAKE_EGG`) |
| How hard stomps hit, how tough each animal is, how fast it heals | `enemies.odin` (`STOMP_K`, `ENEMY_TOUGH`, `HEAL_RATE`) |
| How much of each food there can be, and how fast it comes back and grows | `world.odin` (`FOOD_BUDGET`, `MUSHROOM_BUDGET`, `FOOD_REGROW`, `FOOD_GROW`, `APPLE_*`, `BERRY_*`, `UNRIPE`, `SIZE_SPREAD`) |
| How long the mill takes | `kitchen.odin` (`MILL_TIME`) |
| What each food is made of, how big each store is, where lacking, full and too much begin, how fast stores empty, and how strong every effect is | `diet.odin` (`STUFF`, `STORE_KG`, `FRAME`, `NEED_*`, `THIRST`, `TOO_LONG`, `DEADLY`, and the numbers under "What full and lacking do") |
| Where the pond is and how big | `world.odin` (`POND`, `POND_RADIUS`) |
| Recipes, where each is made, how long each place takes | `kitchen.odin` (`RECIPES`, `STATION_TIME`, `STATION_BONUS`) |
| Meat from each animal, how long a body lies and how long until another animal comes, milk, how foxes behave | `enemies.odin` (`MEAT_FROM`, `BODY_LIFE`, `RESPAWN`, `MILK_EVERY`, `FOX_NOTICE`, `FOX_REST`) |
| Fish, rabbits, crows and bees | `critters.odin` (`FISH_*`, `PEST_*`, `NIBBLE`, `HIVE_GUARD`, `BEE_*`, `STING_*`) |
| Clothes, whole outfits and their colours, how thick a layer is | `outfit.odin` (`PRESETS`, `SHIRT_LOOK`, `OVER_LOOK`, `LAYER`) |
| Where trees may stand, how many groves and how big | `world.odin` (`VIEW_SLOPE`, `GROVES`, `GROVE_TREES`, `GROVE_SIZE`, `GROVE_GAP`, `tree_cover`) |
| Salt rocks | `world.odin` (`SALT_ROCKS`, `MAX_SALT`, `SALT_REGROW`) |
| What everything burns | `prosio.odin` (`WALK_BURN`, `GATHER_BURN`, `FIGHT_BURN`, `HURT_BURN`, ...) |
| The sun's direction and how dark shadows are | `platform.odin` (`SUN`, `SHADOW_INK`) and `scene.frag` |
| Colours | `draw.odin`, `ui.odin` |
| Keys | `KEYS` in `platform.odin` |

## Known gaps

- No sound or music.
- A single meadow, and it is not saved: only Prosio is.
- The map is only uncovered by walking; there is nothing to buy or find that reveals more of it.
- No goal beyond keeping Prosio healthy; the puzzles of earlier versions are gone for now.
- Rabbits, crows and bees cannot be caught or fought, only chased off; fish cannot be seen being carried. A fox gives what it stole straight back to the sack instead of dropping it on the ground.
- Food regrows by itself; there is no sowing or watering yet.
- The nutrient numbers, how fast muscles and skills grow and fade, and the numbers of fishing, bees, pests and foxes, come from scripted runs, not from children playing: they will want tuning.
- Reputation with each kind of animal, rolling in mud and tanning in the sun were ideas for shaping Prosio that are not built.
- Saving in the browser was checked piece by piece (the page's storage code, and the game reading it at start-up), not by playing a whole sitting in a browser and coming back.
- No gamepad or touch controls.
- Linux and Windows builds are untested.
- Text uses raylib's built-in pixel font.
- The game has been checked mostly through scripted runs and screenshots; balance and feel still need real play.
- The story is deliberately not written yet.
