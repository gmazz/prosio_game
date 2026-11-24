# [WD 1c] Real food: the second round of the mixing rules

**Status:** for Gio to review (written 2026-11-24). Everything in it was decided with him that day, except what is marked *proposed*. **Built as rules** (2026-11-24): `src/game/mixing.odin`, its numbers in `data/tuning/food.json` (each with its explanation), its rules in `src/check/rules.odin` (every row of section 7 holds, and wd1b's with two restated: grilled meat "a day in the warm" is three days at 24 degrees, and raw meat "left a day" is half a day, since Gio's table here spoils raw meat in a day), tried with `tools/check.sh mix` (`--wash`, `--press`, `--shape` and `--fill`, `--boil`, `--stand` and `--air`). The piece weights of section 1 are in the game, with the mushroom (140 g) and the pumpkin (1.5 kg) made real too.

It builds on what stands in the game's rules today ([wd1b](wd1b-quantities-times-effects.md): amounts in grams and millilitres, mixing time, cooking time and temperature, microorganisms, seven computed effects, `tools/check.sh mix`). Like that round, **this one is rules and data only: no screen, and the game plays as before**, with one exception named in section 1.

**The principle (Gio):** the game should teach children real things, so food is to be realistic where it can be.

## 1. Real calories to the gram

Every food gets its real calories to the gram. How much one pick gives is chosen so that a pick is worth what it is worth today, so the day's budget is untouched. For most foods nothing changes; the dense ones get lighter:

