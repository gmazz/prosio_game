package game

// Made by tools/gen_data from data/tuning/food.json: do not edit; edit that file.

// Everything that goes in the sack: what each thing weighs, the room it takes, its calories, what it is made of and how fast it goes off; the sack; and what each place makes, from what, and how long it takes.

// ---- sack ----
// calories eaten for each kilogram he puts on
KCAL_PER_KG :: f32(200)
// The sack holds SACK_LITRES, whatever is in it: each thing takes up the room in ITEM_LITRES, and weighs ITEM_KG, which he carries. It is meant to be roomy: a whole pen's worth of wood, or a day's food, goes in at once. What it weighs has no limit but his back: a load slows him a little, makes walking, sprinting and jumping cost a little more, and trains his legs (and his lungs, sprinting) faster, as a pack does (see load_share).
SACK_LITRES :: f32(60)
// of one dish at once
BATCH_MOST :: 9

// ---- things ----
// Each thing that can be in the sack.

// What one of each thing weighs, kg. A food's is its real weight for its calories (RAW_KCAL), at its real calories to the gram (see NUTRIENT_KCAL); a fish is weighed whole, half of it eaten (MIXABLE waste). Raise one and he carries more for the same food.
ITEM_KG := [Item]f32{.Apple = 0.2, .Berries = 0.1, .Mushroom = 0.14, .Pumpkin = 1.5, .Cabbage = 1, .Nuts = 0.03, .Wheat = 0.5, .Egg = 0.09, .Flour = 0.1, .Salt = 0.3, .Fish = 0.4, .Meat = 0.19, .Milk = 0.22, .Honey = 0.1, .Pebble = 0.3, .Apple_Pie = 1.2, .Pumpkin_Pie = 1.5, .Berry_Muffins = 0.5, .Mushroom_Pie = 1, .Nut_Cake = 0.9, .Bread = 0.9, .Fried_Egg = 0.1, .Grilled_Fish = 0.4, .Roast = 0.8, .Butter = 0.042, .Cheese = 0.095, .Wood = 1, .Fence = 3, .Scarecrow = 3, .Rod = 0.4, .Spear = 1, .Gate = 4, .Larder = 6, .Campfire = 5}
// The room one of each thing takes in the sack or the larder, litres (a flat-pack piece for what is built). Raise one and fewer fit.
ITEM_LITRES := [Item]f32{.Apple = 0.3, .Berries = 0.2, .Mushroom = 0.3, .Pumpkin = 4, .Cabbage = 1.5, .Nuts = 0.05, .Wheat = 1.5, .Egg = 0.1, .Flour = 0.2, .Salt = 0.15, .Fish = 0.5, .Meat = 0.25, .Milk = 0.25, .Honey = 0.1, .Pebble = 0.15, .Apple_Pie = 1.5, .Pumpkin_Pie = 1.5, .Berry_Muffins = 1, .Mushroom_Pie = 1.5, .Nut_Cake = 1, .Bread = 1, .Fried_Egg = 0.2, .Grilled_Fish = 0.6, .Roast = 1, .Butter = 0.05, .Cheese = 0.1, .Wood = 1.5, .Fence = 4, .Scarecrow = 6, .Rod = 1.5, .Spear = 2, .Gate = 5, .Larder = 15, .Campfire = 8}
// Calories in one of each raw thing, full grown and of the usual size: a bunch of berries, an apple, a mushroom, a pumpkin, a whole head of cabbage, a handful of nuts, a sheaf of wheat, an egg (a turkey's), the flour from one sheaf, a lump of rock salt (all of it electrolytes, none of it energy), a fish, a cut of meat (a turkey gives two, a goat five), a mug of milk, a piece of honeycomb. What is actually picked varies (see FOOD_BUDGET in world.json, growing); a dish's are worked out from what went into it. Raise one and that food feeds him more (its weight in ITEM_KG should follow, to stay real).
RAW_KCAL := #partial [Item]f32{.Apple = 95, .Berries = 50, .Mushroom = 30, .Pumpkin = 400, .Cabbage = 250, .Nuts = 180, .Wheat = 340, .Egg = 130, .Flour = 340, .Salt = 30, .Fish = 200, .Meat = 300, .Milk = 150, .Honey = 300}

