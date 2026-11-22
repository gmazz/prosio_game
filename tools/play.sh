#!/bin/sh
# Lets a program play the game a step at a time. The game runs in its own
# window and stands still until it is sent a command; each call of this
# script sends commands and prints the answers.
#
#   tools/play.sh start [options]     start a game (options as for a scripted
#                                     run: --pos, --needs, --seed, --stock ...)
#   tools/play.sh look                send one command, print the answer
#   tools/play.sh "walk 3 6" "tap a" "look"     or several, in order
#   tools/play.sh help                the commands and the button letters
#   tools/play.sh stop                close the game
#
# The game played this way never reads or writes the saved game. Everything
# said to it and by it is kept in build/play/in and build/play/out.
set -e
cd "$(dirname "$0")/.."
DIR=build/play

alive() {
	[ -f "$DIR/pid" ] && kill -0 "$(cat "$DIR/pid")" 2>/dev/null
}

# Waits for a line to appear in the answers after byte $1, at most $3 seconds.
await() {
	tries=0
	while ! tail -c "+$(($1 + 1))" "$DIR/out" | grep -q "$2"; do
		tries=$((tries + 1))
		if [ "$tries" -gt "$(($3 * 20))" ] || ! alive; then
			return 1
		fi
		sleep 0.05
	done
}

case "${1:-}" in
"")
	sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'
	;;
start)
	shift
	if alive; then
		echo "A game is already running; tools/play.sh stop closes it."
		exit 1
	fi
	./build_desktop.sh >/dev/null
	mkdir -p "$DIR"
	: > "$DIR/in"
	: > "$DIR/out"
	nohup ./build/desktop/prosio --agent "$DIR/in" "$@" >> "$DIR/out" 2>&1 &
	echo $! > "$DIR/pid"
	if await 0 "^Prosio, a step at a time" 20; then
		grep "^Prosio, a step at a time" "$DIR/out"
	else
		echo "The game did not start; see $DIR/out"
		exit 1
	fi
	;;
stop)
	if alive; then
		echo quit >> "$DIR/in"
		tries=0
		while alive && [ "$tries" -lt 60 ]; do
			tries=$((tries + 1))
			sleep 0.05
		done
		alive && kill "$(cat "$DIR/pid")" 2>/dev/null
		echo "Game closed."
	else
		echo "No game is running."
	fi
	rm -f "$DIR/pid"
	;;
*)
	if ! alive; then
		echo "No game is running; start one with: tools/play.sh start"
		exit 1
	fi
	from=$(($(wc -c < "$DIR/out")))
	mark="end-$$-$from"
	for command in "$@"; do
		echo "$command" >> "$DIR/in"
	done
	echo "mark $mark" >> "$DIR/in"
	if ! await "$from" "^mark $mark\$" 180; then
		tail -c "+$((from + 1))" "$DIR/out"
		echo "The game stopped answering; see $DIR/out"
		exit 1
	fi
	tail -c "+$((from + 1))" "$DIR/out" | grep -v "^mark $mark\$" | grep -v "^INFO: \|^WARNING: " || true
	;;
esac
