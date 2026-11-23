package game

// Made by tools/gen_data from data/tuning/colours.json: do not edit; edit that file.

// Every colour the game draws with, as red, green, blue and opacity, 0 to 255.

// ---- screen_text ----
// The words and panels on the screen.

UI_WHITE :: Color{255, 255, 255, 255}
UI_DARK :: Color{30, 34, 40, 255}
// the edge round his speech bubble
BUBBLE_EDGE_COLOR :: Color{150, 150, 158, 255}
UI_PANEL :: Color{20, 30, 24, 150}
UI_RED :: Color{226, 70, 70, 255}
UI_GREEN :: Color{110, 200, 90, 255}
UI_YELLOW :: Color{246, 206, 70, 255}
UI_ORANGE :: Color{244, 150, 60, 255}
UI_BLUE :: Color{80, 170, 240, 255}
UI_BRUISE :: Color{132, 84, 160, 255}

// ---- meadow_and_prosio ----
// Prosio, the ground, plants, and the colours used all over.

COLOR_SKY :: Color{159, 181, 157, 255}
COLOR_OUTSIDE :: Color{93, 130, 105, 255}
COLOR_TUFT :: Color{76, 126, 58, 255}
COLOR_FERN :: Color{58, 106, 54, 255}
COLOR_FENCE :: Color{174, 145, 99, 255}
COLOR_SKIN :: Color{249, 181, 160, 255}
COLOR_SKIN_DARK :: Color{222, 136, 127, 255}
COLOR_BLUSH :: Color{230, 136, 125, 255}
COLOR_NOSTRIL :: Color{116, 67, 71, 255}
COLOR_SHIRT :: Color{222, 163, 64, 255}
COLOR_SHORTS :: Color{60, 106, 111, 255}
COLOR_HEADBAND :: Color{178, 65, 52, 255}
COLOR_HOOF :: Color{96, 62, 57, 255}
COLOR_WHITE :: Color{255, 248, 226, 255}
COLOR_BLACK :: Color{49, 43, 46, 255}
COLOR_STAR :: Color{255, 226, 80, 255}
COLOR_GOLD :: Color{255, 196, 40, 255}
COLOR_DUST :: Color{232, 220, 188, 255}
COLOR_SWEAT :: Color{130, 200, 255, 255}
COLOR_CRUMB :: Color{240, 190, 120, 255}
COLOR_HEART :: Color{235, 50, 70, 255}
COLOR_LEAF :: Color{96, 164, 80, 255}
COLOR_LEAF_DARK :: Color{66, 134, 76, 255}
COLOR_LEAF_LIGHT :: Color{146, 190, 90, 255}
COLOR_TRUNK :: Color{120, 99, 77, 255}
COLOR_ROCK :: Color{137, 150, 143, 255}
COLOR_ROCK_LIGHT :: Color{157, 166, 146, 255}
COLOR_PLANK :: Color{214, 168, 110, 255}
FLOWER_COLORS := [?]Color{{255, 120, 150, 255}, {255, 236, 120, 255}, {250, 250, 255, 255}, {190, 150, 255, 255}}
BERRY_COLOR :: Color{196, 40, 76, 255}
WHEAT :: Color{230, 190, 88, 255}
UNRIPE_GREEN :: Color{132, 178, 74, 255}
APPLE_RED :: Color{222, 44, 48, 255}
HEALTH_GOOD :: Color{120, 210, 90, 255}
ANIMAL_CREAM :: Color{248, 222, 178, 255}
ANIMAL_INK :: Color{58, 47, 48, 255}
ANIMAL_BLUSH :: Color{255, 150, 165, 255}
TURKEY_BRONZE :: Color{124, 86, 60, 255}
TURKEY_DARK :: Color{78, 56, 46, 255}
TURKEY_RUST :: Color{176, 100, 58, 255}
TURKEY_TIP :: Color{240, 222, 182, 255}
TURKEY_SKIN :: Color{156, 200, 238, 255}
TURKEY_RED :: Color{222, 58, 58, 255}
TURKEY_LEG :: Color{216, 152, 134, 255}
BEAK :: Color{242, 198, 96, 255}
GOAT_WHITE :: Color{240, 234, 222, 255}
GOAT_PATCH :: Color{168, 146, 128, 255}
BILLY_COAT :: Color{156, 132, 106, 255}
BILLY_DARK :: Color{98, 82, 68, 255}
GOAT_HOOF :: Color{62, 52, 50, 255}
GOAT_HORN :: Color{216, 202, 170, 255}
GOAT_PINK :: Color{240, 182, 172, 255}
// A goat: a barrel of a body on four thin legs, a short perky tail, floppy ears, a little beard and horns. The billy goat is bigger and brown, with a long beard and great curling horns. Held, one hind leg runs to Prosio's hand.
UDDER_PINK :: Color{246, 176, 180, 255}
HIDE_TAN :: Color{214, 146, 116, 255}
FOX_COAT :: Color{212, 116, 55, 255}
FOX_FEET :: Color{84, 60, 52, 255}
SALT_PINK :: Color{250, 196, 212, 255}

// ---- needs_and_body ----
// His needs and the parts of his body, on the screen and in the menus.