// ---- made_of ----
// What each raw food, and the two the churn makes (butter is the cream of the milk, cheese its curds and salt), is made of: the share of its calories, in per cent, that is carbs, fat, protein, fibre, vitamins and electrolytes, in that order, adding up to 100. Every other dish is what went into it, mixed by calories (see composition). Raise a share and the others must come down.
COMPOSITION := #partial [Item]Composition{.Apple = {86, 1, 1, 5, 6, 1}, .Berries = {76, 3, 3, 4, 14, 0}, .Mushroom = {30, 5, 40, 10, 5, 10}, .Pumpkin = {82, 2, 7, 4, 3, 2}, .Cabbage = {55, 3, 15, 20, 5, 2}, .Nuts = {12, 70, 12, 5, 0, 1}, .Wheat = {82, 4, 12, 2, 0, 0}, .Flour = {82, 4, 12, 2, 0, 0}, .Egg = {2, 60, 34, 0, 3, 1}, .Salt = {0, 0, 0, 0, 0, 100}, .Fish = {0, 25, 70, 0, 3, 2}, .Meat = {0, 45, 53, 0, 1, 1}, .Milk = {8, 48, 40, 0, 2, 2}, .Honey = {99, 0, 0, 0, 1, 0}, .Butter = {0, 98, 1, 0, 1, 0}, .Cheese = {2, 52, 37, 0, 1, 8}}
// What can go in a mixing bowl (see mixing.odin), and what it is beyond its calories and their shares: the unit it is measured in; the share of its weight that is water; the share of its carbs that is sugar; its acid, in grams to the gram (raise it and it is sourer and keeps longer); how bitter (bitterness to the gram, a burnt crust's being BURN_BITTER) and how hot to the tongue (chili to the gram) it is; how much of its protein sets (holds a shape when worked or heated); how many microorganisms a gram of it starts with, as a power of ten (none 0, few 1, some 3, many 4, very many 5); its marks (Leafy or Firm vegetable, Fruit, grows in the Ground, Wants_Cooking, stays in Pieces in a mix, Mashes into a dough with flour, keeps in its Shell); and, for a fish, the share of a piece in the sack not eaten (waste). A food in the sack (in_sack) has the calories and shares of that thing (item, RAW_KCAL and COMPOSITION, by its weight in ITEM_KG); any other, or salt, has its own (kcal_100g, calories to 100 g, and shares). The new foods' figures are ordinary nutrition tables', rounded.
MIXABLE := [Mixable]Mixable_Data{.Water = {unit = .Millilitre, water = 1, microbes = 1, kcal_100g = 0, shares = {0, 0, 0, 0, 0, 0}}, .Milk = {item = .Milk, in_sack = true, unit = .Millilitre, water = 0.88, sugar = 1, setting = 0.1, microbes = 4}, .Flour = {item = .Flour, in_sack = true, unit = .Gram, water = 0.12, sugar = 0.02, setting = 0.5, microbes = 4}, .Egg = {item = .Egg, in_sack = true, unit = .Egg, water = 0.75, setting = 1, microbes = 3.5, marks = {.Shell}}, .Honey = {item = .Honey, in_sack = true, unit = .Gram, water = 0.18, sugar = 1}, .Butter = {item = .Butter, in_sack = true, unit = .Gram, water = 0.16, microbes = 1}, .Salt = {item = .Salt, in_sack = true, unit = .Pinch, water = 0, kcal_100g = 1600, shares = {0, 0, 0, 0, 0, 100}}, .Cheese = {item = .Cheese, in_sack = true, unit = .Gram, water = 0.4, setting = 0.3, microbes = 1, marks = {.Pieces}}, .Berries = {item = .Berries, in_sack = true, unit = .Gram, water = 0.85, sugar = 0.9, acid = 0.002, microbes = 1, marks = {.Fruit, .Pieces}}, .Apple = {item = .Apple, in_sack = true, unit = .Gram, water = 0.85, sugar = 0.9, acid = 0.002, microbes = 1, marks = {.Fruit, .Pieces}}, .Pumpkin = {item = .Pumpkin, in_sack = true, unit = .Gram, water = 0.9, sugar = 0.5, microbes = 1, marks = {.Firm, .Pieces}}, .Cabbage = {item = .Cabbage, in_sack = true, unit = .Gram, water = 0.92, sugar = 0.9, bitter = 0.002, microbes = 1, marks = {.Leafy, .Pieces}}, .Mushroom = {item = .Mushroom, in_sack = true, unit = .Gram, water = 0.92, sugar = 0.4, microbes = 2, marks = {.Firm, .Pieces}}, .Nuts = {item = .Nuts, in_sack = true, unit = .Gram, water = 0.04, sugar = 0.3, marks = {.Pieces}}, .Fish = {item = .Fish, in_sack = true, unit = .Gram, water = 0.75, setting = 0.1, microbes = 5, marks = {.Pieces}, waste = 0.5}, .Meat = {item = .Meat, in_sack = true, unit = .Gram, water = 0.7, setting = 0.1, microbes = 5, marks = {.Pieces}}, .Chili = {unit = .Pinch, water = 0.1, sugar = 0.3, heat = 1, microbes = 0, marks = {}, kcal_100g = 300, shares = {45, 15, 13, 20, 7, 0}}, .Dill = {unit = .Pinch, water = 0.86, sugar = 0, microbes = 2, marks = {}, kcal_100g = 43, shares = {38, 20, 28, 8, 4, 2}}, .Potato = {unit = .Gram, water = 0.79, sugar = 0.05, microbes = 4.5, marks = {.Firm, .Ground, .Wants_Cooking, .Mashes}, kcal_100g = 77, shares = {79, 1, 10, 6, 3, 1}}, .Onion = {unit = .Gram, water = 0.89, sugar = 0.55, heat = 0.01, microbes = 4.5, marks = {.Firm, .Ground, .Pieces}, kcal_100g = 40, shares = {76, 2, 11, 8, 2, 1}}, .Carrot = {unit = .Gram, water = 0.88, sugar = 0.7, microbes = 4.5, marks = {.Firm, .Ground, .Pieces}, kcal_100g = 41, shares = {66, 4, 9, 14, 5, 2}}, .Beetroot = {unit = .Gram, water = 0.88, sugar = 1, microbes = 4.5, marks = {.Firm, .Ground, .Pieces}, kcal_100g = 43, shares = {63, 4, 15, 13, 3, 2}}, .Cucumber = {unit = .Gram, water = 0.96, sugar = 0.55, microbes = 1, marks = {.Firm, .Pieces}, kcal_100g = 15, shares = {70, 5, 13, 7, 3, 2}}, .Tomato = {unit = .Gram, water = 0.94, sugar = 0.95, acid = 0.003, microbes = 1, marks = {.Firm, .Pieces}, kcal_100g = 18, shares = {56, 9, 18, 12, 4, 1}}, .Cauliflower = {unit = .Gram, water = 0.92, sugar = 0.6, microbes = 1, marks = {.Firm, .Pieces}, kcal_100g = 25, shares = {44, 9, 27, 14, 5, 1}}, .Aubergine = {unit = .Gram, water = 0.92, sugar = 1, bitter = 0.003, microbes = 1, marks = {.Firm, .Wants_Cooking, .Pieces}, kcal_100g = 25, shares = {48, 7, 16, 25, 3, 1}}, .Zucchini = {unit = .Gram, water = 0.95, sugar = 1, microbes = 1, marks = {.Firm, .Pieces}, kcal_100g = 17, shares = {42, 13, 24, 10, 9, 2}}, .Radicchio = {unit = .Gram, water = 0.93, sugar = 0.2, bitter = 0.01, microbes = 1, marks = {.Leafy, .Pieces}, kcal_100g = 23, shares = {57, 9, 22, 7, 4, 1}}, .Lemon = {unit = .Gram, water = 0.89, sugar = 0.55, acid = 0.03, microbes = 1, marks = {.Fruit, .Pieces}, kcal_100g = 29, shares = {64, 7, 11, 14, 3, 1}}, .Orange = {unit = .Gram, water = 0.87, sugar = 1, acid = 0.004, microbes = 1, marks = {.Fruit, .Pieces}, kcal_100g = 47, shares = {76, 2, 7, 9, 5, 1}}, .Peach = {unit = .Gram, water = 0.89, sugar = 1, acid = 0.002, microbes = 1, marks = {.Fruit, .Pieces}, kcal_100g = 39, shares = {78, 5, 8, 7, 1, 1}}, .Pear = {unit = .Gram, water = 0.84, sugar = 0.8, acid = 0.001, microbes = 1, marks = {.Fruit, .Pieces}, kcal_100g = 57, shares = {83, 2, 3, 10, 1, 1}}, .Plum = {unit = .Gram, water = 0.87, sugar = 1, acid = 0.003, microbes = 1, marks = {.Fruit, .Pieces}, kcal_100g = 46, shares = {82, 5, 6, 5, 1, 1}}, .Cherry = {unit = .Gram, water = 0.82, sugar = 0.9, acid = 0.002, microbes = 1, marks = {.Fruit, .Pieces}, kcal_100g = 63, shares = {84, 3, 6, 6, 0, 1}}, .Grapes = {unit = .Gram, water = 0.81, sugar = 0.9, acid = 0.002, microbes = 2, marks = {.Fruit, .Pieces}, kcal_100g = 69, shares = {92, 2, 3, 2, 0, 1}}, .Banana = {unit = .Gram, water = 0.75, sugar = 0.6, acid = 0.001, microbes = 1, marks = {.Fruit, .Mashes}, kcal_100g = 89, shares = {87, 3, 4, 5, 0, 1}}}
// Calories in a gram of each part, as in life (carbs and protein 4, fat 9, fibre 2), to turn a food's calories into the grams it is made of. Vitamins weigh nothing (0). Electrolytes are points, not calories: 16 points are a gram of salt, so that cheese comes out about 2% salt. Raise one and a food of the same calories is made of less of it.
NUTRIENT_KCAL := [Nutrient]f32{.Carbs = 4, .Fat = 9, .Protein = 4, .Fibre = 2, .Vitamins = 0, .Electrolytes = 16}
// grams in a pinch of salt, chili or dill; raise it and a pinch is more
PINCH_G :: f32(2)

