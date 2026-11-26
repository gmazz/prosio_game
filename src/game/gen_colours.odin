package game

// Made by tools/gen_data from data/tuning/colours.json: do not edit; edit that file.

// Every colour the game draws with, as red, green, blue and opacity, 0 to 255.

// ---- screen_text ----
// The words and panels on the screen.

// white words and marks on the screen
UI_WHITE :: Color{255, 255, 255, 255}
// the dark backing behind bars, the map and the chosen cell, and dark words on a light one
UI_DARK :: Color{30, 34, 40, 255}
// the edge round his speech bubble
BUBBLE_EDGE_COLOR :: Color{150, 150, 158, 255}
// the see-through dark backing of the panel at the top left and of the sack
UI_PANEL :: Color{20, 30, 24, 150}
// red on the screen: a need run out, low stamina, an animal near the end of its health, a throw wound up full
UI_RED :: Color{226, 70, 70, 255}
// green words in the menus: good news, what is growing, the outfit chosen
UI_GREEN :: Color{110, 200, 90, 255}
// yellow on the screen: titles and help lines, what is chosen, the throw's wind-up bar and the arrowhead over what he aims at
UI_YELLOW :: Color{246, 206, 70, 255}
// orange on the screen: titles, warnings, a need he lacks, an animal down to half its health
UI_ORANGE :: Color{244, 150, 60, 255}
// the stamina bar
UI_BLUE :: Color{80, 170, 240, 255}
// the bruised end of the stamina bar
UI_BRUISE :: Color{132, 84, 160, 255}

// ---- meadow_and_prosio ----
// Prosio, the ground, plants, and the colours used all over.