| Food | A piece today | A piece from now on | kcal |
|---|---|---|---|
| Flour (from one sheaf) | 500 g | 100 g | 340 |
| Nuts, a handful | 100 g | 30 g | 180 |
| Honey, a piece of comb | 500 g | 100 g | 300 |
| Meat, a cut | 500 g | 190 g | 300 |
| Milk | a jug of 1 litre | a mug of 220 ml | 150 |
| Cheese, butter | 600 g, 500 g | about 95 g, 42 g | 330, 300 |
| Egg (a turkey's) | 60 g | 90 g | 130 |
| Fish | 400 g whole | 400 g whole, 200 g to eat | 200 |

Inside a food, carbs and protein are 4 kcal to the gram, fat 9, fibre 2, as in life.

**The one thing the player sees change:** these things weigh less in the sack.

**What stays unreal, on purpose:** Prosio is an animal with an extremely efficient metabolism. 200 kcal change him by a kilogram (a real body needs about 7,700), which is why his shape changes in days. So a meal can put more weight on him than it weighs. The README's "he gets heavier by exactly what the food weighs" goes; the books balance in energy.

## 2. The foods

Each food that can go in a bowl has: its share of water, calories to 100 g, what its calories are made of, the share of its carbs that is sugar, how sour, how bitter, how hot, how much of its protein sets, what it starts with in microorganisms, and these marks:

| Mark | Means |
|---|---|
| Leafy / firm | a leafy vegetable is ruined by dry heat; a firm one roasts well |
| Fruit | counts with vegetables towards a salad |
| Grows in the ground | has soil on it: wants washing |
| Wants cooking | raw it is hard to digest (potato, aubergine): poor taste and a tummy ache |
| In pieces | stays whole in a mix (a filling) |

**New foods**, as data for the rules only (putting them in the meadow is a later slice). Water and calories are real figures; the rest the dev session fills in from ordinary nutrition tables and reports back for review.

| Food | Kind | Water | kcal to 100 g | What it brings |
|---|---|---|---|---|
| Potato | firm, in the ground, wants cooking | 79% | 77 | starch: mashes, thickens |
| Onion | firm, in the ground | 89% | 40 | strong taste |
| Carrot | firm, in the ground | 88% | 41 | sweet; rabbits love it |
| Beetroot | firm, in the ground | 88% | 43 | sweet; colours everything |
| Cucumber | firm | 96% | 15 | nearly all water; for pickling |
| Tomato | firm | 94% | 18 | sour, juicy |
| Cauliflower | firm | 92% | 25 | |
| Aubergine | firm, wants cooking | 92% | 25 | |
| Zucchini | firm | 95% | 17 | |
| Radicchio | leafy | 93% | 23 | bitter |
| Dill | a herb, by the pinch | | | taste; for pickling |
| Lemon | fruit | 89% | 29 | very sour |
| Orange | fruit | 87% | 47 | sour and sweet |
| Peach | fruit | 89% | 39 | |
| Pear | fruit | 84% | 57 | |
| Plum | fruit | 87% | 46 | |
| Cherry | fruit | 82% | 63 | |
| Grapes | fruit | 81% | 69 | much sugar: for wine |
| Banana | fruit | 75% | 89 | sweet and starchy: mashes |
| Chili pepper | by the pinch | | | heat |

Cabbage is leafy; pumpkin and mushroom are firm. **Mushrooms are brown** (red with white dots is the poisonous one): that is a picture, for the world slice.

**Bitter** is a new taste beside sweet, salty, sour and hot. Burning adds to it.

## 3. What a bowl is

| Kind | What it is |
|---|---|
| Crumbs, Dough, Batter, Slop, Egg mix, Drink | as built |
| **Salad** | at least 70% vegetables and fruit by weight, raw. It is a dish as it stands: eaten fresh, never cooked |
| **Pieces** | things in pieces that are not a salad: a cut of meat, a fish, cheese, nuts, with or without seasoning |
| **Soup** | liquid with pieces in it |
| **Mush** | only what has no pieces and fits nothing else |

**A salad** is as good as it is fresh and washed. Heated dry (oven or fire), its leafy part goes limp and wet and spoils the whole in proportion: all leaves, a **Soggy mess**; all firm vegetables, **Baked** or **Grilled** vegetables, which are good. In a pot with water it is a soup.

## 4. What he can do to it

| Doing | With | New? |
|---|---|---|
| Wash | water | new |
| Mix, for a time | the bowl | as built |
| Shape | his hooves | new |
| Bake, at a temperature for a time | the oven | as built |
| Grill, at a height for a time | the fire | as built |
| Boil, for a time | a pot of water on the fire | new |
| Leave to stand, for days | a crock | new |

**Washing** takes most of the soil's microorganisms off (to a hundredth). Anything that grows in the ground wants it; unwashed in a salad, it gives him a tummy ache.

**Shaping** a dough, before it is cooked:

| Shape | Baked | Boiled |
|---|---|---|
| A loaf (no shaping) | Bread | a Boiled lump (poor) |
| Flat | Flatbread; with things on top, a Pie | |
| Wrapped round a filling | a Pasty | **Dumplings** |
| Layered with a filling | a **Layered bake** | |
| Strips | Crackers | **Noodles** |
| Small lumps | Rolls | **Small dumplings** |

A thin shape cooks faster than a loaf of the same weight. The names are plain on purpose: pierogi and tortellini (dumplings), lasagne (a layered bake) and gnocchi (small dumplings of potato and flour) are **hidden recipes**, found by making the right things in the right shape, cooked the right way.

**Boiling** is at 100 degrees, in water, for a time. Nothing burns in a pot while there is water in it; too long and things fall apart, too short and the middle is raw. In a pot: a soup stays a soup, a slop is porridge, a drink is a hot drink (boiled milk is safe), an egg is a boiled egg, pieces with water are a soup. Without a pot, as before: a drink is lost in the oven and on the fire; a soup loses its liquid and its pieces are baked or grilled.

**Leaving to stand** (fermenting), with three things to learn: how much salt, how warm, how long.

| In the crock | Left | Becomes |
|---|---|---|
| Vegetables in salted water, about 2 to 5% salt, 15 to 25 degrees | 3 days or more | **Pickles** (cucumbers: ogórki kiszone; cabbage: kapusta kiszona): sour, and they keep for months |
| The same, too little salt | | rots |
| The same, too much salt or too cold | | nothing happens |
| Sweet juice, no salt | days | **Wine**: its sugar turns to alcohol |
| Wine, left longer with air | more days | **Vinegar**: its alcohol turns to acid |

So **acid** and **alcohol** are quantities that grow with time in a crock, as microorganisms do, and the same sum says whether it worked. Sour milk and cheese by standing can come later the same way.

**Alcohol** is a part of a food, in grams. Heat drives it off: a sauce cooked with wine has little left. What it does to him (he gets thirsty, dizzy, and for a short while walks where he does not mean to; never anything useful; the same glass hits a light pig harder than a heavy one) belongs to the step that puts this in the game.

## 5. Microorganisms, tuned to how long things really keep

Two lines on the count:

- **Unsafe:** over it, a tummy ache, worse the higher.
- **Spoiled for good:** over it, it stinks, cooking does not save it, and he will not eat it.

Growth is slower in the cold but does not stop; below freezing it stops. Salt, sugar and acid tie up the water it needs.

**Gio's targets**, which the numbers are tuned to:

| | At 24 degrees | At 4 degrees |
|---|---|---|
| Raw meat or fish | must be cooked the same day | good for 2 days |
| Cooked meat or fish | good for 2 days | good for a week |
| Raw milk | unsafe as it comes (he can drink it, with a tummy ache); boil it the same day | |
| Eggs in the shell | 2 weeks | longer |
| Heavily salted, pickled, or frozen | months | months |

A "day" here is a day of the game (60 minutes of play). Eggs are protected by their shell until they are cracked into a bowl.

## 6. Every number in the parameter files, with its explanation

**Gio:** every parameter is tunable, well commented, and in the parameter files, so that he can change it without touching the code.

Checked on 2026-11-24: all 78 constants of the mixing rules are in `data/tuning/food.json`, but 39 have no explanation. So:

- Every value in `data/tuning/*.json` gets a line saying **what it is, its unit, and which way to turn it** ("raise it and bread needs longer in the oven").
- A rule in the check suite fails if any value has no such line.
- No number that shapes the rules stays in the code. (Powers of ten, grams to the kilogram and the like are not tuning.)

## 7. Reference bowls added

The 21 of wd1b stay, restated in the new piece sizes where they change. Added:

| Bowl, and what is done | Must come out as |
|---|---|
| 300 g cabbage, 100 g carrot, washed | Salad; safe |
| the same, not washed | Salad; a tummy ache |
| the same, baked | a Soggy mess |
| 400 g pumpkin, 100 g onion, baked | Baked vegetables: good |
| 300 g cabbage, 100 g carrot, 500 ml water, boiled | Soup |
| 200 g apple, 100 g pear, 100 g plum | Salad |
| 300 g cabbage, 200 g cheese | Pieces (under 70% vegetables), not a salad |
| 200 g meat, 2 pinches of salt, grilled | Grilled |
| 200 g potato, raw | wants cooking: a tummy ache |
| 200 g potato, boiled | good |
| 250 ml milk, drunk as it comes | a tummy ache |
| 250 ml milk, boiled | safe |
| 100 g flour, 60 ml water, wrapped round 60 g cheese, boiled | Dumplings |
| the same, baked | a Pasty |
| 100 g flour, 1 egg, strips, boiled | Noodles |
| 150 g potato, 50 g flour, small lumps, boiled | Small dumplings |
| 100 g flour, 60 ml water, layered with 150 g tomato and 60 g cheese, baked | a Layered bake |
| 500 g cucumber, 500 ml water, 15 g salt, a week at 20 degrees | Pickles; keep for months |
| the same with 2 g salt | rots |
| 500 g grapes pressed, 10 days at 20 degrees | Wine: alcohol in it |
| that wine, boiled 20 minutes | almost no alcohol left |
| that wine, a month more with air | Vinegar |
| raw meat, a day at 24 degrees | spoiled for good; grilling does not save it |
| raw meat, 2 days at 4 degrees, then grilled | safe |
| grilled meat, 2 days at 24 degrees | still safe; a third day, not |
| grilled meat, a week at 4 degrees | still safe |
| an egg, 2 weeks at 24 degrees, then cooked | safe |
| meat frozen 3 months, then grilled | safe |

## 8. The command

`tools/check.sh mix` learns the new things, so any of it can be tried from a shell:

```
tools/check.sh mix "300g cabbage, 100g carrot" --wash
tools/check.sh mix "100g flour, 60ml water" --shape wrapped --fill "60g cheese" --boil 8
tools/check.sh mix "500g cucumber, 500ml water, 15g salt" --stand 7 20
```

## 9. Where the rest of what was decided goes

Not in this round:

| What | Where |
|---|---|
| The stomach, meat yields and how slowly animals come back, the water in food watering him, what he burns, how fast the meadow regrows | [wd2, the day's budget](wd2-day-budget.md) |
| The bowl, pot and crock as places; the bucket; the editor with its skill intervals; the sack holding grams; what alcohol and chili do to him | step 2 of mixing: making it in the game |
| The book, names, hidden recipes and their protection | step 3 of mixing |
| The clock, day and night, seasons | the clock slice |
| A map about a kilometre across; biomes by climate and soil; each food growing where it belongs; growing food himself; the ice house | the world slice |
| Parts, the height grid, the support rule, wheels, saved designs | the building slices |