// ---- mixing ----
// The rules of the mixing bowl, of shaping, of heating what comes out of it (oven, fire, pot), of leaving it to stand in a crock, and of microorganisms (see mixing.odin, docs/plans/wd1b-quantities-times-effects.md and docs/plans/wd1c-real-food-rules.md). Nothing in the game uses them yet: tools/check.sh mix "500g flour, 300ml water" shows what any bowl gives.

// a bowl takes this many kinds of thing at most; raise it for bigger recipes
BOWL_KINDS :: 4
// and this many grams in all (a millilitre counts as a gram); raise it for a bigger bowl
BOWL_MOST_G :: f32(5000)
// the share of a filling's water and fat that is free to wet a mix, the rest staying in the pieces; raise it and pieces make a mix wetter
FILLING_FREE :: f32(0.3)
// the share of a mashed food's water and fat that is free to wet a dough (a potato or banana mashed into flour); raise it and such a dough is wetter
MASH_FREE :: f32(0.5)
// free fat counts as this much of its weight in liquid; raise it and butter wets a mix more
FAT_LIQUID :: f32(0.5)
// A mix's consistency is its free liquid as a share of its weight: under this it is crumbly; raise it and more mixes are crumbs
CRUMBLY_BELOW :: f32(0.28)
// under this, kneadable (a dough); raise it and wetter mixes are still doughs
KNEADABLE_BELOW :: f32(0.5)
// under this pourable (a batter), and over it runny; raise it and wetter mixes are still batters
POURABLE_BELOW :: f32(0.72)
// starch from flour (not in pieces, not vegetables) this share of the weight or more: a mix 'with flour' (crumbs, dough, batter, slop); raise it and a mix needs more flour to be one
FLOUR_LEAST :: f32(0.08)
// things in pieces this share of the weight or more: a mix 'with pieces' (pieces, soup, a pie, muffins); raise it and more pieces are needed
PIECES_LEAST :: f32(0.05)
// vegetables and fruit, raw and not pressed, this share of the weight or more, without flour: a salad; raise it and a salad must be more nearly all vegetables
SALAD_LEAST :: f32(0.7)
// a pourable mix with flour is a batter if protein that sets is this share of its weight, else slop; raise it and a batter needs more egg
BATTER_SET :: f32(0.03)
// a pourable or runny mix without flour is an egg mix if protein that sets is this share of its weight; raise it and it needs more egg
EGG_SET :: f32(0.03)
// washing takes this many powers of ten of microorganisms off what grows in the ground (2: to a hundredth); raise it and washing does more
WASH_OFF :: f32(2)
// an egg in its shell lets microorganisms grow this share as fast as in the open; raise it and eggs keep less long
SHELL_KEEPS :: f32(0.1)
// what wants cooking (potato, aubergine) this share of the weight or more, eaten raw or not cooked through: hard to digest, a tummy ache; raise it and more of it can be eaten raw
HARD_LEAST :: f32(0.2)
// The best mixing time, in minutes on the dial, is MIX_LEAST, plus MIX_DEVELOP times the share of starch free in it, times (1 - free liquid) to the power MIX_STIFFNESS, times (1 - MIX_RICH times the share of fat and sugar), plus MIX_PER_SET times the setting share. MIX_LEAST is the least, a drink's: raise it and everything wants mixing longer
MIX_LEAST :: f32(0.5)
// and never more than this many minutes; raise it and a big stiff dough wants longer
MIX_MOST :: f32(15)
// minutes for each share of free starch: what makes a flour dough want long mixing; raise it and doughs want longer
MIX_DEVELOP :: f32(120)
// how much stiffer, drier mixes want more mixing (a power); raise it and a dry dough wants far longer than a wet one
MIX_STIFFNESS :: f32(3)
// how much fat and sugar shorten mixing; raise it and a rich batter wants less
MIX_RICH :: f32(3)
// minutes for each share of protein that sets (egg); raise it and egg mixes want longer
MIX_PER_SET :: f32(10)
// mixed under this share of the best time it is lumpy; it counts as right from here up (for a batter, up to TOUGH_AT). Raise it and less time is forgiven
MIX_RIGHT_LOW :: f32(0.6)
// mixed under this share of the best time it gets none of the cooking bonus for its mixing; raise it and short mixing costs more
MIX_ZERO_LOW :: f32(0.15)
// a batter mixed over this many times its best is tough; a dough does not mind. Raise it and a batter forgives more
TOUGH_AT :: f32(2)
// a batter mixed this many times its best gets none of the bonus for its mixing; raise it and overmixing costs less
TOUGH_ZERO :: f32(4)
// The best temperature, degrees, is TEMP_HOTTEST, less TEMP_PER_SUGAR times the sugar share and TEMP_PER_SET times the setting share, never under TEMP_LEAST. TEMP_HOTTEST is a plain bread dough's: raise it and everything wants more heat
TEMP_HOTTEST :: f32(220)
// the gentlest best temperature, degrees (an egg mix); raise it and egg mixes want more heat
TEMP_LEAST :: f32(140)
// degrees less for each whole share of sugar (sugar burns sooner); raise it and sweet things want gentler heat
TEMP_PER_SUGAR :: f32(150)
// degrees less for each whole share of protein that sets (egg curdles); raise it and egg mixes want gentler heat
TEMP_PER_SET :: f32(600)
// degrees either side of the best that count as right; raise it and the oven forgives more
TEMP_RIGHT :: f32(15)
// and this many degrees more for each whole share of fat (fat forgives); raise it and rich things forgive more
TEMP_FAT_FORGIVES :: f32(100)
// degrees beyond the right ones at which it gets none of the bonus for its temperature; raise it and a wrong temperature costs less
TEMP_ZERO :: f32(50)
// The best cooking time in the oven, minutes: TIME_PER_KG times the kilograms to the power 2/3, times (1 + TIME_PER_WATER times the water share), times SHAPE_TIME for its shape. On the fire, FIRE_TIME of that. Raise it and everything bakes longer
TIME_PER_KG :: f32(32)
// how much longer water makes the cooking (water to drive off); raise it and wet things take longer
TIME_PER_WATER :: f32(1)
// on the fire a thing is cooked thin: this share of the oven's time; raise it and the fire is slower
FIRE_TIME :: f32(0.4)
// the share of a loaf's cooking time a shaped dough takes, oven, fire or pot (a thin shape cooks faster); raise one and that shape takes longer
SHAPE_TIME := [Dough_Shape]f32{.Loaf = 1, .Flat = 0.35, .Wrapped = 0.5, .Layered = 0.8, .Strips = 0.25, .Lumps = 0.4}
// The best boiling time in a pot, minutes: BOIL_PER_KG times the kilograms to the power 2/3, times SHAPE_TIME for its shape, and for a drink or a soup BOIL_LIQUID of that. Raise it and everything boils longer
BOIL_PER_KG :: f32(38)
// a drink or a soup is through in this share of the time (it is all hot water); raise it and liquids boil longer
BOIL_LIQUID :: f32(0.3)
// a drink or a soup boiling loses this share of its water a minute; raise it and it boils down faster
BOIL_OFF :: f32(0.005)
// but never more than this share of it; raise it and a pot can boil drier
BOIL_OFF_MOST :: f32(0.5)
// grams of water starch takes up in the pot for each gram of it, once cooked through (noodles get heavier); raise it and boiled dough comes out heavier
BOIL_ABSORB :: f32(1.5)
// boiled this many times its best it falls apart; raise it and the pot forgives more
BOIL_APART :: f32(2)
// the share of what alcohol is left that heat drives off each minute (20 minutes boiling leave a twentieth); raise it and cooking drives it off sooner
ALCOHOL_OFF :: f32(0.15)
// cooked for these shares of the best time it counts as right (under the first, the middle is raw); widen them and cooking forgives more
TIME_RIGHT := [2]f32{0.9, 1.25}
// cooked for these shares of the best time it gets none of the bonus for its time; widen them and a wrong time costs less
TIME_ZERO := [2]f32{0.5, 2.5}
// the fire's three heights for the spit, each a temperature, degrees: the lower, the hotter. Raise one and that height cooks hotter
SPIT_TEMP := [Spit]f32{.High = 160, .Middle = 210, .Low = 260}
// what a thing starts at, degrees; raise it and it heats through sooner
ROOM_TEMP :: f32(20)
// The middle is done when it reaches this, degrees. It warms towards the heat around it, never above BOIL while it is wet, and reaches CORE_DONE at the best time at the best temperature. Raise it and the middle needs more heat to count as done
CORE_DONE :: f32(85)
// degrees water boils at: the most the middle of anything wet reaches, and a pot's heat; raise it and pots cook hotter
BOIL :: f32(100)
// at another temperature the time the middle takes goes with (best - ROOM_TEMP) over (temperature - ROOM_TEMP), to this power; raise it and heat matters more to the time
INSIDE_HEAT_POWER :: f32(0.7)
// The outside browns as the time over the best time, doubled for every BROWN_DOUBLING degrees over the best temperature (halved under): 1 is golden. Raise it and heat burns slower
BROWN_DOUBLING :: f32(25)
// browned this far the crust is burnt; raise it and crusts burn later
BURNT_CRUST :: f32(2)
// browned this far, with the middle done, the whole thing is charcoal (sooner on an open fire; never in a pot, which says 0); raise it and charcoal comes later
CHAR_AT := [Heating]f32{.Bake = 4, .Grill = 2.5, .Boil = 0}
// the share of its water a thing loses at its best time and temperature, more the longer and the hotter; raise it and everything dries more
DRY_AT_BEST :: f32(0.33)
// losing more than this share of its water, it is dry; raise it and more drying is forgiven
DRY_RIGHT :: f32(0.45)
// a dough or a slop that loses this share of its water is a brick; raise it and a brick takes longer
BRICK_DRY :: f32(0.65)
// an egg mix heated this many degrees over its best curdles; raise it and eggs forgive more heat
CURDLE_OVER :: f32(25)
// a salad heated dry whose vegetables are this share leaves or more is a soggy mess; under it, baked or grilled vegetables, the poorer the more leaves. Raise it and more leaves are forgiven
SOGGY_LEAFY :: f32(0.5)
// Microorganisms are counted per gram as a power of ten. Over this it is unsafe: a tummy ache, the worse the further over. Raise it and more is safe
UNSAFE_MICROBES :: f32(3)
// over this it is spoiled for good: it stinks, cooking does not save it, and he will not eat it. Raise it and things take longer to spoil
SPOILED_MICROBES :: f32(6)
// they never grow past this; raise it and there is no other effect
MICROBES_MOST :: f32(9)
// Growth, in powers of ten an hour: GROW_FASTEST at GROW_BEST degrees, nothing at GROW_COLDEST or below, rising as the temperature over GROW_COLDEST to the power GROW_POWER, and falling to nothing at GROW_HOTTEST. Tuned so that grilled meat is safe for 2 days at 24 degrees but not 3, and a week at 4. Raise it and everything goes off sooner
GROW_FASTEST :: f32(0.068)
// degrees at which they stop growing: frozen, nothing grows; raise it and cold keeps food for good
GROW_COLDEST :: f32(0)
// degrees at which they grow fastest; raise it and warm places spoil less than hot ones
GROW_BEST :: f32(37)
// degrees at which they stop growing again (and above which heat starts to kill them); raise it and hot food spoils
GROW_HOTTEST :: f32(50)
// how much slower the cold is (a power): at 0.71, 4 degrees grows about 0.28 as fast as 24; raise it and the cold keeps things longer
GROW_POWER :: f32(0.71)
// growth goes with the water free to them, as a share of the weight: none at this or under; raise it and drier things still keep
GROW_DRY :: f32(0.1)
// and all of it at this or over; raise it and only the wettest things grow fast
GROW_WET :: f32(0.5)
// Salt, sugar, acid and alcohol each slow growth as their share of the water (salt and water: a brine), to nothing at their own share. Salt stops it at this brine (12%); raise it and salt keeps less
SALT_STOPS :: f32(0.12)
// sugar at this share of its water stops it (jam, honey); raise it and sugar keeps less
SUGAR_STOPS :: f32(0.65)
// acid at this share stops it (a pickle's sourness); raise it and sour things keep less
ACID_STOPS :: f32(0.005)
// alcohol at this share stops it (wine keeps); raise it and alcohol keeps less
ALCOHOL_STOPS :: f32(0.08)
// Heat kills KILL_AT_70 powers of ten a minute at 70 degrees, ten times as many for every KILL_Z degrees hotter (and ten times fewer for every KILL_Z cooler: next to nothing under 60). Raise it and cooking makes things safe sooner
KILL_AT_70 :: f32(1)
// degrees for ten times as much killing; raise it and heat over 70 kills less
KILL_Z :: f32(7)
// hours in a day of the rules, for standing and keeping (a game day is 60 minutes of play); raise it and a day is longer
DAY_HOURS :: f32(24)
// hours between one look at a crock and the next, working it out; raise it and standing is worked out more roughly
STAND_STEP :: f32(1)
// Standing in a crock: in a brine (salt as a share of its water) from SOUR_SALT_LEAST to SOUR_SALT_MOST its sugar sours; under it, what is not a sweet drink rots. Raise it and pickles need more salt
SOUR_SALT_LEAST :: f32(0.01)
// over this brine nothing sours (and little grows): too salty; raise it and saltier crocks still sour
SOUR_SALT_MOST :: f32(0.06)
// under this many degrees nothing sours or ferments in a crock (its microorganisms are too slow); raise it and a crock wants a warmer place
FERMENT_COLDEST :: f32(12)
// how fast the sugar sours: this share of it an hour for each power of ten an hour growth runs at; raise it and pickles are ready sooner
SOUR_RATE :: f32(1)
// grams of acid from a gram of sugar, souring; raise it and pickles get sourer
ACID_PER_SUGAR :: f32(1)
// calories in a gram of acid; raise it and sour things are richer
ACID_KCAL :: f32(3.5)
// a sweet drink without salt: this share of its sugar turns to alcohol an hour for each power of ten an hour growth runs at; raise it and wine is ready sooner
YEAST_RATE :: f32(2)
// grams of alcohol from a gram of sugar (the rest goes off as gas); raise it and wine is stronger
ALCOHOL_PER_SUGAR :: f32(0.51)
// calories in a gram of alcohol; raise it and wine is richer
ALCOHOL_KCAL :: f32(7)
// the yeast stops when alcohol is this share of its water; raise it and wine can get stronger
ALCOHOL_YEAST_MOST :: f32(0.15)
// with air: this share of the alcohol turns to acid an hour for each power of ten an hour growth runs at; raise it and vinegar comes sooner
VINEGAR_RATE :: f32(0.1)
// grams of acid from a gram of alcohol (it takes oxygen from the air); raise it and vinegar gets sourer
ACID_PER_ALCOHOL :: f32(1.3)
// and grams of water with it; raise it and vinegar comes out heavier
WATER_PER_ALCOHOL :: f32(0.39)
// soured to this share of acid it is pickles; raise it and pickles take longer
PICKLED_ACID :: f32(0.004)
// with this share of alcohol it is wine; raise it and wine must be stronger
WINE_ALCOHOL :: f32(0.03)
// turned to this share of acid, with little alcohol left, it is vinegar; raise it and vinegar takes longer
VINEGAR_ACID :: f32(0.03)
// Taste runs from -1 (awful) to 1: TASTE_PLAIN, plus for each taste its gain as far as its best share, less its loss for every share over its most; less the flaws. Raise it and everything tastes better
TASTE_PLAIN :: f32(0.2)
// each taste's line: sweet, salty, fatty and sour (acid) as shares of the weight, bitter as bitterness to the gram, hot as chili to the kilogram. Raise a best or a most and more of it is liked; raise a gain or a loss and it matters more
TASTES := [Taste]Taste_Line{.Sweet = {best = 0.15, gain = 0.3, most = 0.5, loss = 2}, .Salty = {best = 0.012, gain = 0.3, most = 0.03, loss = 30}, .Fatty = {best = 0.15, gain = 0.2, most = 0.5, loss = 1}, .Sour = {best = 0.003, gain = 0.1, most = 0.012, loss = 30}, .Bitter = {best = 0.002, gain = 0.05, most = 0.01, loss = 20}, .Hot = {best = 5, gain = 0.1, most = 15, loss = 0.03}}
// bitterness a burnt outside adds for each step browned past golden; raise it and burnt things taste worse
BURN_BITTER :: f32(0.01)
// what each flaw takes off the taste (soggy, by the share of leaves); raise one and that flaw tastes worse
TASTE_FLAWS := [Flaw]f32{.Lumpy = 0.3, .Tough = 0.2, .Raw_Middle = 0.3, .Burnt_Crust = 0.5, .Curdled = 0.3, .Dry = 0.2, .Soggy = 0.6, .Falls_Apart = 0.2, .Hard_To_Digest = 0.3}
// what each flaw takes off how right its consistency is (from 1); raise one and that flaw spoils the texture more
CONSISTENCY_FLAWS := [Flaw]f32{.Lumpy = 0.4, .Tough = 0.5, .Raw_Middle = 0.5, .Burnt_Crust = 0.1, .Curdled = 0.7, .Dry = 0.4, .Soggy = 0.8, .Falls_Apart = 0.5, .Hard_To_Digest = 0.3}
// a dish is runny with more than this share of water (unless it set: SET_FIRM of setting protein, and cooked), soft, firm or hard over these, and brittle under; raise one and that texture needs more water
TEXTURE_WATER := [Texture]f32{.Runny = 0.7, .Soft = 0.4, .Firm = 0.22, .Hard = 0.1, .Brittle = 0}
// for its texture, what is in pieces counts this share of its water (a cut of meat is not runny); raise it and dishes of pieces are softer
TEXTURE_PIECES :: f32(0.5)
// protein that sets this share of the weight, cooked, holds a wet dish firm; raise it and more egg is needed
SET_FIRM :: f32(0.03)
// Hardness, 0 to 1: none with this share of water or more; raise it and wetter things are hard
HARD_WET :: f32(0.4)
// all of it at this share of water or less (a brick comes out about 0.8); raise it and hardness comes sooner
HARD_DRY :: f32(0.15)
// The editor's interval for each setting is this many times the best value wide for a beginner, narrowing to SKILL_NARROW for a master; raise one and a beginner is told less
SKILL_WIDE := [Setting]f32{.Mixing = 1, .Cooking = 1.0, .Temperature = 0.4}
// a master's interval, as many times the best value; raise one and a master is told less
SKILL_NARROW := [Setting]f32{.Mixing = 0.1, .Cooking = 0.08, .Temperature = 0.04}
// the best lies at a place inside the interval between these shares of it, the same for the same recipe; widen them and its place says less
SKILL_PLACE := [2]f32{0.15, 0.85}
// and never within this share of the middle (or the middle would give it away); raise it and the best is further from the middle
SKILL_NOT_MIDDLE :: f32(0.08)
// logs an hour of cooking at WOOD_AT degrees burns, more or less in proportion to the heat over ROOM_TEMP; raise it and cooking burns more wood
WOOD_PER_HOUR :: f32(1)
// the degrees WOOD_PER_HOUR is counted at; raise it and hot cooking burns less
WOOD_AT :: f32(200)
// real seconds a minute on the cooking dial takes; raise it and he waits longer
DIAL_MINUTE_SECONDS :: f32(0.25)
// real seconds a cooking takes at most; raise it and long cooking waits longer
COOK_WAIT_MOST :: f32(20)
// real seconds a minute of mixing takes; raise it and mixing waits longer
MIX_WAIT_PER_MINUTE :: f32(0.25)
// real seconds mixing takes at least; raise it and a short mix waits longer
MIX_WAIT_LEAST :: f32(1)
// real seconds mixing takes at most; raise it and a long mix waits longer
MIX_WAIT_MOST :: f32(3)

