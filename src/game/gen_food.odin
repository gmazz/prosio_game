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

// What one of each thing weighs (kg) and how much room it takes (litres).
ITEM_KG := [Item]f32{.Apple = 0.2, .Berries = 0.1, .Mushroom = 0.05, .Pumpkin = 3, .Cabbage = 1, .Nuts = 0.1, .Wheat = 0.5, .Egg = 0.06, .Flour = 0.5, .Salt = 0.3, .Fish = 0.4, .Meat = 0.5, .Milk = 1, .Honey = 0.5, .Pebble = 0.3, .Apple_Pie = 1.2, .Pumpkin_Pie = 1.5, .Berry_Muffins = 0.5, .Mushroom_Pie = 1, .Nut_Cake = 0.9, .Bread = 0.9, .Fried_Egg = 0.1, .Grilled_Fish = 0.4, .Roast = 0.8, .Butter = 0.5, .Cheese = 0.6, .Wood = 1, .Fence = 3, .Scarecrow = 3, .Rod = 0.4, .Spear = 1, .Gate = 4, .Larder = 6, .Campfire = 5}
// a flat-pack piece
ITEM_LITRES := [Item]f32{.Apple = 0.3, .Berries = 0.2, .Mushroom = 0.15, .Pumpkin = 4, .Cabbage = 1.5, .Nuts = 0.15, .Wheat = 1.5, .Egg = 0.1, .Flour = 0.6, .Salt = 0.15, .Fish = 0.5, .Meat = 0.6, .Milk = 1, .Honey = 0.5, .Pebble = 0.15, .Apple_Pie = 1.5, .Pumpkin_Pie = 1.5, .Berry_Muffins = 1, .Mushroom_Pie = 1.5, .Nut_Cake = 1, .Bread = 1, .Fried_Egg = 0.2, .Grilled_Fish = 0.6, .Roast = 1, .Butter = 0.5, .Cheese = 0.6, .Wood = 1.5, .Fence = 4, .Scarecrow = 6, .Rod = 1.5, .Spear = 2, .Gate = 5, .Larder = 15, .Campfire = 8}
// Calories in one of each raw thing, full grown and of the usual size (what is actually picked varies: see FOOD_BUDGET in world.json, growing). A dish's are worked out from what went into it. a bunch a whole head a handful a sheaf, about a cup of flour a lump: all of it electrolytes, none of it energy one piece; a turkey gives two, a goat five a jug a comb
RAW_KCAL := #partial [Item]f32{.Apple = 95, .Berries = 50, .Mushroom = 30, .Pumpkin = 400, .Cabbage = 250, .Nuts = 180, .Wheat = 340, .Egg = 130, .Flour = 340, .Salt = 30, .Fish = 200, .Meat = 300, .Milk = 150, .Honey = 300}

