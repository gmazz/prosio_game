package game

// Made by tools/gen_data from data/tuning/screen.json: do not edit; edit that file.

// How the game looks on the screen: the camera, the pixel sizes, and the sizes and timings of what is drawn over the meadow.

// ---- camera ----
// Where the camera sits, relative to the point it looks at.
CAMERA_OFFSET :: Vec3{0, 8.5, 10.6}
// test meadow portrait distance, camera rise, target height and side angle
LAB_CAMERA :: [4]f32{0.29, 2.6, 1.37, 0.31}
// closest and widest test meadow play camera
LAB_ZOOM :: Vec2{0.44, 1.5}

// ---- test_meadow ----
// candidate directions to place a fixture around Prosio
LAB_PLACEMENT_STEPS :: 16
// clear ground left between Prosio or a landmark and a test fixture
LAB_PLACEMENT_GAP :: f32(0.34)
// clearance for an apple fixture
LAB_APPLE_RADIUS :: f32(0.25)
// radius of the liftable test rock
LAB_ROCK_RADIUS :: f32(0.62)
// duration of the unavailable-action notice
LAB_NOTICE_SECONDS :: f32(2)

// ---- forest_view ----
// in the forest, how much further round him the trees turn see-through (in crowns)
FOREST_REVEAL :: f32(0.9)

// ---- pixels ----
// The world is drawn into a small image, which is then enlarged without smoothing, so it comes out as crisp pixels. How fine the pixels are: nine levels, picked with the number keys 1 to 9 (5, 6 and 7 lie between the old 4 and 5). Each is about this many rows of pixels from top to bottom. Each game pixel is a whole number of real screen pixels (or, on a fine screen, a whole number and a half), so the actual count is the nearest that fits the window.
PIXEL_LEVELS :: 9
// rows of pixels from top to bottom at each of the nine levels: fewer rows, bigger pixels
PIXEL_ROWS := [PIXEL_LEVELS]f32{180, 240, 320, 360, 405, 439, 478, 526, 560}
// from this level (counting from 0) a pixel may be a quarter of a real pixel bigger or smaller, not only a half: the levels between the old 4 and 5
PIXEL_QUARTERS_FROM :: 4
// a border this many game pixels wide drawn round the small image, just past the window's edge
PIXEL_MARGIN :: 1

// ---- panels ----
// The pictures, bars and boxes over the meadow, and the menus. The panel at the top left, made for a child: a picture for each of his six needs with a bar under it (how full it is: orange and blinking when he lacks it, red when it has run out, purple when it is too much); his weight, as a mark on a bar of coloured bands (WEIGHT_BANDS: starving, lean, chubby, huge, too fat), with a heart blinking at its end when he is in danger at either end; and his stamina. After the weight bar, what he weighs in whole kilograms; each part of it is on the BODY page of the M menu. What he needs he says himself (TEXT.say_low and the rest). Returns how wide and how tall it is.

// how big a need's picture is, at 1280 by 720
HUD_ICON :: f32(30)
// the room between the top of him (head, hair or hat) and his speech bubble, at 1280 by 720
BUBBLE_GAP :: f32(14)
// how thick the grey edge round his speech bubble is
BUBBLE_EDGE :: f32(2)
// the room between the game's name on the main menu and the line under it, at 1280 by 720
SUBTITLE_GAP :: f32(22)
// the six needs on the panel, in order from left to right
HUD_NEEDS :: [6]Need{.Carbs, .Protein, .Fibre, .Vitamins, .Electrolytes, .Water}
// the weight bar is this many kg from end to end
WEIGHT_SCALE :: f32(160)
// the weight bar's bands: from what fat to what fat (kg), and the colour of each
WEIGHT_BANDS := [5]Weight_Band{{0, FAT_DANGER, {226, 70, 70, 255}}, {FAT_DANGER, FAT_LEAN, {170, 214, 110, 255}}, {FAT_LEAN, FAT_HUGE, {110, 190, 80, 255}}, {FAT_HUGE, FAT_MAX - FAT_DANGER, {244, 150, 60, 255}}, {FAT_MAX - FAT_DANGER, FAT_MAX, {226, 70, 70, 255}}}
// metres wide
HEALTH_BAR :: f32(0.9)

// ---- sack ----
// boxes shown at most; beyond that the sack scrolls round
SACK_SLOTS :: 6

// ---- menus ----
// boxes in each row of the sack page of the M menu
SACK_COLUMNS :: 9
// where the main and pause menus' first choice is, as a share of the screen's height
MENU_TOP :: f32(0.44)
// from one of their choices to the next, at 1280 by 720
MENU_STEP :: f32(56)
// the BODY page's lines are brought closer together when a short window would push them past the help at its bottom: down to this share of their usual spacing, and no closer
SQUEEZE_MOST :: f32(0.85)
// a help line too long for its menu is made smaller, down to this share of its size (and no smaller than the letters go), before it is broken onto two lines
FIT_SMALLEST :: f32(0.7)

// ---- places ----
// seconds the line about a part of the meadow shows after he gets there
REGION_ABOUT_TIME :: f32(5)

