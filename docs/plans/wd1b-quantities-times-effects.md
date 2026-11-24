# [WD 1b] Mixing from real quantities: times, temperature, microorganisms and computed effects

**Status:** agreed with Gio on 2026-11-24, point by point (his decisions are marked **Gio**). This replaces sections 1, 3 and 4 of [wd1-mixing-and-book.md](wd1-mixing-and-book.md); the bowl by the oven, the editor, the book and the order of building in that document stand. The numbers here are starting values worked out on paper, to be tuned against the reference bowls of section 9. **Step 1 is built** (2026-11-24): the rules in `src/game/mixing.odin`, their numbers in `data/tuning/food.json` (`MIXABLE`, `NUTRIENT_KCAL`, the `mixing` section), their rules in `src/check/rules.odin` (every row of section 9 holds), tried with `tools/check.sh mix`.

## Why the first version is replaced

Step 1 was built on points (wet 3, binding 1...) added up and compared with fixed lines. A walk over every bowl showed what that gives: one egg in eight waters is an omelette, three honeys bake into a custard, flour with eight apples is charcoal. And the points are a second set of books beside what each food is made of.

**Gio:** quantitative properties, and final effects (safety, taste, consistency, wetness...) that are functions of them. The player sets, and tunes, a **mixing time**, a **cooking time** and a **temperature** for each thing he makes; the best values are well-parametrized functions of the proportions of the ingredients, so that he learns to cook each food properly. **Microorganisms** are counted as a quantity that changes with time, so the game knows whether a thing is safe after a given time at a given temperature.

## 1. Units (Gio)

| What | Measured in |
|---|---|
| Anything measured: flour, honey, butter, cheese, fruit, vegetables, nuts, meat, fish | grams |
| Liquids: water, milk | millilitres |
| Eggs | by number |
| Seasoning: salt, chili pepper | pinches |

A pinch is a fixed few grams (a number in the data). How the sack holds grams and millilitres is for step 2; the rules take amounts.

## 2. What a thing is made of

One set of books. An amount of anything is its weight, split into **water, starch, sugar, fat, protein, fibre, salt**. Fat, protein, fibre, salt and the carbs (starch and sugar together) come from the composition the game already has; two numbers for each food are new: the share of its weight that is water, and the share of its carbs that is sugar.

Four qualities are not weight:

| Quality | What it is |
|---|---|
| Acid | how sour |
| Heat | how hot to the tongue: chili |
| Setting | how much of its protein holds a shape when worked or heated (egg: all; flour: half, and only with water and mixing; meat: hardly any) |
| Microorganisms | how many it starts with (section 5) |

A thing that stays in pieces in a mix (fruit, vegetables, nuts, cheese, meat, fish) is a **filling**: only part of its water is free to wet the mix, more once it is heated.

Starting values:

| Thing | Water | Sugar share of carbs | Acid | Heat | Setting | Starts with | Filling |
|---|---|---|---|---|---|---|---|
| Water | 100% | | | | | few | |
| Milk | 88% | 100% | | | 0.1 | some | |
| Flour | 12% | 2% | | | 0.5 | some | |
| Egg (60 g) | 75% | | | | 1 | many | |
| Honey | 18% | 100% | | | | none | |
| Butter | 16% | | | | | few | |
| Salt | 0% | | | | | none | |
| Chili pepper (new) | 10% | 30% | | 1 | | none | |
| Cheese | 40% | | | | 0.3 | few | yes |
| Berries | 85% | 90% | 0.3 | | | few | yes |
| Apple | 85% | 90% | 0.2 | | | few | yes |
| Pumpkin | 90% | 50% | | | | few | yes |
| Cabbage, mushroom | 92% | 40% | | | | few | yes |
| Nuts | 5% | 30% | | | | none | yes |
| Fish | 75% | | | | 0.1 | very many | yes |
| Meat | 70% | | | | 0.1 | very many | yes |

Chili pepper is a new ingredient (**Gio**: for funny effects, such as burning gases and effects on animals). Where it grows and what it does to him and to animals is for a later step; the rules only carry its heat through to the dish.

## 3. What is done to it

