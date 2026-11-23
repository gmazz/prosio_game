package game

// Made by tools/gen_data from data/tuning/screen.json: do not edit; edit that file.

// How the game looks on the screen: the camera, the pixel sizes, and the sizes and timings of what is drawn over the meadow.

// ---- camera ----
// Where the camera sits, relative to the point it looks at.
CAMERA_OFFSET :: Vec3{0, 8.5, 10.6}

// ---- forest_view ----
FOREST_REVEAL :: f32(0.9) // in the forest, how much further round him the trees turn see-through (in crowns)

// ---- pixels ----
// The world is drawn into a small image, which is then enlarged without smoothing, so it comes out as crisp pixels. How fine the pixels are: six levels, picked with the number keys 1 to 6. Each is about this many rows of pixels from top to bottom. Each game pixel is a whole number of real screen pixels (or, on a fine screen, a whole number and a half), so the actual count is the nearest that fits the window.
PIXEL_LEVELS :: 6
PIXEL_ROWS := [PIXEL_LEVELS]f32{180, 240, 320, 360, 420, 560}
PIXEL_MARGIN :: 1

// ---- panels ----
// The pictures, bars and boxes over the meadow, and the menus. The panel at the top left, made for a child: a picture for each of his six needs with a bar under it (how full it is: orange and blinking when he lacks it, red when it has run out, purple when it is too much); his weight, as a mark on a bar of coloured bands (WEIGHT_BANDS: starving, lean, chubby, huge, too fat), with a heart blinking at its end when he is in danger at either end; and his stamina. What he weighs in kilograms, and each part, are on the BODY page of the M menu; what he needs he says himself (see STATE_TEXT). Returns how wide and how tall it is.

// how big a need's picture is, at 1280 by 720
HUD_ICON :: f32(30)
HUD_NEEDS :: [6]Need{.Carbs, .Protein, .Fibre, .Vitamins, .Electrolytes, .Water}
// the weight bar is this many kg from end to end
WEIGHT_SCALE :: f32(160)
WEIGHT_BANDS := [5]Weight_Band{{0, FAT_DANGER, {226, 70, 70, 255}}, {FAT_DANGER, FAT_LEAN, {170, 214, 110, 255}}, {FAT_LEAN, FAT_HUGE, {110, 190, 80, 255}}, {FAT_HUGE, FAT_MAX - FAT_DANGER, {244, 150, 60, 255}}, {FAT_MAX - FAT_DANGER, FAT_MAX, {226, 70, 70, 255}}}

// ---- sack ----
// boxes shown at most; beyond that the sack scrolls round
SACK_SLOTS :: 6

// ---- menus ----
SACK_COLUMNS :: 9

// ---- places ----
// seconds the line about a part of the meadow shows after he gets there
REGION_ABOUT_TIME :: f32(5)