// ---- going_off ----
// Food goes off by the clock of play: each kind loses half its calories, and its freshness with them, in SPOIL_HALF seconds.

// Food goes off. Each kind of food in the sack loses half of what it is worth in SPOIL_HALF seconds (some never: grain, flour, nuts, honey, salt, butter), and so does its freshness; once that is below ROTTEN, out it goes ("Pee-yew!"). The sack keeps one freshness for each kind, as it keeps one total of calories: a fresh apple put in with stale ones makes them a little fresher on average. A dead animal goes off too: the longer its body lies, the poorer the meat chopped from it, and flies gather. In the end it is gone. A larder keeps food LARDER_KEEPS times as long, and holds more than the sack. It is built at the workbench (wood, and salt to keep the damp out), stood up with Q like a scarecrow, and E at it opens it: food goes in and out of it from the sack. F takes an empty one down again.
SPOIL_HALF := [Item]f32{.Apple = 3600, .Berries = 1200, .Mushroom = 1200, .Pumpkin = 3600, .Cabbage = 3600, .Nuts = 0, .Wheat = 0, .Egg = 1200, .Flour = 0, .Salt = 0, .Fish = 600, .Meat = 600, .Milk = 600, .Honey = 0, .Pebble = 0, .Apple_Pie = 1800, .Pumpkin_Pie = 1800, .Berry_Muffins = 1800, .Mushroom_Pie = 1800, .Nut_Cake = 2400, .Bread = 1800, .Fried_Egg = 1200, .Grilled_Fish = 1200, .Roast = 1200, .Butter = 0, .Cheese = 7200, .Wood = 0, .Fence = 0, .Scarecrow = 0, .Rod = 0, .Spear = 0, .Gate = 0, .Larder = 0, .Campfire = 0}
// below this freshness it is thrown away
ROTTEN :: f32(0.3)
// and below this it is said to be going off
STALE :: f32(0.75)
// seconds between one look at what has gone off and the next
SPOIL_EVERY :: f32(1)
// a body that has lain this share of its time draws flies
BODY_FLIES :: f32(0.5)
// the freshness of meat chopped from a body about to go
BODY_MEAT_LEAST :: f32(0.35)

