#!/bin/sh
# Takes a set of screenshots of the game for looking over: every part of the
# meadow, every menu, the outfits and a few unusual states. They go into
# build/tour (or the folder given as the first argument) as PNG files, with
# an index.txt saying what each one should show.
#
#   tools/tour.sh
#   tools/tour.sh some/folder
#   TOUR_LANG=pl tools/tour.sh build/tour_pl     (in another language: a file in data/text)
#
# It builds the desktop game first and runs it once for each picture, which
# opens a window for a moment each time; the whole tour takes about a minute.
set -e
cd "$(dirname "$0")/.."
OUT="${1:-build/tour}"
mkdir -p "$OUT"
./build_desktop.sh >/dev/null
: > "$OUT/index.txt"

# shot_at FRAME NAME "what it should show" options...
# Beside each picture goes NAME.txt: how Prosio is at that moment, in numbers.
shot_at() {
	frame="$1"
	name="$2"
	about="$3"
	shift 3
	rm -f "$OUT/$name.png" "$OUT/$name.txt" # so that an old picture is never taken for a new one
	./build/desktop/prosio "$@" ${TOUR_LANG:+--lang "$TOUR_LANG"} --shot "$OUT/$name.png" --frame "$frame" 2>/dev/null | grep -v "^INFO\|^WARNING" > "$OUT/$name.txt" || true
	if [ -f "$OUT/$name.png" ]; then
		echo "$name.png: $about" >> "$OUT/index.txt"
	else
		echo "$name.png: MISSING ($about)" >> "$OUT/index.txt"
	fi
}

# The same on frame 40, two thirds of a second in.
shot() {
	shot_at 40 "$@"
}

# The parts of the meadow.
shot home "Home, as the game starts: the paths leaving the yard, the oven up and to the left (partly under the panels), and the panel of what he is made of (80.0 kg, the sum of its rows)" --pos 6 6
shot forest "The forest: trees all through, spaced apart; the trail to the clearings; the trees round Prosio see-through" --pos -42 -12
shot clearing "A forest clearing: berry bushes and wild apple trees round it, the trail running through" --pos -50 -14
shot fields "The wheat fields and the mill, nothing in front of them" --pos 43 26
shot garden "The garden: pumpkin beds and the cabbage bed, crops at different sizes" --pos -17 49.5
shot turkeys "Turkey meadow, with turkeys closing in" --pos 14 -42
shot hills "The goat hills: a salt rock with pink crystals, rocks, pines, goats" --pos 81.9 -27.2
shot churn "The churn in the goat hills, with its stool" --pos 57.5 -31
shot pond "The pond: water, lily pads, bulrushes, fish; the prompt offers a drink" --pos -23 -38.5 --hold u --release-at 40
shot_at 70 fire "The cooking fire and chopping block by the pond" --pos -17.5 -41
shot bees "The bee meadow: three straw hives, flowers, bees" --pos -50 55
shot wood "Fallen branches under the forest trees, to his right: pale, so that they show on the forest floor" --pos -47.1 -6.0
shot workbench "The workbench at home, across the yard from the oven: a table with a saw and a mallet on it, planks leaning against it" --pos 3.8 8.2

# The menus.
shot menu_main "The main menu" --menu
shot menu_oven "The oven's menu: six recipes, what each needs, how many to make" --pos -4 -0.3 --stock --tap a
shot menu_fire "The fire's menu: fried egg, grilled fish, roast meat" --pos -15.5 -41.7 --stock --tap a
shot menu_bench "The workbench's menu: six plans (fence, scarecrow, rod, spear, gate, larder), what each is for and what it needs" --pos 1.5 8.8 --stock --tap a
shot bag_sack "The sack panel: 33 things in a grid of nine across, the chosen one's freshness, and its composition" --pos 6 6 --stock --tap m
shot bag_body "The body panel: his weight as the sum of his parts, then muscles and skills" --pos 6 6 --stock --tap m --tap2 c --tap2-at 14
shot_at 120 bag_outfit "The outfit panel: a row for each piece, Prosio shown close up" --pos 6 6 --hold m --tap c --tap-at 12 --tap2 c --tap2-at 16
shot bag_map "The map panel: dark except where he has been" --pos 6 6 --tap m --tap2 z --tap2-at 14