// ---- made_of ----
// Raw foods, and the two the churn makes (it changes what milk is: the butter is the cream, the cheese the curds, and salt). Every other dish is what went into it, mixed by calories: see composition. carbs  fat  protein  fibre  vitamins  electrolytes
COMPOSITION := #partial [Item]Composition{.Apple = {86, 1, 1, 5, 6, 1}, .Berries = {76, 3, 3, 4, 14, 0}, .Mushroom = {30, 5, 40, 10, 5, 10}, .Pumpkin = {82, 2, 7, 4, 3, 2}, .Cabbage = {55, 3, 15, 20, 5, 2}, .Nuts = {12, 70, 12, 5, 0, 1}, .Wheat = {82, 4, 12, 2, 0, 0}, .Flour = {82, 4, 12, 2, 0, 0}, .Egg = {2, 60, 34, 0, 3, 1}, .Salt = {0, 0, 0, 0, 0, 100}, .Fish = {0, 25, 70, 0, 3, 2}, .Meat = {0, 45, 53, 0, 1, 1}, .Milk = {8, 48, 40, 0, 2, 2}, .Honey = {99, 0, 0, 0, 1, 0}, .Butter = {0, 98, 1, 0, 1, 0}, .Cheese = {2, 52, 37, 0, 1, 8}}

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
STATION_SKILL := [Station_Kind]Trait{.Oven = .Baking, .Fire = .Grilling, .Churn = .Dairy, .Bench = .Hooves, .Camp = .Grilling}
OVEN_RADIUS :: f32(1.15)
STATION_RADIUS := [Station_Kind]f32{.Oven = OVEN_RADIUS, .Fire = 0.8, .Churn = 0.55, .Bench = BENCH_RADIUS, .Camp = 0.8}
// where the chopping block stands, from the fire
FIRE_BLOCK :: Vec3{1.55, 0, 0.35}
BLOCK_RADIUS :: f32(0.36)
CHURN_STOOL :: Vec3{0.95, 0, 0.3}
// The mill, by the wheat fields: it grinds wheat into flour, a sheaf at a time. E puts all the wheat in the sack into it; E again takes the flour.
MILL_RADIUS :: f32(1.35)
// seconds to grind one sheaf
MILL_TIME :: f32(2.5)
// The logs each dish takes are the last thing it needs: one for something small, two for a pie or a tray of muffins, three for a big rich cake. The plans of the workbench (what each is for is in PLAN_ABOUT).
RECIPES := [?]Recipe{{at = .Oven, dish = .Apple_Pie, needs = {{item = .Apple, count = 3}, {item = .Flour, count = 1}, {item = .Egg, count = 1}, {item = .Wood, count = 2}}}, {at = .Oven, dish = .Pumpkin_Pie, needs = {{item = .Pumpkin, count = 1}, {item = .Flour, count = 1}, {item = .Egg, count = 1}, {item = .Wood, count = 2}}}, {at = .Oven, dish = .Berry_Muffins, needs = {{item = .Berries, count = 3}, {item = .Flour, count = 1}, {item = .Egg, count = 1}, {item = .Wood, count = 2}}}, {at = .Oven, dish = .Mushroom_Pie, needs = {{item = .Mushroom, count = 3}, {item = .Flour, count = 1}, {item = .Egg, count = 1}, {item = .Wood, count = 2}}}, {at = .Oven, dish = .Nut_Cake, needs = {{item = .Nuts, count = 2}, {item = .Flour, count = 1}, {item = .Egg, count = 1}, {item = .Wood, count = 3}}}, {at = .Oven, dish = .Bread, needs = {{item = .Flour, count = 2}, {item = .Wood, count = 1}}}, {at = .Fire, dish = .Fried_Egg, needs = {{item = .Egg, count = 1}, {item = .Wood, count = 1}}}, {at = .Fire, dish = .Grilled_Fish, needs = {{item = .Fish, count = 1}, {item = .Wood, count = 1}}}, {at = .Fire, dish = .Roast, needs = {{item = .Meat, count = 1}, {item = .Wood, count = 1}}}, {at = .Churn, dish = .Butter, needs = {{item = .Milk, count = 2}}}, {at = .Churn, dish = .Cheese, needs = {{item = .Milk, count = 2}, {item = .Salt, count = 1}}}, {at = .Bench, dish = .Fence, needs = {{item = .Wood, count = 2}}}, {at = .Bench, dish = .Scarecrow, needs = {{item = .Wood, count = 3}, {item = .Wheat, count = 3}}}, {at = .Bench, dish = .Rod, needs = {{item = .Wood, count = 2}}}, {at = .Bench, dish = .Spear, needs = {{item = .Wood, count = 2}, {item = .Pebble, count = 1}}}, {at = .Bench, dish = .Gate, needs = {{item = .Wood, count = 3}}}, {at = .Bench, dish = .Larder, needs = {{item = .Wood, count = 4}, {item = .Salt, count = 2}}}, {at = .Bench, dish = .Campfire, needs = {{item = .Wood, count = 4}, {item = .Pebble, count = 4}}}}

