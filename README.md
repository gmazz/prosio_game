# Prosio

Prosio is a small 2.5D top-view action game about a pig explorer whose weight is the whole game. He roams a big meadow gathering food into his sack and bakes it into pies at his oven. Everything he does burns a little weight and everything he eats puts some back, and almost everything he can do depends on how heavy he is at that moment: how fast he runs, how high he jumps, how far an enemy flies when he bumps it, and what he can pick up and throw.

It is written in [Odin](https://odin-lang.org) on top of [raylib](https://www.raylib.com), runs natively on the desktop and in the browser through WebAssembly, and is aimed at children of about seven.

This is a proof of concept: one meadow, no goal yet beyond keeping Prosio fed and healthy.

## Contents

- [Playing](#playing)
- [How weight works](#how-weight-works)
- [Body and skills](#body-and-skills)
- [The sack and the oven](#the-sack-and-the-oven)
- [Wood and the workshop](#wood-and-the-workshop)
- [Nutrients and water](#nutrients-and-water)
- [Moving, jumping and stamina](#moving-jumping-and-stamina)
- [Fighting](#fighting)
- [Grabbing and throwing](#grabbing-and-throwing)
- [The meadow](#the-meadow)
- [Building](#building)
- [How the code is organised](#how-the-code-is-organised)
- [Asset workshop, integration plan and agent handoff](docs/asset-integration.md)
- [Testing without playing](#testing-without-playing)
- [Tuning](#tuning)
- [Known gaps](#known-gaps)

## Playing

Keep Prosio's energy in balance. Walking, picking things up and fighting all burn a little of his weight; food puts it back, but slowly, so he has to keep going out to gather it. Each kind of food grows in its own part of the meadow, so he has to know where to look, and the best food is what he bakes, cooks or churns from it, each in its own place. Calories are not everything: he also needs six nutrients and water, so he has to eat a bit of everything, and drink at the pond. And Prosio becomes what he does: what he keeps doing builds his muscles and his skills, and what he stops doing fades. He is saved as you play, so he is the same pig next time.

### Controls

| Action | Keys |
|---|---|
| Move | `W` `A` `S` `D` or the arrow keys |
| Bump (belly charge) | `Space` |
| Jump | `J` or `X` |
| Sprint | hold `Shift` while moving |
| Grab. Then: tap to put it down, or hold to wind up and let go to throw | `F` or `L` |
| Bash with a held animal | `Space` |
| Pick up food into the sack (next to food or a berry bush) | `E` or `K` |
| Use the oven, the fire, the churn, the mill, the workbench or a larder, or drink at the pond (next to it) | `E` or `K` |
| Open or shut a gate in front of him, with or without an animal in his hooves | `E` or `K` |
| Grab a fish (on the bank of the pond, with one close); with the fishing rod chosen in the sack, cast it | `F` or `L` |
| Throw a pebble or a spear (chosen in the sack, nothing in reach to grab): hold to wind up, let go | `F` or `L` |
| Put up a piece of fence, a gate, a scarecrow or a larder (chosen in the sack), in front of him | `Q` |
| Lift a held turkey or fox over the fence in front of him | `F` or `L` (tapped) |
| Take a piece of fence, a gate, a scarecrow or an empty larder down (standing at it, with nothing to grab and nothing to throw chosen) | `F` or `L` |
| Choose what a throw is aimed at, while winding up | the direction keys |
| Milk a held goat, or one in a pen; chop a held body into meat (at the fire) | `E` or `K` |
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

The game opens on a main menu (Play, the pixel size, and Quit on the desktop). `Esc` pauses, with Resume, Start over and Exit to menu.

**Saving.** A Prosio saved by an earlier version of the game (before pebbles, before wood and the workbench, or before gates, larders and the three kitchen skills) is carried over as he was; his one old cooking skill becomes all three kitchen skills. Prosio is saved every 15 seconds of play, when the game is paused, when it goes back to the menu, and the moment he goes down (as the pig who will wake up at home, so leaving the game while he lies there does not undo it): his fat, muscles and skills, his nutrient levels, his sack, his outfit, the recipes and plans he knows, what he has uncovered of the map, and what he has built in the meadow: his fences and gates (open or shut), his scarecrows, his larders with what is in them, and the animals in his pens (up to 240 pieces of fence, 8 scarecrows, 4 larders and 12 animals); and how fresh the food in his sack is. On the desktop this is the file `prosio.sav` beside the program; in the browser it is kept in the browser's own storage for the page. With a saved Prosio the main menu says Continue instead of Play, and has Start over, which begins again with a new pig. The rest of the meadow starts afresh each sitting: food, the other animals, a spear left lying and what is in the oven are not saved.

 The menus of the oven, the fire and the churn, and the sack, outfit and map menu, also pause the game.

**The sack, body, outfit and map menu** (`M`) has four panels; `Z` and `C` switch between them, `M` or `Esc` closes it.

- **Sack:** everything that can be in the sack, gathered or baked, in a grid: its picture, how many (greyed out when none), and for the chosen one its name, calories and how much weight it puts on. The arrows choose, `E` or `Enter` eats.
- **Body:** what he weighs as the sum of his parts (the same bar, with each part's kilograms), then his arms, his legs and his four skills of the body, each with a bar, whether it is growing or fading, what makes it grow and what it is good for; and, a line each, his three kitchen skills with his title at each station and what it is worth (see [Body and skills](#body-and-skills)).
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

Two more things he needs weigh nothing: vitamins and electrolytes. Food gives all of its points of these only while he is under half full of them; above that he takes in less and less, and nothing when full.

**Food is made of the same stuff.** Each food has a composition: the share of its calories that is carbs, fat, protein, fibre, vitamins and electrolytes, adding up to 100% (the tables in [The sack and the oven](#the-sack-and-the-oven) give them all). A piece puts into him exactly those shares of its calories and nothing it is not made of, and a piece twice as rich puts in twice as much of each. Each share goes in at a fixed rate: carbs, fat and protein 200 kcal to the kilogram, fibre 60 kcal to the kilogram, vitamins and electrolytes a point of their level for each kcal. So a food's calories count all of it; only its carbs, fat and protein are energy. Food holds no water: that comes from the pond. Eating puts each share into the part of him that is the same thing, so he gets heavier by exactly what the food weighs:

- **Carbs** go into his carbs. What they cannot hold turns to fat: one loaf fills them, and a second goes almost all to fat.
- **Fat** goes straight onto his fat.
- **Protein** goes into his protein. What that cannot hold passes through him. Protein never turns into carbs, so eggs, fish, meat and cheese put next to no carbs into him.
- **Fibre** goes into his; what will not fit passes through.

**What he burns** comes out of his carbs and his fat, and **muscle is what burns it**: every kilogram of muscle uses energy all the time, so a muscular pig needs proportionally more feeding than a lean one (see [Burning weight](#burning-weight)).

- **Muscle work takes carbs first, then fat.** That is his muscles keeping going, sprinting, jumping and fighting.
- **Everything else takes from both:** walking, picking and being hurt take carbs in proportion to how full they are (half the cost when they are half full), and the rest off his fat.
- **With no fat left he lives on his carbs, and with neither he faints.** Nothing else keeps him going: muscle that fades or wastes simply goes, as burned fat does.

**Training** turns protein into muscle, kilogram for kilogram. Nothing comes from nowhere.

It is his fat that has limits:

| Zone | Fat |
|---|---|
| Faints | no fat **and** no carbs left |
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
| Picking something up | 0.03 kg |
| One jump | 0.06 kg |
| One bump, grab, bash or throw | 0.2 kg |
| His muscles, all the time | 0.014 kg a minute for each kg of muscle, carbs first: 0.11 kg a minute wasted (8 kg), 0.18 ordinary (13 kg), 0.41 at the most (30 kg) |

Sprinting, jumping and fighting take carbs first too; walking and picking take from carbs and fat together. Being pecked, butted or stung burns nothing: it bruises him (see [Being shoved](#being-shoved)).

Five minutes of walking with nothing to eat takes an ordinary Prosio from 80 to about 71.5 kg: 4 kg off his fat, over 2 off his carbs, 1.5 of water, and the rest fibre and protein used up (some of the protein goes into his legs). Ten seconds in the middle of an angry flock of turkeys can cost him 2 kg.

How muscle changes what he needs, in scripted runs:

| | Wasted (8 kg) | Ordinary (13 kg) | Muscular (25 kg) | Most muscle (30 kg) |
|---|---|---|---|---|
| Burned in 10 minutes standing still | 0.8 kg | 1.1 kg | 2.8 kg | 3.5 kg |
| Burned in 5 minutes walking | 5.7 kg | 6.4 kg | 7.9 kg | 8.6 kg |
| With no fat and full carbs, faints after | | 51 min | 27 min | 22 min |

So a strong pig is hungry: he gets through his carbs in under 20 minutes at rest and wants bread, honey or fruit, where an ordinary one hardly notices.

## The sack and the oven

Food is not eaten where it is found. `E` next to it and Prosio stoops, picks it up and drops it over his shoulder into the sack on his back. He eats from the sack when he likes: `Z` and `C` choose, `Q` eats.

**The sack holds 60 litres**, of whatever he likes, and is meant to be roomy: the sixteen logs for a whole pen go in at once, or the eight pieces of fence they make, with room for food beside them; fifteen pumpkins fill it. Each thing takes up room and has a weight (a berry bunch 0.1 kg and 0.2 litres, an apple 0.2 kg and 0.3 litres, a log 1 kg and 1.5 litres, a pumpkin 3 kg and 4 litres, a flat-packed piece of fence 3 kg and 4 litres: all in `ITEM_KG` and `ITEM_LITRES` in `kitchen.odin`). Under the sack on the screen are how full it is and what it weighs ("18 / 60 L   7.5 kg"). **The weight has no limit but his back**, and he carries it. The sack sits well on his back, so his legs feel only 60% of its weight (a rock in his arms they feel all of):

- It slows him a little: 16 kg in the sack makes him about a tenth slower, a full sack of wood (40 kg) about a quarter.
- Walking and sprinting burn a little more: an eighth more with 16 kg. Sprinting and jumping cost more stamina, and he jumps less high (all of the sack's weight counts for that, so a heavy sack can stop him clearing a fence).
- Like a pack on a long walk, it trains him: his legs grow faster under a load (1.36 times as fast with 16 kg), and his lungs too when he sprints.
- Over 30% of his weight in the sack, he says so: "Oof! This sack is heavy...".

His weight on the screen is his body alone; the load is shown with the sack.

**Food goes off.** In the sack each kind of food loses half its calories in a set time, and its freshness with them: fish, meat and milk in 10 minutes; berries, mushrooms, eggs, fried eggs, grilled fish and roast in 20; pies, muffins and bread in 30 (a nut cake 40); apples, pumpkins and cabbages in an hour; cheese in two. Grain, flour, nuts, honey, salt and butter keep. Once its freshness is under 30% it is thrown out ("Pee-yew! My RAW FISH went bad. Out it goes!"). The sack menu says whether what he has is fresh, a bit stale or going off. As with calories, the sack keeps one freshness for each kind: a fresh apple put in with stale ones makes them a little fresher on average. **A larder** keeps food five times as long (see [Wood and the workshop](#wood-and-the-workshop)).

**Food is scarce.** Of each kind there is never more in the whole meadow than 4,000 kcal's worth, counted at full size (1,200 for mushrooms, which are so light there would be far too many). That is a ceiling, not a promise:

| Food | Where | At most | Comes back |
|---|---|---|---|
| Pumpkins | Two beds in the garden | 10 | A new one sprouts 4 to 9 minutes after one is picked, and takes 5 minutes to grow |
| Wheat | Three small fields | 12 sheaves | Sprouts after 4 to 9 minutes, grows in about 4 |
| Apples | 14 wild apple trees in the forest | 42 (3 a tree, counting those lying under it) | A tree starts a new apple every 2 to 5 minutes; it ripens in about 3 |
| Berries | 40 bushes in the forest | 80 bunches (2 a bush) | A picked bush starts another bunch after 1 to 3 minutes; it ripens in 2 |
| Mushrooms | In the shade of the forest trees | 40 | Sprouts after 1.5 to 4 minutes, grows in under 2 |
| Eggs | Wherever the turkeys are | 10 lying about | A turkey in the wild lays one only every 10 to 20 minutes, a penned one every 1 to 2 minutes (see [Wood and the workshop](#wood-and-the-workshop)); an egg lies for 4 minutes |
| Cabbages | A bed in the garden | 16 | Sprouts after 3 to 8 minutes, grows in 4 |
| Nuts | Little heaps under the forest trees | 22 handfuls | A new heap starts after 2.5 to 7 minutes, and more nuts drop on it for 3 |
| Rock salt | Pink crystals standing on four big grey rocks in the goat hills | 8 lumps, 2 a rock (salt is no energy, so no budget) | A rock grows another lump after 5 to 10 minutes |
| Fish | In the pond | 6 | Another swims in 4 to 8 minutes after one is caught |
| Honey | Three hives in the bee meadow | 6 combs (2 a hive) | The bees fill another comb in 4 to 8 minutes |
| Wood | Fallen branches under the forest trees | 36 branches (not food: see [Wood and the workshop](#wood-and-the-workshop)) | Another falls where one lay 2 to 5 minutes after it is picked up |
| Milk | The five goats | a jug from each | A milked goat has milk again after 3 minutes |
| Meat | Turkeys and goats, once dead | 2 pieces from a turkey, 5 from a goat, 8 from the billy goat | Another turkey takes a dead one's place after 5 to 8 minutes, a goat after 8 to 12, the billy goat after 10 to 15 |

**Things grow, and can be picked too early.** A new piece sprouts small and green, with a quarter of its calories, and grows to full size and colour; picked early it is worth less, and the prompt says what it is worth now ("E: pick it now (164 kcal, still growing)"). Each piece's full size also differs by up to 15% either way, so one ripe pumpkin is 350 kcal and the next 450. At the start of a game everything is at a different stage. The sack keeps the calories of each kind of thing all together, not piece by piece: three apples of 150, 100 and 50 kcal are 300 kcal of apples, and any one of them taken out is worth the average, 100. The sack shows what one piece of each kind is worth, and, for the one chosen in its menu, what it is made of: a bar of its composition, each share in per cent, and what one piece puts into him.

- **Apple trees:** a ripe apple drops now and then, and lies for a minute and a half before it rots. **Bump an apple tree** (or slam an animal or throw one into it) and its apples come down, ripe or not: the harder the hit, the more.
- **A turkey** held by the legs and shaken with `Space` hardly ever lets an egg drop: one swing in a hundred. Eggs come from turkeys laying, and most of them from turkeys in a pen.

**Rabbits and crows eat what is left standing.** Two rabbits live in burrows by the garden and two crows circle over the wheat. Every minute or three one comes out for a crop that is at least 60% grown, far from Prosio, and eats it down over 14 seconds: not away altogether, but back to a much smaller size. Within 50 m he hears it start ("Caw, caw! A crow is at my wheat!"). They run when he comes within about 5 metres, and from his wind. A pebble does it from a distance: a stone passing or landing within 2.5 m sends one off, and it then stays away two and a half times as long. So ripe crops are best picked, or guarded: with a sack of pebbles, with a scarecrow against the crows, or with a fence against the rabbits (see [Wood and the workshop](#wood-and-the-workshop)).

**Pebbles** are for throwing, not eating. Nine patches of them lie about the meadow (three in the goat hills, two on the pond's bank, one each near home, in the forest, by the turkeys and by the fields); `E` takes a handful of three, a patch holds six, and another works its way up every half minute to a minute. See [Grabbing and throwing](#grabbing-and-throwing) for what they do.

**Fish** swim about the pond. They dart away from a pig on the move, but one standing still on the bank makes them curious and they drift over. `F` grabs the nearest if it is within reach (the prompt says when); hit or miss, the splash keeps the rest away for 12 to 22 seconds. With a fishing rod chosen in the sack, `F` casts it instead: it reaches a fish 4 m out (a hoof reaches 1.25 m), and the others take no fright.

**Honey** is in the three straw hives of the bee meadow, `E` to take a comb. Come within 3.6 m of a hive and its bees are after him, a little faster than he walks, stinging every 0.7 seconds (0.1 kg a sting) until he has been out of that 3.6 m for 5 seconds. His wind sends them back into the hive and keeps them quiet for 14 seconds, and well padded he hardly feels the stings (see [Nutrients and water](#nutrients-and-water)).

**Milk** comes from a goat (not the billy goat), one jug every 3 minutes; her udder is round and full when she has some. There are two ways to get it. The gentle one: be salty. A Prosio full of electrolytes draws the goats, who trot up and stand licking the salt off him and have no mind to butt, and `E` beside a licking goat milks her where she stands. The rough one: grab her by the hind legs with `F`, and `E` milks her while he holds on, with the rest of the herd still butting him. There is a third, which takes building: a goat in a pen stands quietly, and `E` beside her milks her.

**Meat** comes from a turkey or a goat that has been knocked out, which now means dead (see [Fighting](#fighting)). The body has to be dragged to the chopping block by the cooking fire, at the pond, and `E` there chops it into pieces of raw meat.

**Some food cannot be eaten as it is.** Raw eggs, raw fish and raw meat have to be cooked on the fire. Wheat has to be ground into flour at the **mill**, a little windmill by the wheat fields: `E` there puts all the wheat in the sack into it, the sails spin while it grinds (2.5 seconds a sheaf), and `E` again takes the flour. Flour cannot be eaten either: it goes into the oven. So bread means a walk to the fields, the mill, and home to the oven.

What each raw food is made of, in shares of its calories, and what one ripe piece of the usual size puts into him (the kilograms are what he gains):

| Raw food | kcal | Carbs | Fat | Protein | Fibre | Vitamins | Electrolytes | One piece puts in |
|---|---|---|---|---|---|---|---|---|
| Bunch of berries | 50 | 76% | 3% | 3% | 4% | 14% |  | 0.24 kg, 7 vitamins |
| Apple | 95 | 86% | 1% | 1% | 5% | 6% | 1% | 0.50 kg, 6 vitamins, 1 electrolytes |
| Mushroom | 30 | 30% | 5% | 40% | 10% | 5% | 10% | 0.16 kg, 2 vitamins, 3 electrolytes |
| Pumpkin | 400 | 82% | 2% | 7% | 4% | 3% | 2% | 2.09 kg, 12 vitamins, 8 electrolytes |
| Cabbage | 250 | 55% | 3% | 15% | 20% | 5% | 2% | 1.75 kg, 12 vitamins, 5 electrolytes |
| Handful of nuts | 180 | 12% | 70% | 12% | 5% |  | 1% | 1.00 kg, 2 electrolytes |
| Jug of milk | 150 | 8% | 48% | 40% |  | 2% | 2% | 0.72 kg, 3 vitamins, 3 electrolytes |
| Comb of honey | 300 | 99% |  |  |  | 1% |  | 1.49 kg, 3 vitamins |
| Lump of rock salt | 30 |  |  |  |  |  | 100% | 30 electrolytes, and weighs nothing |
| Wheat (a sheaf), or its flour | 340 | 82% | 4% | 12% | 2% |  |  | 1.78 kg (not edible until baked) |
| Egg | 130 | 2% | 60% | 34% |  | 3% | 1% | 0.62 kg, 4 vitamins, 1 electrolytes (not edible until fried, or baked) |
| Fish | 200 |  | 25% | 70% |  | 3% | 2% | 0.95 kg, 6 vitamins, 4 electrolytes (not edible until grilled) |
| Piece of meat | 300 |  | 45% | 53% |  | 1% | 1% | 1.47 kg, 3 vitamins, 3 electrolytes (not edible until roasted) |

**The oven** stands at home, by the start: a round brick oven with a chimney. `E` next to it opens its menu (the game waits meanwhile): every recipe, what it needs and what is in the sack, and its calories. `Up`/`Down` choose, `E` or `Enter` bakes, `Esc` closes. Baking takes 6 seconds, with a fire in the oven and smoke from the chimney; then it says "Ding!", and the dish waits in the oven's mouth, where you can see what it is, until Prosio takes it out with `E`, into the sack.

Cooking makes more of the calories in food available to the body, and **the better he is at it, the more**. Each place where food is made has a skill of its own (see [Body and skills](#body-and-skills)), which grows with every dish made there and never fades; what he makes is worth what actually went into it (unripe ingredients make a poorer pie) times a bonus that his skill takes from a beginner's to a master's:

| Where | Beginner | Master | What he is called on the way |
|---|---|---|---|
| The oven | +15% kcal | +80% | Beginner baker, Apprentice baker, Baker, Master baker |
| The cooking fire | +0% | +50% | Beginner cook, Apprentice cook, Cook, Master of the grill |
| The churn | +0% | +25% | Beginner dairy pig, Apprentice dairy pig, Dairy pig, Master cheesemaker |

The menu says it: "Beginner baker: +15% kcal (up to +80%, the more you make)". He is half way to master after 11 dishes in one place and nearly there after 50; an apprentice from a quarter of the way, then the plain title from half way, and a master from 85%. The skill also makes the work quicker, up to twice as fast. With ripe ingredients of the usual size, made by a beginner baker:

| Dish | Needs | Raw | Baked (beginner) | Carbs | Fat | Protein | Fibre | Vitamins | Electrolytes | One puts in |
|---|---|---|---|---|---|---|---|---|---|---|
| Apple pie | 3 apples, 1 flour, 1 egg, 2 logs | 755 | 868 kcal | 70% | 13% | 12% | 3% | 3% | 1% | 4.48 kg, 24 vitamins, 5 electrolytes |
| Pumpkin pie | 1 pumpkin, 1 flour, 1 egg, 2 logs | 870 | 1000 kcal | 70% | 11% | 13% | 3% | 2% | 1% | 5.16 kg, 18 vitamins, 11 electrolytes |
| Berry muffins | 3 bunches of berries, 1 flour, 1 egg, 2 logs | 620 | 713 kcal | 64% | 16% | 14% | 2% | 4% | <1% | 3.59 kg, 29 vitamins, 2 electrolytes |
| Mushroom pie | 3 mushrooms, 1 flour, 1 egg, 2 logs | 560 | 644 kcal | 55% | 17% | 22% | 3% | 2% | 2% | 3.33 kg, 10 vitamins, 12 electrolytes |
| Nut cake | 2 handfuls of nuts, 1 flour, 1 egg, 3 logs | 830 | 954 kcal | 39% | 41% | 15% | 3% | <1% | 1% | 5.05 kg, 4 vitamins, 6 electrolytes |
| Bread | 2 flour, 1 log | 680 | 782 kcal | 82% | 4% | 12% | 2% |  |  | 4.09 kg |

A dish is made of what went into it, mixed by calories (wood, with none, changes nothing), and cooking makes it richer but not different: more of everything in it, vitamins and electrolytes too. The sack keeps a dish's calories as they came out of the oven.

**A fire needs wood.** Every dish from the oven or the cooking fire takes logs with it, more for a bigger dish: one for a loaf or anything on the fire, two for a pie or a tray of muffins, three for a nut cake. They are the last thing in each recipe, and are used up for each one made. The churn and the mill need none. Without wood the menu shows the logs in red and says so.

So a trip to the forest, the fields, the mill and Turkey Meadow for an apple pie is worth more than eating everything raw on the way.

**The cooking fire** is by the pond, with a spit over it and the chopping block beside it, and **the churn** stands in the goat hills. They work like the oven, each with a menu of its own. In all three menus `Left`/`Right` choose how many to make at once (up to nine), as many as the sack has the makings of and room for. The fire takes 4 seconds and the churn 5, whatever the number. A beginner gets just what went in, at either; the table is for him:

| Made | Where | Needs | kcal | Carbs | Fat | Protein | Fibre | Vitamins | Electrolytes | One puts in |
|---|---|---|---|---|---|---|---|---|---|---|
| Fried egg | fire | 1 egg, 1 log | 130 | 2% | 60% | 34% |  | 3% | 1% | 0.62 kg, 4 vitamins, 1 electrolytes |
| Grilled fish | fire | 1 fish, 1 log | 200 |  | 25% | 70% |  | 3% | 2% | 0.95 kg, 6 vitamins, 4 electrolytes |
| Roast meat | fire | 1 piece of meat, 1 log | 300 |  | 45% | 53% |  | 1% | 1% | 1.47 kg, 3 vitamins, 3 electrolytes |
| Butter | churn | 2 jugs of milk | 300 |  | 98% | 1% |  | 1% |  | 1.49 kg, 3 vitamins |
| Cheese | churn | 2 jugs of milk, 1 lump of salt | 330 | 2% | 52% | 37% |  | 1% | 8% | 1.50 kg, 3 vitamins, 26 electrolytes |

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

Prosio becomes what he does. Besides his fat he has **nine traits**: the muscle of his arms and of his legs, four skills of the body, and three of the kitchen. Each is a level that follows what he has been doing lately:

- **Doing the thing trains it.** Each time, the trait gains a share of what it still lacks, so it rises quickly at first and more slowly near the top.
- **What is in his body fades when left alone; what he knows how to do stays.** His muscles and the four skills of the body fade, as in real life: it loses half of what he had built in about 18 minutes of play (only play counts, not time with the game closed). So a habit shows on him after a few minutes, and he cannot keep everything up at once.
- **Muscle is built out of protein, kilogram for kilogram.** Training takes it from the protein in him: with little there it builds little, with none it builds nothing. So a goat's five pieces of roast meat are over 6 kg of muscle waiting to be trained, and a pig that eats no protein stays ordinary however hard he works. When he lacks protein (or is starving) his muscles waste away below their ordinary size, in about 11 minutes, and come back in about 8 once he is fed.
- **Muscle is heavy and hungry.** It adds to his weight, and every kilogram of it burns energy all the time, carbs first and then fat (see [Burning weight](#burning-weight)). Muscle that fades or wastes simply goes, as burned fat does: it is not something to live on.

| Trait | Grows by | At its most | Shows as |
|---|---|---|---|
| Arms (3 kg wasted, 5 ordinary, 12 at most) | holding rocks and animals, dragging, bashing, throwing | he lifts and throws 1.8 times as much (wasted: 0.6 times) | thick or thin arms |
| Legs (5, 8, 18 kg) | sprinting, jumping, long walks, dragging bodies | he walks and runs 1.3 times as fast, and twice the energy goes into a jump, so into a stomp too (wasted: three quarters) | sturdy or thin legs |
| Lungs | sprinting | a sprint costs 55% of the stamina, and breath comes back 1.6 times as fast | a broader chest |
| Hide | taking pecks, butts and stings | he feels half of every knock, on top of what his fat takes | darker, tougher skin |
| Gut | eating fibre | from level 0.4 he holds his wind until `G` is pressed (ready again after 2 seconds), and it reaches up to 1.5 times as far | the fibre bar says "GASSY (G)" |
| Hooves | picking, fishing, milking | picking takes half the time, and he reaches 1.4 times as far for a fish or a leg | quicker stoop |
| Baking (never fades) | baking at the oven | what he bakes is worth 80% more than what went in, not 15%, and is done in half the time | his title at the oven, and on the body panel |
| Grilling (never fades) | cooking on the fire | +50%, not +0%, in half the time | his title at the fire |
| Dairy (never fades) | churning | +25%, not +0% | his title at the churn |

In scripted runs: sprinting half the time with protein kept up took his legs from 8 to 12.6 kg in 5 minutes (walking 5.7 instead of 4.8 m/s after ten); holding a rock of his own weight half the time took his arms from 5 to 8.6 kg in 6 minutes, enough to swing the billy goat.

The **muscle bar** under the fat shows arms and legs together: wasted to the left of the mark, built up to the right. The player does not steer the two separately except by what Prosio does; the body panel of the `M` menu shows each by itself.

## Wood and the workshop

**Wood** is fallen branches: 36 of them lie under the forest trees, pale against the forest floor. `E` puts one in the sack, and 2 to 5 minutes later another has fallen where it lay. No tree is cut down. Wood is not food; it feeds the oven and the cooking fire (see [The sack and the oven](#the-sack-and-the-oven)), and it is what things are built of.

**The workbench** stands at home, across the yard from the oven, on the grass between the paths to the fields and to the garden: a table with a saw and a mallet. `E` there opens a menu like the oven's, with a plan on each line, what it is for and what it takes. Building takes 3 seconds (less with deft hooves), and what was built waits on the bench for `E`.

| Plan | Takes | What it is for |
|---|---|---|
| Piece of fence | 2 logs | `Q` puts it up. Animals cannot get past |
| Scarecrow | 3 logs, 3 sheaves of wheat | `Q` stands it up. Crows leave the wheat within 9 m of it alone |
| Fishing rod | 2 logs | Chosen in the sack, `F` at the pond casts it: it reaches a fish 4 m out, and does not frighten the others |
| Spear | 2 logs, 1 pebble | Chosen in the sack, hold `F` and let go: thrown at what he aims at, it takes far more than a stone, and lies where it lands to be picked up again |
| Gate | 3 logs | `Q` puts it up like a piece of fence. `E` opens and shuts it, even with an animal in his hooves |
| Larder | 4 logs, 2 lumps of salt (to keep the damp out) | `Q` stands it up. `E` opens it: food keeps five times as long in it, and it holds 100 litres |

**He knows every recipe and every plan from the start**, for now. Each one has a flag saying whether he knows it (`knows` in `prosio.odin`, saved with him), and a menu lists only what he knows: so later a recipe or a plan can be something to find first.

**Things that are not food** (wood, pebbles and what he builds) sit in the sack with the food. `Q` on a piece of fence or a scarecrow puts it up; on anything else that is not food he says what it is for. In the sack menu, `E` on such a thing chooses it and closes the menu. A fox never takes one.

**Fences** stand on a grid of two-metre squares that covers the meadow, so that pieces join. With a piece chosen in the sack, a yellow mark on the ground shows where `Q` would put it: across his way, on the line of the grid nearest to the spot just in front of him (red, where it cannot go: on another piece, through a tree, a rock, a building or the pond, or along the meadow's own fence). `F` takes down the piece in front of him, back into the sack, when there is nothing to grab and no pebble or spear is chosen. What a fence does:

- Nothing on its feet gets past it: not an animal, not a rock or an animal sliding along the ground, and not Prosio.
- **Prosio jumps over**, if his jump takes him 0.4 m up. An ordinary pig of 80 kg jumps 0.45 m, so he clears it; much heavier (about 90 kg with his sack), or with cramped legs, he cannot, and is fenced in or out until he takes a piece down with `F`. Strong legs and a light sack help. Facing a fence, the line at the bottom of the screen says which it is ("J: jump over the fence", or "Too heavy to jump the fence!").
- **He lifts a light animal over it.** At a fence, with an animal in his hooves, `F` lifts it over the top rail and sets it down unhurt on the far side, if it weighs no more than 35% of his weight times the strength of his arms: 28 kg for an ordinary pig, so a turkey (16 kg) or a fox (20 kg) goes over, and a goat (55 kg) never does, even with the strongest arms. Too heavy, it is put down on his side ("Way too heavy to lift over! It needs a gate.").
- He cannot jump with an animal in his hooves. A thrown turkey or fox sails over, once it is 0.4 m off the ground; a goat or the billy goat (over 30 kg) bangs into the fence and bounces off. A stone or a spear flies between the rails.
- **A gate** is a piece of fence that opens. `E` at it opens it or shuts it, and works with an animal in his hooves, so he can drag a goat in: open the gate, drag her through, put her down, come out and shut it. It will not shut on anything standing in the gateway. Open, anything goes through; shut, it is fence like the rest. Either way it counts as fence for a pen, so the animals already in a pen stay penned while he brings another in.
- A square of four pieces round Prosio keeps turkeys and goats off him.

**A pen** is any place with fences all round it (the edge of the meadow counts as a fence) and no more than 40 squares inside. An animal that finds itself in one is penned:

- It settles down: it potters about, and neither chases nor butts nor pecks him, even when he walks in.
- It stays, and its pen is its home. A turkey lays far more often than in the wild, an egg every 1 to 2 minutes, in the pen; a goat stands to be milked with `E`.
- It is there next time he plays (the nearest animal of its kind is fetched from the meadow into the pen).
- A gate standing open does not let it out of the pen by itself: it stays put round the middle of it.
- Take a piece out and it is an ordinary animal again, and wanders home. Killed, it comes back where its kind lives, not in the pen.

The way to pen a turkey or a fox is to lift it over the fence (`F` at the fence) or throw it in; a goat is dragged in through a gate. Or build the last piece round any of them.

**A rabbit will not go for anything fenced in**, by the same test: a cabbage with fences all round it is safe. **A crow will not come to wheat with a scarecrow within 9 m.** One on its way to a crop, or at it, when the fence is closed or the scarecrow goes up is off at once.

**The larder** is a wooden cupboard on short legs, with a bag of salt at its foot. `E` at it opens a list of everything in the sack and the larder: `Right` puts one in, `Left` takes one out, `E` moves all of a kind (in, or out if the sack has none), and each row says how fresh it is. Food spoils five times as slowly in a larder; a larder holds 100 litres. `F` takes an empty larder down again (not a full one). Up to four can stand, and they are saved with what is in them. When a larder and the workbench (or the oven) are both in reach, `E` goes to the nearer.

**The spear** is thrown like a pebble (see [Grabbing and throwing](#grabbing-and-throwing)): wind up, aim with the direction keys, let go; a tap is a weak flick. It weighs 1.5 kg, so it leaves an ordinary Prosio's hoof at the same 22 m/s as a pebble, and costs 6 stamina. At that speed it takes 55 of a turkey's 100 health, 40 of a goat's, 28 of the billy goat's and 60 of a fox's; thrown slower, less, by the square of the speed. The animal is not bowled over: it staggers for most of a second, a fox drops what it stole, and the flock takes fright as at any hard blow. Hit or miss, the spear lies where it came down, stuck in the ground, until `E` picks it up.

## Nutrients and water

Four of his parts are **stores** that fill and empty as he eats and lives: carbs, protein, fibre and water. Each has a bar that shows how full it is, and its kilograms. Two more things, **vitamins** and **electrolytes**, weigh nothing but have bars of the same kind. (Fats are not a separate level: the fat he eats is the fat on him.)

- **Eating** fills them with what the food contains (see the tables in [The sack and the oven](#the-sack-and-the-oven)).
- **Carbs** are what his muscles burn, all the time and faster when he works: the more muscle, the faster they go (see [Burning weight](#burning-weight)).
- **The others**, at rest, each lose a thousandth of what is in them every second, so half in about 11 minutes: protein is used up mending him (it counts as burned, for his muscle, and never turns into carbs); fibre passes.
- **Water** runs down steadily: a full drink lasts a good quarter of an hour, less if he sprints. `E` at the pond fills it; food holds no water.

A game starts with everything half full and water at 80%.

**The system is forgiving, and what matters is what he lacks.**

- **Too much of anything never ends the game.** Above 90% a store moves its surplus on six times as fast: too many carbs turn to fat, the rest passes, and a drink at the pond washes out too much fibre, vitamins or electrolytes at once. (Only too much *fat* is dangerous.)
- **Running out of carbs, protein or fibre never ends the game by itself.** His fat keeps him going; he is just the worse for it. But with **no fat and no carbs** he faints.
- **Running right out of water, vitamins or electrolytes does**, but slowly: under 4% (for water: none left) the bar's name blinks and a countdown of **three minutes** runs beside it. Eating nothing at all, that point is over 40 minutes away.
- **What to eat is always on the screen:** whenever he lacks something, a line under the bars says what to eat for it ("EAT: eggs, fish, meat, nuts").

A store between 15% and 70% does nothing. Below 15% he **lacks** it, which is a nuisance. Above 70% he is **full of** it, which is funny and useful as well as a nuisance, so it can be worth eating for. Above 90% it is **too much**: funnier, less useful, and soon over.

| | Lacking it (under 15%) | Full of it (over 70%) | Too much (over 90%) |
|---|---|---|---|
| Carbs | **No fuel:** stamina comes back half as fast, and everything he burns comes off his fat (with no fat either, he faints) | **Sugar rush:** 25% faster, and a sprint costs under a third of the stamina. When it wears off, an 8-second **sugar crash** | **Hiccups:** every few seconds one jerks him into a little jump, while the surplus turns to fat |
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
- **Coming down on an animal** from a jump is a stomp. The blow is **his weight times the height of his jump** (times `STOMP_K`, 1), which is 36 for every Prosio, since a heavy one cannot jump as high. It takes from the animal's health like any other blow (see [Fighting](#fighting)): all of it at 50 for a turkey (two stomps), 110 for a goat and 160 for the billy goat. An animal that still has health left is dizzy for longer the less it has. He bounces off it, and the bounce does not count as another stomp.

## Fighting

The enemies are farm animals gone bad-tempered: big turkeys (16 kg) all over the meadow, in the north-east a few goats (55 kg) led by a billy goat (95 kg, more than Prosio at the start), and in the forest five foxes (20 kg). They have big kawaii eyes. A cross turkey spreads its barred tail fan and frowns; the billy goat is brown, with a shaggy mane, a long beard and great curling horns.

**Every animal has health, and every blow takes from it.** All four kinds have the same measure, 100. Whatever hits an animal takes from it: being thrown, bumped, hit by a rock or by another animal, slammed about while he holds it, stomped on. What a blow takes goes with the square of its speed, measured against how sturdy that kind is: a blow at its sturdy speed (14 for a turkey, 12 for a fox, 5.5 for a goat, 3.5 for the billy goat) takes 28. A heavy animal is the less sturdy because it comes down that much harder. So nothing is settled by one lucky hit: the pig he starts as needs three full throws for a turkey, and the strongest pig there can be still needs two. A hurt animal shows a little bar over it with what it has left, goes slower (down to 60% of its speed), and a turkey loses feathers. Left alone for 8 seconds it starts to mend, 1.2 a second, so a hunt has to be finished or it was for nothing.

| Throwing a turkey, wound up fully | It leaves at | Takes | Throws to finish it |
|---|---|---|---|
| 40 kg, arms wasted | 4.8 | 3 | more than he has breath for |
| 50 kg | 10 | 14 | 8 |
| 80 kg (the start) | 16 | 37 | 3 |
| 80 kg, strongest arms | 22 | 69 | 2 |
| 110 kg | 22 | 69 | 2 |

**They know how dangerous he is.** Each kind sizes Prosio up by what one good throw of his would take from it (his *threat* to it, which goes with his weight and the strength of his arms).

- **A small, weak Prosio they know they can beat**, and they press him harder: up to 30% faster, coming for him from up to 40% further off, more turkeys darting in at once and more often, and knocking him again sooner. This starts when his threat is under 0.16 and is at its worst under 0.04. The pig he starts as is just dangerous enough to turkeys and goats that none of this applies; a pig of 50 kg already has the goats at their boldest.
- **A big, strong Prosio they fear.** From a threat of 0.45 they dart in less, and from 0.75 hardly at all.
- **A hurt flock scatters.** When one of them takes a real blow, each of the others within 11 m runs for it with a chance of 1.6 times his threat (so about six in ten from the pig he starts as, nearly all from a strong one, almost none from a weak one), and keeps away for 6 to 12 seconds. The one that was hit may run too once it is up. Goats and the billy goat are one flock.
- **Far from home they give up.** A turkey that has followed him 30 m from its home, or a goat 26 m, turns back and ambles home for 8 seconds whatever he does. So walking away always works.

**An animal with no health left is dead.** Its body lies where it fell, limp, with little crosses for eyes, for 4 minutes. It goes off as it lies: after 2 minutes flies gather over it, and the longer it has lain, the poorer the meat chopped from it, down to about a third of its calories (and as stale) just before it is gone. `F` takes it by the leg (a turkey is carried by the feet, a goat dragged), and it is as floppy as any held animal: it can still be used as a club, or thrown. Dead weight slows him down: a turkey hardly, a goat to about 70% of his speed, the billy goat to under 60%, and holding it costs stamina. At the chopping block by the fire `E` turns it into meat (see [The sack and the oven](#the-sack-and-the-oven)). Another animal takes its place only after 5 to 15 minutes, so hunting thins the flock, and with it the eggs. A fox with no health left only slinks off for a minute or two. (A fox that cannot get back to its den within 30 seconds eats what it stole wherever it is.)

**Foxes steal.** A fox does not fight. When Prosio comes within 13 m with anything in his sack, it comes up on him from wherever he is not looking, and stands stock still whenever he turns to face it. If it reaches him it takes the richest thing in the sack and runs for its den, where it eats it. A bump, a grab, a stomp, anything that sends it flying, or his wind, and it drops what it took and he has it back; then it keeps away for 25 seconds.

**Turkeys hunt like a pack.** The turkeys near Prosio do not run at him in a bunch. Like wolves round their prey, they spread out round him at about three metres, each taking its own place in the order they already stand (so their paths do not cross), with the places drifting round to his back. From time to time one darts in on a curve, flapping, leading him a little: more likely from behind (55% at each try), less from the side (25%) and rarely from in front (6%), and never more than two at once. After a peck, or a miss, it falls back and circles again. Turkeys go round obstacles they bump into, and if one finds itself wedged in a dead end it turns back and tries the other way.

**Goats butt.** They graze about their patch, and when Prosio comes within about 8 metres they square up to him a few steps off, facing him, then lower their heads and charge in a straight line at where he was (so he can step aside), and back off again.

### Bump

A bump hits with Prosio's momentum, weight times speed. The enemy digs in and absorbs the first part of that (its *grip*); only the rest throws it:

```
launch speed = 0.479 x (Prosio's weight x his speed - enemy's grip) / enemy's weight
```

Measured against a turkey (grip 560, sturdy speed 14). A bump is a blow of the speed it leaves at:

| Prosio | Turkey leaves at | Takes from its health |
|---|---|---|
| 45 kg | 2.8 | nothing: Prosio bounces off |
| 60 kg | 8.1 | 9 |
| 75 kg | 12.9 | 24 |
| 90 kg | 17.0 | 41 |
| 105 kg | 20.5 | 60 |
| 125 kg | 24.2 | 84 |

A goat (grip 450, sturdy speed 5.5) and the billy goat (grip 500, sturdy speed 3.5) need a heavier Prosio to shift at all, but lose more health for the speed they leave at. A bump out of a sprint keeps the extra speed, so it hits harder.

Flying enemies bounce off walls, sail over low ones, and bowl over any enemy they hit.

### Being shoved

An enemy that reaches Prosio shoves him at `31 x enemy's weight / Prosio's weight` (at most 12), takes 12 stamina (more if he is all skin, less if he is well padded or thick-skinned) and knocks a carried rock out of his hands (a held animal he keeps hold of; mid-swing he cannot be pushed off course). After a shove he flashes warm gold and cannot be shoved again for 1.2 seconds (0.9 by animals at their boldest). If his stamina reaches zero he is dizzy for under a second, then gets up with 30 stamina and three seconds of safety, so a crowd cannot pin him down.

**Bruises.** A knock takes no weight off him. It leaves a bruise: 3 points from a turkey, 6 from a goat, 9 from the billy goat and 0.8 from a bee sting, each times how much of it he feels. Bruises come off the top of his stamina: the far end of the stamina bar turns purple and is out of reach until they mend. So a battered Prosio cannot sprint or fight for long, and has to get away. They can take three quarters of the bar and no more: he always has a quarter left to run with. Bruised that far, he is knocked out, and wakes up at home at the same cost as fainting. Before that, from seven tenths of the way, he says he is black and blue.

It takes real, steady pressure. Standing still among six turkeys and doing nothing, the pig he starts as is knocked out after about 45 seconds and a pig of 110 kg after over two minutes; a 40 kg pig lasts under half a minute. Walking away ends it (they give up far from home, see [Fighting](#fighting)).

Bruises start to mend 5 seconds after the last knock: 0.2 points a second, times a half when he lacks protein and vitamins, up to twice with plenty of both. Sixty points go in about two and a half minutes for a well-fed pig, ten for a badly fed one.

## Grabbing and throwing

`F` grabs whatever is within about an arm's length (0.85) beyond touching. Nothing has to be held down: `F` again throws it.

**Into the pond.** An animal thrown into the pond lands with a splash, sits low in the water and paddles for the nearest bank, then climbs out, shakes itself and keeps well away from him for a while. How it fares depends on where it landed and what it is: a fox swims well (1.6 m/s, unharmed), a goat tires (1.1 m/s, losing 3 health a second), the billy goat more (5 a second), and a turkey is no swimmer at all (0.7 m/s, losing 16 a second). So a turkey that lands within about four metres of the bank gets out, wet and cross; one that lands further out goes bottoms up, comically: "Glub glub... oops! Bottoms up!", feet in the air, crosses for eyes, a bubble now and then. It floats slowly to the bank, and its body lies there like any other.

- **Animals.** A turkey is held up by both feet in one hoof, out to his side, and dangles head down, flapping madly (every beat of its wings jerks it about). A goat or the billy goat is caught by both hind legs, a hoof on each, and dragged along behind him as he walks. A fox is held by its tail. With an animal and a rock both in reach, `F` takes the animal; the prompt says which it will be.
  - **`Space`: bash with it.** He swings the animal like a club, roughly the way he is walking, and slams it into the ground in front of him and into anything standing there. Each swing goes a different way: over his head, round his side, or backhand across his front, landing somewhere ahead and a little to either side. Press `Space` again during a swing to queue the next one.
  - **`F`, tapped: put it down.** It is left where he stands, unhurt and a little dazed. This is how to let go of a goat he has milked, or of anything he does not mean to hurt.
  - **`F`, held: wind up; let go: throw.** A bar at his feet fills as he winds up. The throw has 35% of its full speed at first and all of it after a second; then a quick swing over his head, and it flies off the way he is walking.
- **Rocks**, boulders included, are lifted overhead and held there. A tap of `F` puts the rock down in front of him; held and let go, `F` hurls it down in front of him, the harder the longer he wound up, and it skims across the ground.

**A floppy body.** A held animal is not stiff. Its body is a short chain of three points (the feet in his hoof, the middle of its body, its shoulders) that swing, fall and slide on the ground under their own weight, and its back and front halves are drawn between them, so it bends in the middle. Its legs dangle with gravity and trail behind as it moves. While it is still fighting it stands on its feet and scrabbles to get away, with a sudden lunge every second or so; once it has been bashed it goes limp, with a few small pain stars round its head, and it is simply dragged along the grass.

**Dragging is a tug of war.** The held leg is a rope. While it is taut, Prosio and the animal are pulled together, and each gives way by the *other's* share of their weight. An animal on its feet digs in (1.5 times its weight), a limp one slides (0.6 times), and Prosio digs his heels in too (1.5 times his). So a turkey barely slows him down, while the 95 kg billy goat drags an ordinary Prosio about: he leans back with gritted teeth, his free arm flung out, heels ploughing the grass, and keeps facing it while he backs away.

**Rocks heavier than twice his own weight cannot be lifted at all** ("Way too heavy to lift!"). If a rock slips from his hands before he has it up (he runs out of stamina), he can move again at once.

**Only something lighter than 0.9 times his own weight can be swung or thrown**, with ordinary arms. That is any turkey, a goat from about 61 kg, and the billy goat only from about 106 kg. Built-up arms raise that by up to 1.8 times, and wasted ones lower it to 0.6 (see [Body and skills](#body-and-skills)); rocks and throws go the same way. With something too heavy, `Space` is a heave: he strains with all he has, lifts its rear a little, and it answers with a lunge. He can hang on until his stamina runs out or it pulls free.

**`F` always lets go.** A tap puts it down at once. A hold throws it when the button comes up, if he can: if it is too heavy, or he is too tired to throw (a throw costs 4 stamina plus 12 times its weight over his), he puts it down all the same. The prompt at the bottom says what `F` will do. `F` held down from the moment he took hold does not count until it has been let go once, and pressing `F` while a throw is under way changes nothing.

Everything else scales with the *ratio* between the animal's weight and Prosio's:

| | Rule |
|---|---|
| Stamina to grab | 6 + 25 x ratio (at most 31) |
| Stamina drain while holding | 5 per second x ratio, a quarter of that once it is limp |
| A struggling animal pulls free after | 9 s / (ratio + 0.4): about 15 s for a turkey, 6 to 7 s for the billy goat |
| Stamina per bash | 3 + 10 x ratio |
| How long a swing takes | 0.3 + 0.45 x ratio seconds, never under 0.3 or over 0.75, and a throw takes 0.8 of that: a heavier Prosio swings faster, so he hits harder |
| Throw speed | 3.2 x his weight / its weight (at most 22) |

**Bashing.** Each press of `Space` is one swing of a pendulum across his front: from the side the animal is on, round past his front, out to the other side, fastest in the middle. Press again and it swings back. Each swing differs a little: how far out it goes, how high, and how deep it dips in the middle (a deep dip slams it into the ground in front of him). His hoof leads and the animal's body follows on the end of its leg, its front half flopping after it. Hitting the ground hard is a slam (WHACK, THUD, SPLAT...): dust, a little shake, and the animal goes limper.

**The club is floppy.** Whatever it hits is struck as in a collision of two balls, but only part of the swung animal's body is behind the blow (0.6 of its weight, `m'`), and it squashes rather than bounces (restitution `e` = 0.35):

```
struck animal flies off at   (1 + e) x m' / (m' + its weight) x club speed
the club carries on at       (m' - e x its weight) / (m' + its weight) x club speed
```

So a turkey swung into a turkey knocks it at about half the club's speed, mostly sideways (tumbled over, not launched), and swung into the billy goat it only rocks it and bounces back. Small rocks are batted away the same way. Trees and walls stop it with a BONK, and shake the tree. Each slam is a blow to the animal he holds as well: 4 plus 1.2 for each m/s it hit at, 30 at the most, whatever kind it is (his arm sets the speed).

A thrown animal takes a blow of the speed it leaves at (see [Fighting](#fighting)). It is spinning, so at every skip it keeps 82% of its forward speed, bounces back up with 55% of its falling speed, and the spin turns another 18% of the fall into forward speed. It knocks over any other animal it hits, which is a blow to that one too, and bounces off walls, trees and rocks.

**Aiming.** While he winds up a throw (of an animal, a rock or a pebble) he plants his feet, and a yellow arrowhead bobs over what he is aiming at: at first the nearest animal, rabbit or crow in front of him, within 16 m. A direction key moves the aim to the next one that way; with nothing that way, it just turns him to throw at nothing. A stone is thrown to come down on what he aims at, leading it if it is moving.

**Rocks and stones.** Rocks weigh `380 x radius cubed`: about 10 kg for a small one (radius 0.3), 82 kg at radius 0.6, and about 280 kg for the big boulders; a pebble weighs 0.3 kg. He can lift up to twice his own weight. His arms put the same energy into every throw, 8 joules for each kilogram of him (times the strength of his arms), so `speed = square root of (16 x strength x his weight / the stone's weight)`: a heavy rock is a short, slow lob. A light stone would leave faster than an arm can move, so nothing leaves his hoof faster than 22 (times the root of his strength). A thrown rock skims while it is still moving faster than 3, bouncing back with 45% of its falling speed and keeping 80% of its forward speed, shakes a tree it hits (apples come down), and comes to rest as an ordinary rock again. A pebble is lost in the grass where it lands.

What a stone does to an animal it hits is the blow of an animal of that kind landing with the stone's energy, counted twice over because a stone does not give. Since the energy is the same whatever he throws, a rock takes about 23 from a turkey, 43 from a goat and 62 from the billy goat when the pig he starts as throws it at full strength: rocks are for goats. A rock also bowls the animal over. A stone under 2 kg knocks nothing over: a pebble takes 2 or 3 and no more, but it stings, sends the animal running for 3 to 6 seconds, and makes a fox drop what it stole. A pebble costs 3 stamina; a tap of `F` is a quick flick at 35% strength.

| Thrown at full strength, leaves at | 45 kg Prosio | 80 kg | 125 kg |
|---|---|---|---|
| Pebble (0.3 kg) | 22 | 22 | 22 |
| 16 kg rock | 6.7 | 8.9 | 11.2 |
| 130 kg boulder | too heavy to lift (over twice his weight) | 3.1 | 3.9 |

- **A carried rock's weight is his.** It counts when he lands, and it lowers his jump and his speed. A dragged animal stands on its own feet, so it does not count.
- He cannot bump, sprint, eat or pick things up with his hands full, and cannot jump while holding an animal. He can bash on the move, at half speed.

## The meadow

The meadow is 200 by 140 metres inside a fence, more than five times as big as before. Prosio's home is in the middle: a bare yard with the oven, and footpaths winding out from it to each part of the meadow. Each part has its own food, its own look on the ground, and its name in the top right corner while he is in it.

| Where | Which way from home | What is there |
|---|---|---|
| The forest | west | About 155 trees on a darker floor strewn with leaves, all through it, each at least 4.6 m from the next and thinning out towards the edge; a trail from the path from home to three clearings, where the 14 wild apple trees and most of the 40 berry bushes are; mushrooms, heaps of nuts and fallen branches at the foot of the trees; and five foxes |
| The wheat fields | south-east | Three small ploughed fields of wheat, the windmill that grinds it, a few shady trees, and two crows overhead |
| The garden | south | Two beds of pumpkins and a bed of cabbages, and two rabbit burrows |
| Turkey Meadow | north | Open grass, most of the 22 turkeys and their eggs |
| Goat hills | north-east | Dry, stony ground with big rocks and pines, the goats and the billy goat, four big rocks with pink rock salt growing on them, and the churn |
| The pond | north-west | The only water to drink: a round pond with a sandy shore, bulrushes, lily pads and six fish. He cannot walk into it, and an animal never wanders in; but one thrown in lands with a splash and swims for the nearest bank (see [Grabbing and throwing](#grabbing-and-throwing)). The cooking fire and its chopping block stand on the east bank |
| Bee meadow | south-west | Flowers everywhere, a few blossom trees, and three hives |

In between is open meadow with lone trees and rocks, but no food, and a few turkeys wandering about. Animals far from Prosio rest until he comes near.

**Where trees may stand.** The camera always looks from the south and from above, so a tree's leaves hide a strip of ground to the north of its trunk: for a tall tree, from about 4 to 10 metres behind it. Two rules follow, and the meadow is built by them:

- No tree is planted where its leaves would stand in front of something that has to stay in view: a path, a field, the oven, mill, fire or churn, a hive, a salt rock, a berry bush, or food lying on the ground.
- What is put down after the trees (bushes, mushrooms, nuts, branches, salt rocks) goes only where no tree is in front of it. Mushrooms, nuts and branches lie at the foot of a tree on the camera's side, and apples fall on that side of their tree.

The forest trails are the exception: trees may stand in front of them. The forest is trees all through, spaced out rather than in clumps, so a good part of its floor is behind leaves; what makes that work is that **trees turn see-through round him**. A tree Prosio walks behind fades to a see-through pattern where it covers him, pines included, and in the forest the fading reaches further round him, so he sees the ground he is on and what lies there.

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
    kitchen.odin     the sack, calories, recipes and plans, the oven, the fire,
                     the churn, the mill, and their menus and pixel icons
    workshop.odin    wood, the workbench, fences, gates and pens, lifting an
                     animal over a fence, scarecrows, the fishing rod and
                     the spear
    larder.odin      food going off, in the sack and in a larder; the
                     larder, its menu and its picture
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
  check/             the tests: the rules the game must keep, and a bot that
                     plays it (see Testing without playing)
  main_web/          entry point and page for the browser
build_desktop.sh
build_web.sh
tools/               check.sh (the check suite and autoplay), tour.sh (screenshots)
                     and play.sh (a program plays a step at a time)
AGENTS.md            where an agent that tests or plays the game begins
.claude/agents/      the playtester agent
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

There are three tools that test the game by themselves, a way for a program to play it a step at a time, and an agent that uses them all.

**The check suite** plays out the rules the game must keep and prints PASS or FAIL for each (105 of them: weight is always the sum of his parts, `F` always lets go, too much food never ends the game, no tree stands in front of a path or a building, a fox steals and gives back, a pig with no fat left is still there next time, leaving while he lies there does not undo a game over, and so on). It runs the game's own code without a window, far faster than real time. Every rule came from a decision about the design or from a bug that was found; when something new is decided or fixed, add a rule to `src/check/rules.odin`.

```bash
tools/check.sh
```

**Autoplay** lets a bot play for a long while: it wanders, picks food and wood, grabs, throws, stomps, eats, drinks, bakes and cooks, builds at the workbench and puts fences and scarecrows up, all at random. It plays badly on purpose, to go everywhere and press everything. As it plays it watches for what should never happen (his weight not the sum of his parts, a number gone wild, Prosio or an animal inside a rock or beyond the fence, walking and getting nowhere, `F` not letting go, `E` doing nothing, a food over its budget, an animal on its feet getting through a fence), and it counts what did happen. Its report gives the anomalies with when and where, the game overs and their causes, his body every five minutes, the share of the time each store spent lacking or full, what he ate, what he built and penned, what his weight went on (kilograms burned by walking, sprinting, gathering, fighting, knocks, stings and his muscle), and everything he said with how often. Thirty minutes of game time take about half a minute. The same seed always gives the same run.

```bash
tools/check.sh autoplay --minutes 30 --seed 3
```

**The tour** takes about forty screenshots: every part of the meadow, every menu, each whole outfit, and a few unusual states. They go into `build/tour`, with an `index.txt` saying what each should show, a `.txt` beside each picture giving how Prosio is at that moment in numbers, and half-size copies in `build/tour/small`. It takes about a minute and opens a window for a moment for each picture.

```bash
tools/tour.sh
```

**Playing a step at a time** is for a program that can run shell commands but cannot react sixty times a second: any coding agent, whoever made it. The game runs in its own window and stands still until it is sent a command; it then runs that many frames with those buttons down, stops, and says in words what happened. So the player can take as long as it likes over each move, and a person can watch the window.

```bash
tools/play.sh start
```

```bash
tools/play.sh "walk 14 -30" "look" "tap g" "state"
```

```bash
tools/play.sh stop
```

| Command | What it does |
|---|---|
| `step N [hold LETTERS] [tap LETTERS] [until event]` | runs N frames (60 a second, at most a minute's worth), with those buttons held and those pressed on the first frame; with `until event` it stops early when he says something, takes hold or lets go, or the line at the bottom changes. It always stops when a menu opens or closes or the game is over |
| `hold LETTERS N`, `tap LETTERS [N]`, `wait N` | shorter ways of saying the same |
| `walk X Y [sprint] [max N]` | holds the direction buttons towards that place until he is there, is blocked, or the frames run out; it goes straight, not round things |
| `look [R]` | the screen in words: an open menu with its lines and which is chosen, or else Prosio, the line at the bottom, and everything within R metres (animals and what they are doing, food and how grown, bushes, rocks and their weight, the oven and the rest, the pond) with how far and which way each is |
| `state` | his body in numbers |
| `map` | the parts of the meadow and the fixed places, and where they lie from him |
| `shot FILE.png` | a picture of the screen as it stands |
| `pace real` | frames are drawn as they run, so someone watching sees it at the speed of play (`pace fast` goes back) |
| `help` | all of this, and the letter for each button |

The buttons are the game's own, one letter each as in the scripted runs below, plus `p` for the pause menu and `x` to wake up after a game over. Nothing reaches round the rules: `walk` only presses the direction buttons, and a menu has to be worked with the buttons like anyone would. A game played this way never reads or writes the saved game, and takes the same starting options as a scripted run (`--pos`, `--needs`, `--seed`, `--stock` and so on). Everything sent and answered is kept in `build/play/in` and `build/play/out`. `AGENTS.md` at the top of the repository tells an agent that has never seen the game where to begin.

**The playtester agent** is defined in `.claude/agents/playtester.md`. Asked to "playtest the game" in Claude Code, it reads this README as the description of what the game should do, runs the three tools on several meadows, looks at every picture, plays parts of it itself a step at a time, looks into what seems wrong (with small test programs of its own, kept in `build/playtest/`), and writes a report to `build/playtest/`: bugs with how to see them again, odd effects, numbers worth a look, and where this README and the game disagree. It does not change the game. It cannot tell whether the game is fun or clear to a child: that still needs people playing.

### Scripted runs

The desktop build takes options that script a run, save a picture and quit. As it quits it prints how Prosio is at that moment: where he is, what he weighs and each part of it, his levels, traits and stamina, what he carries and says, and what is in his sack. They ignore the real keyboard and use a fixed time step, so a run is repeatable. They neither load nor save the saved game. (The check suite does save, to try saving out, but to a file of its own beside its program in `build/check`.)

| Option | Meaning |
|---|---|
| `--kg 120` | start at this weight |
| `--pos -24 -8.5` | start at this place |
| `--hold ub` | hold buttons from frame 10 |
| `--tap j` | press buttons once on frame 10 |
| `--tap-at 60` | press the `--tap` buttons on this frame instead |
| `--tap2 g --tap2-at 90` | a second set of buttons, on its own frame |
| `--release-at 90` | let go of the `--hold` buttons on this frame |
| `--near fox` | one animal (`turkey`, `goat`, `billy` or `fox`) within reach in front of him, and no others anywhere |
| `--bruises 50` | start bruised: this many points off the top of his stamina |
| `--far` | with `--near`: the animal stands five metres off, out of reach, to throw at |
| `--pebbles` | start with six pebbles, chosen in the sack |
| `--built` | start with things built: a turkey in a pen beside him (its near side a gate), a larder with cheese and fish in it, a scarecrow, a spear in the ground, and a log, a piece of fence, a rod, a spear and a gate in the sack (14 of its 60 litres) |
| `--swimmers` | put a turkey and a goat swimming in the pond, and a drowned turkey floating |
| `--choose Spear` | this is chosen in the sack at the start, if he has any (a thing by its name in the code: `Apple`, `Apple_Pie`, `Wood`, `Rod`...) |
| `--shot name.png` | save a picture, then quit |
| `--frame 150` | which frame to take the picture on |
| `--menu` | show the menu instead of starting the game |
| `--seed 7` | build a different meadow (the game itself always builds the same one) |
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
| Calories, recipes, baking time | `kitchen.odin` (`RAW_KCAL`, `RECIPES`, `STATION_TIME`, `KCAL_PER_KG`) |
| Speeds, sprint, stamina costs and recovery, jump energy | `prosio.odin` (`walk_speed`, `dash_cost`, `JUMP_ENERGY`, ...) |
| How hard bumps and shoves are, enemy weights and grips | `enemies.odin` |
| Throw and bash strength, lift limit, dragging grip, how fast animals go limp, rock weight | `grab.odin` |
| World size, regions, fields, paths, how many trees and rocks | `world.odin` (`WORLD_HALF`, `REGIONS`, `PATH_ENDS`, `build_world`) |
| How often turkeys lay, in the wild and in a pen, the chance of a shaken-out egg | `enemies.odin` (`EGG_EVERY`, `PEN_EGG_EVERY`, `SHAKE_EGG`) |
| How fast each animal swims, how fast it tires or drowns, how low it sits in the water | `enemies.odin` (`SWIM_SPEED`, `DROWN_RATE`, `SWIM_SINK`, `FLOAT_DRIFT`) |
| What lifts over a fence, and what never goes over | `workshop.odin` (`HOIST_SHARE`, `FENCE_HEAVY`) |
| What each thing weighs and how much room it takes, how big the sack is, what a load does | `kitchen.odin` (`ITEM_KG`, `ITEM_LITRES`, `SACK_LITRES`, `BATCH_MOST`), `prosio.odin` (`LOAD_EASE`, `LOAD_TRAIN`, `LOAD_HEAVY`) |
| How fast each food goes off, when it is thrown out, how much longer a larder keeps it and how big it is, how a body goes off | `larder.odin` (`SPOIL_HALF`, `ROTTEN`, `STALE`, `LARDER_KEEPS`, `LARDER_LITRES`, `MAX_LARDERS`, `BODY_FLIES`, `BODY_MEAT_LEAST`) |
| The cooking bonus at each station for a beginner and a master, and the titles | `kitchen.odin` (`COOK_RANGE`, `COOK_TITLE`, `STATION_SKILL`), `body.odin` (`COOK_WORK`, `COOK_QUICK`) |
| Animal health: what a blow takes, how sturdy each kind is, how fast it mends | `enemies.odin` (`ENEMY_HEALTH`, `HARD_BLOW`, `ENEMY_STURDY`, `HEAL_RATE`, `HEAL_AFTER`, `HURT_SLOW`); slams in `grab.odin` (`SLAM_BLOW`, `SLAM_MOST`); stomps in `enemies.odin` (`STOMP_K`, `ENEMY_TOUGH`) |
| When animals are bold or wary, how a hurt flock scatters, how far they follow | `enemies.odin` (`FEARLESS_BELOW`, `RESPECT_ABOVE`, `BOLD_SPEED`, `BOLD_NOTICE`, `WARY_FROM`, `WARY_FULL`, `ALARM_BLOW`, `ALARM_RANGE`, `SCATTER`, `FRIGHT`, `LEASH`, `GIVE_UP`) |
| Bruises: what each knock leaves, how far they can go, how fast they mend | `prosio.odin` (`BRUISE`, `BRUISE_STING`, `BRUISE_FLOOR`, `BRUISE_MEND`, `BRUISE_REST`, `BRUISE_WARN`) |
| Putting down and winding up a throw | `grab.odin` (`WIND_TAP`, `WIND_FULL`, `WIND_LEAST`) |
| How fast rocks and pebbles are thrown, what they do when they hit, how far he can aim | `grab.odin` (`THROW_ENERGY`, `ARM_SPEED`, `PEBBLE_KG`, `PEBBLE_COST`, `STONE_HARD`, `LIGHT_STONE`, `PEBBLE_FRIGHT`, `AIM_RANGE`) |
| Pebble patches: how many and where, how many each holds, how fast they refill | `world.odin` (`PEBBLE_PATCHES`, `MAX_PEBBLES`, `PEBBLE_HANDFUL`, `PEBBLE_REGROW`) |
| How near a stone scares a rabbit or a crow, and how much longer it then stays away | `critters.odin` (`STONE_SCARE`, `STONED_AWAY`, `PEST_HEARD`) |
| How much of each food there can be, and how fast it comes back and grows | `world.odin` (`FOOD_BUDGET`, `MUSHROOM_BUDGET`, `FOOD_REGROW`, `FOOD_GROW`, `APPLE_*`, `BERRY_*`, `UNRIPE`, `SIZE_SPREAD`) |
| How long the mill takes | `kitchen.odin` (`MILL_TIME`) |
| How many logs each dish takes, and what each plan takes | `kitchen.odin` (`RECIPES`: the logs are the `.Wood` each recipe needs) |
| How much wood lies in the forest, how soon another branch falls | `workshop.odin` (`WOOD_LYING`), `world.odin` (`FOOD_REGROW[.Wood]`) |
| The fence grid, how high a jump clears it, how far ahead a piece goes, how big a pen can be, where the workbench stands | `workshop.odin` (`FENCE_LEN`, `FENCE_TOP`, `FENCE_AHEAD`, `FENCE_REACH`, `PEN_MOST`, `MAX_FENCES`, `BENCH_PLACE`) |
| How far a scarecrow guards, how far the rod reaches | `workshop.odin` (`SCARECROW_REACH`, `ROD_REACH`) |
| What a spear does to each animal, what it weighs and costs | `workshop.odin` (`SPEAR_BLOW`, `SPEAR_KG`, `SPEAR_COST`, `SPEAR_STAGGER`) |
| What each food is made of, how big each store is, where lacking, full and too much begin, how fast stores empty, and how strong every effect is | `diet.odin` (`COMPOSITION`, `FIBRE_KCAL`, `VITAMIN_KCAL`, `SALT_KCAL`, `STORE_KG`, `FRAME`, `NEED_*`, `THIRST`, `TOO_LONG`, `DEADLY`, and the numbers under "What full and lacking do") |
| Where the pond is and how big | `world.odin` (`POND`, `POND_RADIUS`) |
| Recipes, where each is made, how long each place takes | `kitchen.odin` (`RECIPES`, `STATION_TIME`, `STATION_BONUS`) |
| Meat from each animal, how long a body lies and how long until another animal comes, milk, how foxes behave | `enemies.odin` (`MEAT_FROM`, `BODY_LIFE`, `RESPAWN`, `MILK_EVERY`, `FOX_NOTICE`, `FOX_REST`) |
| Fish, rabbits, crows and bees | `critters.odin` (`FISH_*`, `PEST_*`, `NIBBLE`, `HIVE_GUARD`, `BEE_*`, `STING_*`) |
| Clothes, whole outfits and their colours, how thick a layer is | `outfit.odin` (`PRESETS`, `SHIRT_LOOK`, `OVER_LOOK`, `LAYER`) |
| Where trees may stand, how many there are in the forest and how far apart, its clearings and trails, how far round him trees turn see-through | `world.odin` (`VIEW_SLOPE`, `FOREST_TREES`, `FOREST_SPACING`, `FOREST_EDGE`, `CLEARINGS`, `CLEARING_RADIUS`, `TRAILS`, `tree_cover`), `draw.odin` (`FOREST_REVEAL`) |
| Salt rocks | `world.odin` (`SALT_ROCKS`, `MAX_SALT`, `SALT_REGROW`) |
| What everything burns | `prosio.odin` (`WALK_BURN`, `GATHER_BURN`, `FIGHT_BURN`, `HURT_BURN`, ...) |
| The sun's direction and how dark shadows are | `platform.odin` (`SUN`, `SHADOW_INK`) and `scene.frag` |
| Colours | `draw.odin`, `ui.odin` |
| Keys | `KEYS` in `platform.odin` |

## Known gaps

- No sound or music.
- A single meadow, and it is not saved: only Prosio is, with what he has built in it.
- The map is only uncovered by walking; there is nothing to buy or find that reveals more of it.
- No goal beyond keeping Prosio healthy; the puzzles of earlier versions are gone for now.
- Rabbits, crows and bees cannot be caught or fought, only chased off (rabbits and crows with a pebble too); fish cannot be seen being carried. A fox gives what it stole straight back to the sack instead of dropping it on the ground.
- Food regrows by itself; there is no sowing or watering yet.
- The nutrient numbers, how fast muscles and skills grow and fade, and the numbers of fishing, bees, pests and foxes, come from scripted runs, not from children playing: they will want tuning.
- Reputation with each kind of animal, rolling in mud and tanning in the sun were ideas for shaping Prosio that are not built.
- Saving in the browser was checked piece by piece (the page's storage code, and the game reading it at start-up), not by playing a whole sitting in a browser and coming back.
- No gamepad or touch controls.
- Linux and Windows builds are untested.
- Text uses raylib's built-in pixel font.
- The game is checked by rules, a playing bot and screenshots (see [Testing without playing](#testing-without-playing)); balance and feel still need real play. In the bot's hands Prosio loses weight steadily: over 30 minutes of constant gathering he went from 80 kg to between 32 and 56 kg, with his carbs lacking or run out about half the time. That was while knocks still burned weight, which was a third of all he burned. Now that they bruise him instead, he ends 30 minutes between 60 and 70 kg, and is knocked out by bruises once or twice on some meadows (the bot walks into every flock). Picking (0.08 kg a time, about a fifth of what he burns) still costs more than a small mushroom or a young bunch of berries gives, and that wants looking at.
- Bruises are not saved: leaving the game and coming back mends them.
- The numbers of animal health, boldness, scattering and bruises come from scripted runs and the bot, not from children playing.
- **Stomping is out of reach for most Prosios.** He cannot come down on an animal unless his jump clears it, and an ordinary Prosio above about 47 kg does not jump high enough to clear even a turkey (a goat needs under 32 kg). The rule above (36 for every Prosio) describes what is meant, not what happens.
- The three-minute countdown when he has run right out of water, vitamins or electrolytes is not saved: leaving the game and coming back starts it again.
- Lines he says when a level crosses a threshold can repeat a lot when it sits right at the threshold ("Uh oh... I feel gassy!" up to 73 times in 90 minutes of the bot's play), and "So hungry..." repeats every 3.5 seconds for as long as he is starving.
- A fence is only fences: a gap closed by a boulder or a tree is still a gap to the pen test, though no animal can get through it.
- Penned animals need no feeding, and the billy goat cannot break a fence.
- A gate opens only when he faces it from a step away: standing in the gateway, he has to step back first.
- Every recipe and plan is known from the start; nothing yet teaches him one.
- Tools do not wear out, the rod has no line or bait to run out of, and a spear left lying when the game is closed is lost.
- The numbers of the workshop (logs per dish, what each plan takes, what a spear does, how far a scarecrow guards), the sack's 60 litres and what each thing weighs and takes up, how fast food goes off, and how fast animals swim and drown are first guesses, not tuned by play.
- Food in the sack goes off by the clock of play only; nothing goes off while the game is closed.
- A dead body in the water floats straight to the nearest bank, through lily pads and all; the pond has no current. The bot gathers wood, builds, and puts fences up at random, but never builds a whole pen: pens are covered by the rules only.
- The story is deliberately not written yet.