// ---- making ----
// The places where things are made, and what each makes from what.

// seconds to make a batch
STATION_TIME := [Station_Kind]f32{.Oven = 6, .Fire = 4, .Churn = 5, .Bench = 3, .Camp = 4}
// How much richer what is made here is than what went in: for a beginner, and at the most, for a master. The skill that takes him from one to the other, and what he is called on the way.
COOK_RANGE := [Station_Kind][2]f32{.Oven = {1.15, 1.8}, .Fire = {1, 1.5}, .Churn = {1, 1.25}, .Bench = {1, 1}, .Camp = {1, 1.5}}
// the skill each place trains and goes by (see Trait)
STATION_SKILL := [Station_Kind]Trait{.Oven = .Baking, .Fire = .Grilling, .Churn = .Dairy, .Bench = .Hooves, .Camp = .Grilling}
// metres from the oven's middle he must be within to use it; raise it and it can be used from further off
OVEN_RADIUS :: f32(1.15)
// metres from each place's middle he must be within to use it; raise one and that place can be used from further off
STATION_RADIUS := [Station_Kind]f32{.Oven = OVEN_RADIUS, .Fire = 0.8, .Churn = 0.55, .Bench = BENCH_RADIUS, .Camp = 0.8}
// where the chopping block stands, from the fire
FIRE_BLOCK :: Vec3{1.55, 0, 0.35}
// metres from the chopping block's middle he must be within to chop a body; raise it and he can chop from further off
BLOCK_RADIUS :: f32(0.36)
// where the churn's stool stands, metres from the churn
CHURN_STOOL :: Vec3{0.95, 0, 0.3}
// The mill, by the wheat fields: it grinds wheat into flour, a sheaf at a time. E puts all the wheat in the sack into it; E again takes the flour.
MILL_RADIUS :: f32(1.35)
// seconds to grind one sheaf
MILL_TIME :: f32(2.5)
// The logs each dish takes are the last thing it needs: one for something small, two for a pie or a tray of muffins, three for a big rich cake. The plans of the workbench (what each is for is in PLAN_ABOUT).
RECIPES := [?]Recipe{{at = .Oven, dish = .Apple_Pie, needs = {{item = .Apple, count = 3}, {item = .Flour, count = 1}, {item = .Egg, count = 1}, {item = .Wood, count = 2}}}, {at = .Oven, dish = .Pumpkin_Pie, needs = {{item = .Pumpkin, count = 1}, {item = .Flour, count = 1}, {item = .Egg, count = 1}, {item = .Wood, count = 2}}}, {at = .Oven, dish = .Berry_Muffins, needs = {{item = .Berries, count = 3}, {item = .Flour, count = 1}, {item = .Egg, count = 1}, {item = .Wood, count = 2}}}, {at = .Oven, dish = .Mushroom_Pie, needs = {{item = .Mushroom, count = 3}, {item = .Flour, count = 1}, {item = .Egg, count = 1}, {item = .Wood, count = 2}}}, {at = .Oven, dish = .Nut_Cake, needs = {{item = .Nuts, count = 2}, {item = .Flour, count = 1}, {item = .Egg, count = 1}, {item = .Wood, count = 3}}}, {at = .Oven, dish = .Bread, needs = {{item = .Flour, count = 2}, {item = .Wood, count = 1}}}, {at = .Fire, dish = .Fried_Egg, needs = {{item = .Egg, count = 1}, {item = .Wood, count = 1}}}, {at = .Fire, dish = .Grilled_Fish, needs = {{item = .Fish, count = 1}, {item = .Wood, count = 1}}}, {at = .Fire, dish = .Roast, needs = {{item = .Meat, count = 1}, {item = .Wood, count = 1}}}, {at = .Churn, dish = .Butter, needs = {{item = .Milk, count = 2}}}, {at = .Churn, dish = .Cheese, needs = {{item = .Milk, count = 2}, {item = .Salt, count = 1}}}, {at = .Bench, dish = .Fence, needs = {{item = .Wood, count = 2}}}, {at = .Bench, dish = .Scarecrow, needs = {{item = .Wood, count = 3}, {item = .Wheat, count = 3}}}, {at = .Bench, dish = .Rod, needs = {{item = .Wood, count = 2}}}, {at = .Bench, dish = .Spear, needs = {{item = .Wood, count = 2}, {item = .Pebble, count = 1}}}, {at = .Bench, dish = .Gate, needs = {{item = .Wood, count = 3}}}, {at = .Bench, dish = .Larder, needs = {{item = .Wood, count = 4}, {item = .Salt, count = 2}}}, {at = .Bench, dish = .Campfire, needs = {{item = .Wood, count = 4}, {item = .Pebble, count = 4}}}}