// The colour of each in the bar of what a food is made of, as in the panel of what he is made of.
NUTRIENT_COLOR := [Nutrient]Color{.Carbs = {244, 150, 60, 255}, .Fat = {246, 206, 70, 255}, .Protein = {236, 150, 190, 255}, .Fibre = {120, 196, 96, 255}, .Vitamins = VITAMIN_COLOR, .Electrolytes = SALT_COLOR}
VITAMIN_COLOR :: Color{250, 230, 110, 255}
SALT_COLOR :: Color{236, 236, 240, 255}
GAS_GREEN :: Color{176, 204, 96, 255}
NEED_POWER :: Color{176, 140, 250, 255}
NEED_SILLY :: Color{240, 150, 220, 255}
MUSCLE_RED :: Color{232, 110, 96, 255}
PART_COLOR := [Part]Color{.Fat = {246, 206, 70, 255}, .Muscle = MUSCLE_RED, .Carbs = {244, 150, 60, 255}, .Protein = {236, 150, 190, 255}, .Fibre = {120, 196, 96, 255}, .Water = {80, 170, 240, 255}, .Frame = {168, 168, 178, 255}}
// Each need's bar, when all is well.
NEED_BAR := [Need]Color{.Carbs = {240, 160, 60, 255}, .Protein = {232, 120, 150, 255}, .Fibre = {110, 190, 80, 255}, .Water = {90, 160, 240, 255}, .Vitamins = {246, 206, 70, 255}, .Electrolytes = {220, 220, 220, 255}}

// ---- buildings_and_food ----
// The oven, the fire, the mill, food and the sack.

// The colour of each, for the thing in his hoof as he picks it up.
ITEM_COLOR := #partial [Item]Color{.Apple = {222, 44, 48, 255}, .Berries = {196, 40, 76, 255}, .Mushroom = {196, 64, 46, 255}, .Pumpkin = {232, 128, 40, 255}, .Cabbage = {150, 200, 110, 255}, .Nuts = {160, 112, 70, 255}, .Salt = {244, 222, 226, 255}, .Fish = {240, 140, 70, 255}, .Honey = {246, 190, 60, 255}, .Pebble = {150, 152, 150, 255}, .Wheat = {230, 190, 88, 255}, .Egg = {246, 236, 214, 255}, .Wood = {150, 108, 70, 255}, .Spear = {150, 108, 70, 255}}
BRICK :: Color{190, 96, 70, 255}
BRICK_DARK :: Color{142, 66, 52, 255}
BRICK_LINE :: Color{168, 80, 60, 255}
FLAME :: Color{246, 120, 40, 255}
FLAME_HOT :: Color{255, 220, 90, 255}
STEEL :: Color{190, 196, 204, 255}
CRUST :: Color{230, 182, 108, 255}
CRUST_DARK :: Color{190, 130, 66, 255}
SACK_BOX :: Color{246, 236, 214, 255}
MILL_WALL :: Color{238, 230, 212, 255}
MILL_ROOF :: Color{176, 88, 66, 255}

// ---- clothes_and_map ----
// Prosio's clothes and hair, and the map.

MAP_FOG :: Color{24, 28, 34, 255}
MAP_GRASS :: Color{98, 152, 76, 255}
MAP_FOREST :: Color{58, 96, 56, 255}
MAP_HILLS :: Color{156, 152, 104, 255}
MAP_PATH :: Color{196, 172, 124, 255}
MAP_SOIL :: Color{132, 96, 64, 255}
MAP_WHEAT :: Color{214, 178, 88, 255}
MAP_WATER :: Color{80, 150, 210, 255}
// Colours of his clothes.
STRAW :: Color{232, 200, 120, 255}
HAT_BLACK :: Color{48, 44, 52, 255}
WOOL :: Color{86, 140, 210, 255}
GLASS_FRAME :: Color{52, 44, 48, 255}
HAIR :: Color{122, 78, 58, 255}
HAIR_BLACK :: Color{42, 38, 46, 255}
HAIR_GREY :: Color{176, 176, 184, 255}
LIPSTICK :: Color{214, 40, 70, 255}
TSHIRT :: Color{214, 72, 62, 255}
SAILOR :: Color{246, 244, 236, 255}
NAVY :: Color{50, 70, 130, 255}
GILET :: Color{142, 96, 62, 255}
COAT :: Color{82, 116, 88, 255}
DENIM :: Color{76, 104, 156, 255}
SKIRT :: Color{226, 120, 150, 255}
SNEAKER :: Color{246, 244, 238, 255}
BOOT :: Color{112, 74, 52, 255}
LEATHER :: Color{46, 42, 50, 255}
TRENCH :: Color{198, 166, 114, 255}
CORDS :: Color{150, 100, 62, 255}
CHECKS :: Color{170, 172, 182, 255}
TEE_BLACK :: Color{40, 38, 46, 255}
TEE_CREAM :: Color{238, 228, 204, 255}
CAPE_RED :: Color{176, 42, 50, 255}
TRAINER :: Color{152, 156, 166, 255}
SOLE :: Color{70, 60, 60, 255}
LEG_COLOR := [Legwear]Color{.Shorts = COLOR_SHORTS, .None = {}, .Jeans = DENIM, .Skirt = SKIRT, .Leather = LEATHER, .Cords = CORDS, .Checks = CHECKS}

// ---- creatures ----
// Fish, rabbits, crows and bees.

FISH_ORANGE :: Color{240, 136, 64, 255}
RABBIT_COAT :: Color{184, 160, 138, 255}
CROW_BLACK :: Color{52, 50, 62, 255}
HIVE_STRAW :: Color{226, 182, 96, 255}
HONEY_GOLD :: Color{246, 190, 60, 255}

// ---- built_things ----
// Things he builds.

PLANK_DARK :: Color{176, 128, 80, 255}
SACKCLOTH :: Color{226, 200, 150, 255}

// ---- water ----
// The pond.

POND_SPLASH :: Color{150, 206, 232, 255}

// ---- outlines_and_shadows ----
// The dark outlines, and the shadows.

// Dark cartoon outlines around solid shapes, about one pixel wide.
OUTLINE_COLOR :: Color{52, 40, 44, 255}
// how much of the light a shadow lets through
SHADOW_INK :: Color{150, 150, 166, 255}

