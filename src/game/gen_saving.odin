package game

// Made by tools/gen_data from data/tuning/saving.json: do not edit; edit that file.

// Keeping his game from one sitting to the next: the saved game, written every so often, and the backups of it made before he starts over or loads another (see the README, Saving, backups and loading).

// ---- saving ----
// The saved game is written while he plays, and when the game is paused or left for the menu. Before Restart or Load throws the game away, the saved game is first copied to a backup named for when it was saved (prosio_DDMMYY_HHMMSS.sav); LOAD on the menus lists the backups, newest first.

// seconds between saves while he plays
SAVE_EVERY :: f32(15)
// the folder, beside the saved game, the backups are written to (on the desktop; the browser keeps them in its own storage)
BACKUP_FOLDER :: "saves"
// how many backups the LOAD list shows, the newest; every backup is kept all the same
BACKUP_LIST :: 50
// how many backups the browser keeps, the newest (its storage is small)
WEB_BACKUPS :: 10