// the sky, behind everything
COLOR_SKY :: Color{159, 181, 157, 255}
// the ground beyond the meadow, under the fog
COLOR_OUTSIDE :: Color{93, 130, 105, 255}
// tufts of grass, and the stalks of flowers
COLOR_TUFT :: Color{76, 126, 58, 255}
// ferns and the low bushes under the forest trees
COLOR_FERN :: Color{58, 106, 54, 255}
// a fence's wood, though nothing is drawn with it at present (fences use PLANK_DARK and COLOR_PLANK)
COLOR_FENCE :: Color{174, 145, 99, 255}
// his skin, which tans towards HIDE_TAN as his hide toughens
COLOR_SKIN :: Color{249, 181, 160, 255}
// his snout, the insides of his ears and his belly button
COLOR_SKIN_DARK :: Color{222, 136, 127, 255}
// a blush, though nothing is drawn with it at present (his cheeks use ANIMAL_BLUSH)
COLOR_BLUSH :: Color{230, 136, 125, 255}
// his nostrils and his open mouth
COLOR_NOSTRIL :: Color{116, 67, 71, 255}
// the explorer's jacket, and the clasp of his pack
COLOR_SHIRT :: Color{222, 163, 64, 255}
// his shorts, and his pack
COLOR_SHORTS :: Color{60, 106, 111, 255}
// his red head cloth and kerchief, and the bands of the straw hat and the top hat
COLOR_HEADBAND :: Color{178, 65, 52, 255}
// his hooves and eyebrows, and dark bands on wooden things such as the churn's hoops
COLOR_HOOF :: Color{96, 62, 57, 255}
// a warm white used all over: the shine in eyes, eggs, milk, sparks, the mill on the map and white bits of clothes
COLOR_WHITE :: Color{255, 248, 226, 255}
// his eyes
COLOR_BLACK :: Color{49, 43, 46, 255}
// stars and sparkles: a knock, a fall, a thing made
COLOR_STAR :: Color{255, 226, 80, 255}
// gold: buckles and clasps, the crown, the monocle, earrings and the nose ring
COLOR_GOLD :: Color{255, 196, 40, 255}
// dust kicked up by landings, falls and bumps
COLOR_DUST :: Color{232, 220, 188, 255}
// drops of sweat when he strains
COLOR_SWEAT :: Color{130, 200, 255, 255}
// crumbs when he eats something that is not a dish
COLOR_CRUMB :: Color{240, 190, 120, 255}
// the heart that thumps above him, the hearts over a licking goat, and the crown's jewel
COLOR_HEART :: Color{235, 50, 70, 255}
// leaves: the crowns of broadleaf and apple trees, and leaves on crops and fallen branches
COLOR_LEAF :: Color{96, 164, 80, 255}
// darker leaves, mixed in with COLOR_LEAF, and a cabbage's outer leaves
COLOR_LEAF_DARK :: Color{66, 134, 76, 255}
// lighter leaves, mixed in with COLOR_LEAF, and bits of leaf when a crop is picked or nibbled
COLOR_LEAF_LIGHT :: Color{146, 190, 90, 255}
// bark and dark wood: tree trunks, stems, firewood, the chopping block and the scarecrow's pole
COLOR_TRUNK :: Color{120, 99, 77, 255}
// stone: pebbles, the footings of the oven and the mill, the stones round the fire
COLOR_ROCK :: Color{137, 150, 143, 255}
// lighter stone, mixed in with COLOR_ROCK, and the spear's point
COLOR_ROCK_LIGHT :: Color{157, 166, 146, 255}
// pale wood: snapped branches, the top of the chopping block, the churn, the larder, parts of fences and the workbench
COLOR_PLANK :: Color{214, 168, 110, 255}
// the meadow's flowers, each one of these
FLOWER_COLORS := [?]Color{{255, 120, 150, 255}, {255, 236, 120, 255}, {250, 250, 255, 255}, {190, 150, 255, 255}}
// ripe berries (they ripen from green to this), and bushes on the map
BERRY_COLOR :: Color{196, 40, 76, 255}
// ripe wheat (it ripens from green to this)
WHEAT :: Color{230, 190, 88, 255}
// an unripe apple, which reddens to APPLE_RED as it ripens
UNRIPE_GREEN :: Color{132, 178, 74, 255}
// a ripe apple
APPLE_RED :: Color{222, 44, 48, 255}
// the bar over an animal while it has more than half its health
HEALTH_GOOD :: Color{120, 210, 90, 255}
// the fox's pale parts
ANIMAL_CREAM :: Color{248, 222, 178, 255}
// dark marks on the animals and the scarecrow: eyes, brows, noses, beards, the crosses of a dead one
ANIMAL_INK :: Color{58, 47, 48, 255}
// pink: his rosy cheeks, the fox's, and a rabbit's ears and nose
ANIMAL_BLUSH :: Color{255, 150, 165, 255}
// a turkey's bronze body, and every other tail feather
TURKEY_BRONZE :: Color{124, 86, 60, 255}
// a turkey's darker breast, thighs and wings, and the bands on its tail feathers
TURKEY_DARK :: Color{78, 56, 46, 255}
// a turkey's other tail feathers
TURKEY_RUST :: Color{176, 100, 58, 255}
// the pale tips of a turkey's feathers and wings, and the feathers that fly off it
TURKEY_TIP :: Color{240, 222, 182, 255}
// a turkey's bare blue neck and head
TURKEY_SKIN :: Color{156, 200, 238, 255}
// a turkey's red wattle and snood
TURKEY_RED :: Color{222, 58, 58, 255}
// a turkey's legs and feet
TURKEY_LEG :: Color{216, 152, 134, 255}
// beaks: the turkey's and the crow's
BEAK :: Color{242, 198, 96, 255}
// a goat's white coat
GOAT_WHITE :: Color{240, 234, 222, 255}
// a goat's darker patches and beard
GOAT_PATCH :: Color{168, 146, 128, 255}
// the billy goat's brown coat
BILLY_COAT :: Color{156, 132, 106, 255}
// the billy goat's darker patches and beard
BILLY_DARK :: Color{98, 82, 68, 255}
// the goats' hooves
GOAT_HOOF :: Color{62, 52, 50, 255}
// the goats' horns
GOAT_HORN :: Color{216, 202, 170, 255}
// a goat's nose and the insides of its ears
GOAT_PINK :: Color{240, 182, 172, 255}
// A goat: a barrel of a body on four thin legs, a short perky tail, floppy ears, a little beard and horns. The billy goat is bigger and brown, with a long beard and great curling horns. Held, one hind leg runs to Prosio's hand.
UDDER_PINK :: Color{246, 176, 180, 255}
// his skin with the toughest hide: it tans towards this as his hide toughens
HIDE_TAN :: Color{214, 146, 116, 255}
// the fox's orange coat
FOX_COAT :: Color{212, 116, 55, 255}
// the fox's dark feet
FOX_FEET :: Color{84, 60, 52, 255}
// rock salt, and the salt rocks on the map
SALT_PINK :: Color{250, 196, 212, 255}