# Whole outfits, front on (he turns slowly in the outfit panel).
for n in 0 1 2 3 4 5 6 7; do
	shot_at 432 "outfit_$n" "Whole outfit $n from the front: nothing underneath pokes through" --pos 6 6 --outfit "$n" --hold m --tap c --tap-at 12 --tap2 c --tap2-at 16
done
shot_at 230 outfit_coat_back "A long coat over a T-shirt, from behind: his back fully covered" --pos 6 6 --outfit 00000002200 --hold m --tap c --tap-at 12 --tap2 c --tap2-at 16

# Animals and unusual states.
shot_at 30 animals "A dead turkey and a dead goat (crosses for eyes), a fox running off with an apple in its mouth, and a rabbit making off at the bottom" --pos 6 5 --bodies
shot_at 80 holding "Holding a turkey by the feet; the prompt says what SPACE and F do" --pos 6 5 --crowd --tap g --tap-at 12
shot_at 70 holding_goat "Holding a goat by both hind legs, a hoof on each; the prompt offers to milk her" --pos 6 5 --near goat --tap g --tap-at 12 --hold l
shot_at 70 holding_fox "Holding a fox by its tail" --pos 6 5 --near fox --tap g --tap-at 12 --hold l
shot_at 170 licking "A salty Prosio: the goat stands licking him, and the prompt offers to milk her without a grab" --pos 6 5 --near goat --needs 50,50,50,80,50,95
shot_at 50 aiming "Winding up a pebble: a yellow arrowhead over the turkey he aims at, a bar at his feet, the pebble in his raised hoof" --pos 6 5 --near turkey --far --pebbles --hold g
shot built "What he builds: a turkey in a pen whose near side is a gate (a leaf with a brace and a latch), a larder (a cupboard on legs, salt at its foot), a scarecrow, a spear stuck in the ground, and a yellow mark where Q would put the piece of fence chosen in the sack; the sack line says 14 / 60 L" --pos 6 6 --built
shot swimmers "Animals in the pond: a turkey and a goat low in the water paddling for the bank, a drowned turkey floating feet up" --pos -26 -38.5 --swimmers
shot_at 50 spear "Winding up the spear at the turkey in the pen: a yellow arrowhead over it, a bar at his feet, the spear over his shoulder" --pos 6 7 --built --choose Spear --hold g --tap r --tap-at 20
shot_at 24 rod "Casting the rod from the pond's bank: the rod up, a line out to a red and white float on the water" --pos -24 -40.7 --built --choose Rod --tap g --tap-at 12
shot bruised "Bruised: the far end of the stamina bar is purple, with BRUISED on it, and out of reach" --pos 6 6 --bruises 50
shot body_strong "Lean and strong: 66.0 kg, the little fat he has shows as a short yellow piece, muscle as a long red one; stores full" --pos 6 6 --kg 66 --traits 1,1,0.8,1,0.5,0.3,0.6,0.6,0.6 --needs 95,95,90,95,50,50
shot body_starved "Nearly out of everything: 40.0 kg, fat low, stores low, advice on what to eat" --pos 6 6 --kg 40 --traits -1,-1,0,0,0,0,0,0,0 --needs 5,10,10,20,10,10
shot too_much "Too much of things: hiccups, gas storm, glowing orange, parched" --pos 6 6 --needs 96,96,96,60,96,96

# Half-size copies, quicker to look through (macOS has sips; elsewhere the
# full-size pictures are all there is).
if command -v sips >/dev/null 2>&1; then
	mkdir -p "$OUT/small"
	for f in "$OUT"/*.png; do
		sips -Z 1280 "$f" --out "$OUT/small/$(basename "$f")" >/dev/null 2>&1 || true
	done
fi

echo "Took $(grep -vc MISSING "$OUT/index.txt") pictures into $OUT ($(grep -c MISSING "$OUT/index.txt") missing); see $OUT/index.txt"
if ! grep -qv MISSING "$OUT/index.txt"; then
	echo "None could be taken: the game needs a screen to open its window on. Is the display asleep?"
fi