**Mixing, for a time.** It brings the bowl together and develops the flour (worked with water, flour's protein starts to hold).

| Mixed | What it does |
|---|---|
| Too little | lumpy; a dough that will not hold and bakes dense |
| About right | even; a dough springy, a batter smooth |
| Too much | a dough is still fine; a batter turns tough |

The **best mixing time** is a function of the proportions: long for a bowl that is mostly flour and water, short for one rich in fat, sugar and egg, shortest for a drink.

**Heating, at a temperature, for a time.** Heat dries the thing, sets what can set, kills microorganisms and makes more of its energy available; past a point it burns. The two settings do different things:

- **Temperature** decides how fast the outside browns and burns.
- **Time**, at that temperature, decides whether the middle is done.

| | What it is |
|---|---|
| Too hot and too short | burnt outside, raw in the middle |
| Too cool | dried out before it browns |
| Far too little of both | raw: the microorganisms are still there |
| About right | done |
| Too long | dry and hard |
| Far too long, or far too hot | burnt: charcoal |

The **best temperature** and the **best cooking time** are functions of the proportions and the amount: longer for more of it and for more water to drive off; hotter for a bread dough, gentle for an egg mix (too hot and it curdles); sugar burns at a lower heat and sooner, fat forgives. The oven's temperature is chosen; the fire has three heights for the spit (low, middle, high), each a temperature.

So charcoal and the brick are not special cases. Charcoal is anything cooked far too long or far too hot. A brick is a slop or a dough baked until it is dry right through. **Neither can be eaten (Gio)**; they keep their weight.

**Wood (Gio):** what a bake or a grilling burns goes with its temperature and time, but it should be almost nothing to think about: a small number.

Every constant in these functions is a named number in `data/tuning/food.json`.

## 4. What it comes out as

**A mix is named by its consistency and what is in it.** Consistency comes from the free liquid in it (free water, with fat counting for half), as a share of its weight:

| Consistency | Free liquid | With flour | Without |
|---|---|---|---|
| Crumbly | under about 28% | Crumbs | Salad if it has pieces, else Mush |
| Kneadable | to about 50% | Dough | Mush (a paste) |
| Pourable | to about 72% | Batter if enough in it sets, else Slop | Egg mix if enough sets; Soup if it has pieces; else Mush |
| Runny | over that | Slop | Egg mix if enough sets; Soup if it has pieces; else Drink |

Nine kinds of mix: the eight already built and **Soup** (liquid with pieces in it; it wants a pot, which comes later).

**Heated, it is named as before** (Bread, Pie, Flatbread, Cake, Muffins, Pancake, Custard, Omelette, Porridge, Crackers, Baked, Grilled, Mush), with how well it was cooked on top: an underdone cake is still a cake, raw in the middle. Anything burnt is Charcoal; a slop or a dough dried right out is a Brick. A drink in the oven boils away, and on the fire runs through the grill.

## 5. Microorganisms (Gio)

One count for a thing, on a scale of tens (10, 100, 1,000...). It replaces both "freshness" and "raw".

- **It starts** where the food starts (the table in section 2).
- **It grows with time**: faster the warmer the place the food is kept, hardly at all in the cold; and slower the less free water the food has. Salt, sugar and acid each tie water up, so dry, salted, sugared and sour things grow almost nothing.
- **Heat kills it**, by temperature and time together: next to nothing below about 60 degrees, quickly above.
- **Safety is the count when he eats it.** Under a line, nothing happens. Over it, a tummy ache, longer and worse the higher the count. Far over, he will not eat it ("Pee-yew!").

**Going off no longer takes calories (Gio).** Old food is as rich as fresh, and unsafe.

What follows without a rule for each: "cooked through" and "safe" are the same sum; a larder is a cool place; winter keeps food and summer spoils it; salted meat and jam keep; meat that has started to turn can be saved by cooking it well.

## 6. Effects, each worked out from the above

| Effect | From | What it does |
|---|---|---|
| **Safety** | the count of microorganisms when eaten | none, or a tummy ache by how far over the line |
| **Taste** | the balance of sugar, salt, acid, fat and heat; lumps; burning | what he says, a short lift when it is good, half of it spat out when it is awful. Later: what each animal makes of it |
| **Consistency** | liquid, setting and fat after cooking | runny, soft, firm, hard or brittle |
| **Keeping** | free water, with salt, sugar and acid tying some up | how fast microorganisms grow in it |
| **Energy** | how well mixed and how well cooked | how much of the station's cooking bonus it gets: all when both are right, none when neither is. The bonus itself still grows with his skill |
| **Weight** | what is left when water has gone | bread is lighter than its dough |
| **Hardness** | water and setting after cooking | a brick is a stone. The number building will use too |

Sugar, salt, fat and fibre keep acting on his body through what the dish is made of, as today.

## 7. How the player learns

- **Before:** the editor shows what the bowl is like (how wet, how sweet...) as things go in. Not what it will become.
- **After:** he says what was wrong, by the worst of it: "Lumpy...", "Tough as a boot!", "Still gooey in the middle.", "Dry as dust.", "Burnt!", or "Just right!". The book notes it with the times and temperature he used.
- **With skill (Gio):** the editor shows an interval for the mixing time, the cooking time and the temperature. It is wide for a beginner and narrows towards the best value as his skill at that place grows. The best value must not sit in the middle of the interval, or the middle gives it away: where it lies inside is different for each recipe, and always the same for the same recipe.

## 8. Waiting (Gio)

- **The timer stops by itself** at the time he set. The dish waits; it does not go on cooking.
- **The dial shows cooking minutes** ("40 minutes at 200 degrees"), but **the wait is short**: about a quarter of a real second for a dial minute, so a bread waits about 10 seconds and nothing more than about 20. Mixing takes 1 to 3 real seconds.

## 9. Reference bowls

Mixed and cooked at their best settings unless said. The constants are tuned until these hold.

| Bowl | Must come out as |
|---|---|
| 500 g flour, 300 ml water | Dough; Bread in the oven, Flatbread on the fire |
| the same, with 100 g cheese | Dough; a Pie |
| the same dough, cooked three times too long | Charcoal on the fire; a Brick in the oven; neither can be eaten |
| the same dough, far too hot for a third of the time | burnt outside, raw in the middle: unsafe |
| the same dough, a third of the time | Bread, raw in the middle: unsafe |
| 250 g flour, 1,000 ml water | Slop; Porridge on the fire |
| 500 g flour | Crumbs |
| 250 g flour, 2 eggs, 300 ml milk | Batter; Cake, Pancake |
| the same, mixed three times too long | a Cake that is tough |
| the same, with 150 g berries | Batter; Muffins |
| 3 eggs, 100 ml milk | Egg mix; Custard, Omelette |
| the same, far too hot | curdled: poor consistency |
| 1 egg, 2,000 ml water | Drink |
| 300 g honey | Mush |
| 400 g fish, 500 ml milk | Soup |
| 500 g flour, 300 ml water, 3 pinches of chili | Bread, with its heat carried through |
| 300 g meat grilled, kept a day in the warm | unsafe |
| the same, kept a day in the cold | safe |
| 300 g meat with 10 pinches of salt, grilled | keeps several times as long as the plain one |
| 200 g berries, 200 g honey, heated | keeps far longer than berries |
| 300 g meat left raw a day, then grilled well | safe again |

Best times and temperatures must also move the right way: more of the same bowl takes longer; more water takes longer; more sugar wants less heat; a dough's best mixing time is several times a batter's.

## 10. After the rework was built: Gio's direction (2026-11-24), not yet in the rules

The game should teach children things, so some things are to be realistic:

- **Raw milk gives him belly trouble.** He can drink it, with consequences; better to boil it in a pot. The same for any other raw food (meat and so on). So raw milk stays unsafe as built, and a pot is needed.
- **Salad** is anything with a certain amount of water and at least a certain share of vegetables (say 70%). It is eaten fresh: cooked, the water in the vegetables turns it into a very bad thing. **Vegetables should be washed.**
- **Water content belongs in food**, kept fairly realistic: without it there are no sound rules for soups, mush and salads.

Open after this (planning session's questions to Gio): whether firm vegetables (pumpkin, mushroom) roast well while leafy ones do not; whether fruit counts towards a salad; what needs washing and where; whether the water in food also waters him when eaten; and real weights for the calorie-dense foods.

**Gio's answers (2026-11-24):**

- Vegetables are **leafy or firm**; only leafy ones are ruined by dry heat. The game needs more leafy ones.
- **New foods**, taking Polish (Slavic) cooking as the base: potatoes, onions, cucumbers, tomatoes, carrots (also to lure rabbits), cauliflower, radicchio, aubergines, zucchini. Fruit: lemon, orange, peach, pear, banana.
- **Mushrooms are brown**, not red with white dots.
- **Fruit counts towards a salad.**
- **The water in what he eats waters him**, in proportion to the food's water content.
- **Real weights against real calories** is an important question, to be discussed separately.

**Decided with Gio later the same day (2026-11-24), not yet in the rules:**

- **Food is real:** real calories to the gram for every food; how much one pick gives is chosen for balance. Prosio is an animal with an extremely efficient metabolism: 200 kcal change him by a kilogram.
- **Shaping** is a step of its own, with a few shapes (flat, wrapped, layered, strips, lumps), so that pierogi, tortellini, lasagne and gnocchi can be told from a pie; they go among the hidden recipes.
- **Fermenting** ("leave to stand"), starting with ogórki kiszone and kapusta kiszona; grapes, and wine, whose effects on him are negative and comic (dehydration, dizziness, erratic movement he cannot control).
- **More foods:** beetroot, dill, plums, cherries, grapes, with the list above. Each grows in the biome whose climate and soil suit it (a hot one for citrus and bananas).
- **How long meat and fish keep** (Gio's targets, to tune the microorganisms to):

| | At 24 degrees | At 4 degrees |
|---|---|---|
| Raw | must be cooked the same day | good for 2 days |
| Cooked | good for 2 days | good for a week |
| Heavily salted, or frozen | months | months |

**Gio, 2026-11-24 (evening), not yet in the rules:**

- **A stomach limits how much he eats at once, by volume.** For simplicity the volume of a meal is its weight times a number `k`, tuned to make things work.
- **Eggs are protected by their shell** and keep two weeks.
- **Meat yields:** realistic, but balanced for the game (the planning session proposes numbers).
- **Freezing** is a pit or cellar he builds and fills with ice cut in winter, or a naturally cold place in a cold biome.
- **Every parameter must be tunable, well commented, and in the parameter files**, so that he can change them without touching the code.