// ---- needs_and_body ----
// His needs and the parts of his body, on the screen and in the menus.

// The colour of each in the bar of what a food is made of, as in the panel of what he is made of.
NUTRIENT_COLOR := [Nutrient]Color{.Carbs = {244, 150, 60, 255}, .Fat = {246, 206, 70, 255}, .Protein = {236, 150, 190, 255}, .Fibre = {120, 196, 96, 255}, .Vitamins = VITAMIN_COLOR, .Electrolytes = SALT_COLOR}
// vitamins, in NUTRIENT_COLOR
VITAMIN_COLOR :: Color{250, 230, 110, 255}
// electrolytes, in NUTRIENT_COLOR
SALT_COLOR :: Color{236, 236, 240, 255}
// the puffs of his wind
GAS_GREEN :: Color{176, 204, 96, 255}
// the bars of what each trait is worth, on the BODY page
NEED_POWER :: Color{176, 140, 250, 255}
// a need's bar on the panel when he has too much of it
NEED_SILLY :: Color{240, 150, 220, 255}
// muscle: its part of what he is made of, and a muscle built past ordinary on the BODY page
MUSCLE_RED :: Color{232, 110, 96, 255}
// the colour of each part of him, in the bar of what he is made of and on the BODY page
PART_COLOR := [Part]Color{.Fat = {246, 206, 70, 255}, .Muscle = MUSCLE_RED, .Carbs = {244, 150, 60, 255}, .Protein = {236, 150, 190, 255}, .Fibre = {120, 196, 96, 255}, .Water = {80, 170, 240, 255}, .Stomach = {172, 116, 74, 255}, .Frame = {168, 168, 178, 255}}
// Each need's bar, when all is well.
NEED_BAR := [Need]Color{.Carbs = {240, 160, 60, 255}, .Protein = {232, 120, 150, 255}, .Fibre = {110, 190, 80, 255}, .Water = {90, 160, 240, 255}, .Vitamins = {246, 206, 70, 255}, .Electrolytes = {220, 220, 220, 255}}

// ---- buildings_and_food ----
// The oven, the fire, the mill, food and the sack.

// The colour of each, for the thing in his hoof as he picks it up.
ITEM_COLOR := #partial [Item]Color{.Apple = {222, 44, 48, 255}, .Berries = {196, 40, 76, 255}, .Mushroom = {196, 64, 46, 255}, .Pumpkin = {232, 128, 40, 255}, .Cabbage = {150, 200, 110, 255}, .Nuts = {160, 112, 70, 255}, .Salt = {244, 222, 226, 255}, .Fish = {240, 140, 70, 255}, .Honey = {246, 190, 60, 255}, .Pebble = {150, 152, 150, 255}, .Wheat = {230, 190, 88, 255}, .Egg = {246, 236, 214, 255}, .Wood = {150, 108, 70, 255}, .Spear = {150, 108, 70, 255}}
// the oven's bricks, and the oven on the map
BRICK :: Color{190, 96, 70, 255}
// the oven's mouth and chimney
BRICK_DARK :: Color{142, 66, 52, 255}
// the lines between the oven's bricks
BRICK_LINE :: Color{168, 80, 60, 255}
// flames, and the fire on the map
FLAME :: Color{246, 120, 40, 255}
// every other flame: the hot yellow ones
FLAME_HOT :: Color{255, 220, 90, 255}
// steel: the cleaver by the fire and the saw at the workbench
STEEL :: Color{190, 196, 204, 255}
// golden pie crust, and a made thing an animal carries off in its mouth
CRUST :: Color{230, 182, 108, 255}
// darker crust: the rim of a mushroom pie, the slashes on a loaf
CRUST_DARK :: Color{190, 130, 66, 255}
// the boxes things sit in, in the sack and the larder
SACK_BOX :: Color{246, 236, 214, 255}
// the mill's walls, and the flour waiting there
MILL_WALL :: Color{238, 230, 212, 255}
// the mill's roof
MILL_ROOF :: Color{176, 88, 66, 255}

// ---- clothes_and_map ----
// Prosio's clothes and hair, and the map.

// the map where he has not been yet
MAP_FOG :: Color{24, 28, 34, 255}
// open grass on the map
MAP_GRASS :: Color{98, 152, 76, 255}
// the forest on the map
MAP_FOREST :: Color{58, 96, 56, 255}
// the goat hills on the map
MAP_HILLS :: Color{156, 152, 104, 255}
// the paths and his home on the map
MAP_PATH :: Color{196, 172, 124, 255}
// fields of crops other than wheat on the map
MAP_SOIL :: Color{132, 96, 64, 255}
// wheat fields on the map
MAP_WHEAT :: Color{214, 178, 88, 255}
// the pond on the map
MAP_WATER :: Color{80, 150, 210, 255}
// Colours of his clothes.
STRAW :: Color{232, 200, 120, 255}
// the top hat and the sunglasses
HAT_BLACK :: Color{48, 44, 52, 255}
// the beanie
WOOL :: Color{86, 140, 210, 255}
// the frames of his glasses
GLASS_FRAME :: Color{52, 44, 48, 255}
// brown hair, and the moustache
HAIR :: Color{122, 78, 58, 255}
// long black hair
HAIR_BLACK :: Color{42, 38, 46, 255}
// grey hair, and the beard
HAIR_GREY :: Color{176, 176, 184, 255}
// lipstick
LIPSTICK :: Color{214, 40, 70, 255}
// the red T-shirt, and the scarecrow's shirt
TSHIRT :: Color{214, 72, 62, 255}
// white cloth: the sailor top, the white shirt, the chef's jacket and the apron
SAILOR :: Color{246, 244, 236, 255}
// the sailor top's collar and hem, and the print on the computer tee
NAVY :: Color{50, 70, 130, 255}
// the gilet
GILET :: Color{142, 96, 62, 255}
// the coat
COAT :: Color{82, 116, 88, 255}
// jeans
DENIM :: Color{76, 104, 156, 255}
// the skirt
SKIRT :: Color{226, 120, 150, 255}
// the sneakers
SNEAKER :: Color{246, 244, 238, 255}
// the brown boots, and the leather flying cap
BOOT :: Color{112, 74, 52, 255}
// black leather: the jacket, the trousers, the knee boots, the pirate top and the outside of the cape
LEATHER :: Color{46, 42, 50, 255}
// the trench coat
TRENCH :: Color{198, 166, 114, 255}
// the corduroy trousers
CORDS :: Color{150, 100, 62, 255}
// the chef's checked trousers
CHECKS :: Color{170, 172, 182, 255}
// the band tee and the turtleneck
TEE_BLACK :: Color{40, 38, 46, 255}
// the computer tee
TEE_CREAM :: Color{238, 228, 204, 255}
// the inside and collar of the cape, the tie and the bow tie
CAPE_RED :: Color{176, 42, 50, 255}
// the grey trainers
TRAINER :: Color{152, 156, 166, 255}
// the soles of the knee boots
SOLE :: Color{70, 60, 60, 255}
// the colour of each kind of trousers or skirt
LEG_COLOR := [Legwear]Color{.Shorts = COLOR_SHORTS, .None = {}, .Jeans = DENIM, .Skirt = SKIRT, .Leather = LEATHER, .Cords = CORDS, .Checks = CHECKS}

// ---- creatures ----
// Fish, rabbits, crows and bees.

// the fish
FISH_ORANGE :: Color{240, 136, 64, 255}
// the rabbits
RABBIT_COAT :: Color{184, 160, 138, 255}
// the crows
CROW_BLACK :: Color{52, 50, 62, 255}
// the straw hives
HIVE_STRAW :: Color{226, 182, 96, 255}
// honeycomb, and the hives on the map
HONEY_GOLD :: Color{246, 190, 60, 255}

// ---- built_things ----
// Things he builds.

// darker wood: fences and gates, the workbench, the larder, branches and the spear's shaft
PLANK_DARK :: Color{176, 128, 80, 255}
// the scarecrow's sackcloth head
SACKCLOTH :: Color{226, 200, 150, 255}

// ---- water ----
// The pond.

// splashes from the pond
POND_SPLASH :: Color{150, 206, 232, 255}

// ---- outlines_and_shadows ----
// The dark outlines, and the shadows.

// Dark cartoon outlines around solid shapes, about one pixel wide.
OUTLINE_COLOR :: Color{52, 40, 44, 255}
// how much of the light a shadow lets through
SHADOW_INK :: Color{150, 150, 166, 255}

