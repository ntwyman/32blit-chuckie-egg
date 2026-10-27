# Trace diff against the original

`run.sh` runs the port and Paul Brook's original C code on the same scripted input and compares their state frame by frame. Every gameplay change proves itself here: a script that matches the original prints `PASS`.

## Run it

```
tools/parity/run.sh --all
tools/parity/run.sh --script idle
tools/parity/run.sh --record held-through-death
tools/parity/run.sh --clock
tools/parity/run.sh --game-over
tools/parity/run.sh --self-test
```

`--all` prints one line per script in `scripts/`, `<name> PASS` or `<name> DIVERGES at frame <n> field <field>`, and exits zero only when every script matches what is expected of it:

- A script that passes must not be listed in `expected-divergent.txt`. A listed script that passes fails the run, so the list only shrinks.
- A script that diverges must be listed, and its full report must equal the one pinned in `<name>-divergences.txt`. A change that moves, adds, or removes any divergence fails the run and prints the difference.

`--script <name>` prints the full report: the result line, then one line per field that ever differs, with the first frame it differs on and both values. A `-` value means that side has no such field on that frame. Fields that first differ on the same frame keep the original's field order.

The last line of a diverging report, `every difference: <n> field values over <m> frames, sha256 <digest>`, covers every frame and field that differs, not only the first difference per field. The digest hashes the list of `<frame> <field> <port> <original>` for each differing value. Without it, a field that already differs would pass CI however it changed afterwards, so a listed script could regress unnoticed. A change to any later value of any field changes the digest and fails the run.

`--record <name>` rewrites `<name>-divergences.txt` from the current report. Run it only for a change the PR means to make, and say so in the PR, because the pinned reports are what holds later PRs to the original. When a fix makes a script pass, delete its report and its line in `expected-divergent.txt`.

`--clock` runs `clock_test`, which feeds `FrameClock::due` fixed timestamps and checks how many `Game::Step` calls it returns. The trace diff cannot see the clock, because it calls `Step` once per input frame. `--all` runs it after the scripts.

`--game-over` runs `game_over_test`, which plays five deaths and checks that A does not leave the game-over screen for its first 67 steps (about two seconds), and that a fresh press then does. It also plays a game that reaches level 2 to game over and checks that the next game starts on level 1 with level 1's bonus, lives, and score, where upstream starts it with the bonus of the level reached (see "Two quirks the port does not copy"). The trace diff cannot see the screen, because the original starts a new game at once. `--all` runs it after the clock test.

`--self-test` checks the comparator on fixed traces. CI runs it before `--all`.

`run.sh` configures and builds the `parity` target in `build.parity`, or in `PARITY_BUILD` when set. `PARITY_CMAKE_ARGS` passes extra configure flags, such as `-D32BLIT_DIR=<sdk>`. Traces and driver logs land in `build.parity/parity/traces/`.

## Input scripts

A script holds the buttons for each frame. Blank lines and text after `#` are ignored.

```
level 1
5 -
1 left+jump
29 left
```

- `level <n>` names the level, as the HUD numbers it, from 1 to 256. It is optional, must come before the frame lines, and defaults to 1.
- `score <n>` sets the score a new game starts with, from 1 to 99999999. It is optional, goes with the `level` line before the frame lines, and defaults to 0.
- `players <n>` sets the number of players, from 1 to 4. It is optional, goes with the `level` line before the frame lines, and defaults to 1.
- `<frames> <keys>` holds the keys for that many frames. `-` or no keys means no buttons. Keys are `right`, `left`, `down`, `up`, `jump`, and `skip`, joined with `+`.  A leading, trailing, or doubled `+` is an error.
- `skip` is upstream's debug level skip, the `l` key in its front ends, which sets `cheat` (`chuckie.c:1155`). The frame that holds it completes the level, as if the last egg were gone, unless Henry dies on that frame. The port's driver calls `Game::SkipLevel`, which exists only in the parity build.
- Frame 0 must not hold `jump`. The port enters the level on an A press, so a jump held into frame 0 is no new press there, while the original jumps. That difference would come from the driver, not the game.

## The drivers

Both drivers take `[--level <n>] [--score <n>] [--players <n>] <script.inputs>`, write one trace line per input frame to stdout, and send logs to stderr. `--level`, `--score` and `--players` override the script's lines.

- `build.parity/parity-port` runs `Game` with no screen. Before the first frame it presses up and releases once for each player past the first, then presses A, releases, and presses A again, to pass the how-many-players and ready screens. With more than one player the port stops on a "Ready player" screen after each death, where the original goes straight to the next player's level. After such a `Step` the driver releases A, presses it, and calls `Step` again with the script's buttons, so both traces hold the next player's first frame at the same index. It then calls `Game::Step` once per input frame and writes `Game::Snapshot` after it. With `--bench <frames>` after the script it writes no trace. It times that many `Game::Step` calls with the debug hook silenced, repeats the batch 200 times, and prints the median wall time. It refuses a count that runs past Henry's first death, because a game-over frame does almost nothing and would hide the cost of a live one. It also prints the mean time of one `Step` over the whole script, for information. To compare two builds, give both the same count, no larger than the earlier first death. The batch median is the perf metric, because the mean per `Step` sits near the timer's resolution and most of a script's frames come after Henry's first death.
- `build.parity/parity-original` builds `third_party/pbrook-chuckie-egg/chuckie.c` and `leveldata.c` with a raster that draws nothing and no sound. It sets the original's `buttons` from the script each frame and ignores `button_ack`, as upstream's SDL input does. It records the trace in `RenderFrame` and stops when the script runs out. If upstream calls `abort()`, the trace ends with a `frame=<n> abort=1` line.

Both sides record before their death and level-complete checks. `dead` is 1 on the frame Henry dies on both sides, and both then take the life and reload the level at the start of the next frame, so that frame shows one fewer life and the level as it restarts. A completed level works the same way. The frame the last egg goes, or `skip` is held, shows the level as it was. The next frame shows the bonus counted into the score, the next level loaded with its own bonus, timer and hens, and Henry's first move on it.

The port ignores a button held into a level start, including the start after a death and the start of the next level, until it is released (`chuckie.c:218` sets `button_ack`). The original driver ignores `button_ack`. A script that holds a key through a death or a level skip therefore differs by design, and `held-through-death` and `held-through-level-complete` pin those differences. The other scripts let go of every key on the respawn and the level-change frame.

After the last life of the last player the original starts a new game at once. The port shows its game-over screen, and a fresh press of A after 67 steps returns to the player-count screen. A script that goes on past that death compares the port's menu with the original's new game. `game-over` does so for one frame and pins the difference, so a port that replays the level at no lives, or restarts the game, differs from the pinned report. Every other script ends on or before the last death, which is why `long-play` ends on the fifth.

The `player` field is the player whose turn it is, so a wrong turn order shows even when the scores match. `two-players` and `four-players` match the original through several deaths of each player, and `four-players` also covers the turn order skipping players who have no lives left. `two-players-zero-bonus` diverges on `bonus` by design; see "Two quirks the port does not copy".

The build copies `chuckie.c` and applies `patches/*.patch` to the copy in name order, with no fuzz, so `third_party/` is never edited. `start-level.patch` makes a new game start on the requested level. `start-score.patch` gives a new game the requested score. `players.patch` makes `NUM_PLAYERS` (`chuckie.c:13`) the driver's player count. `timer-death.patch` deletes the `abort()` that upstream calls when the timer reaches zero (`chuckie.c:884`), so the timer kills Henry as it does in the port; the plan allows it in CE-6. `original_driver.c` also sets `current_level` once before the first game, so the start level gets its bonus and a restart after game over plays as upstream. A later change to the original is another patch. A patch that changes how the original plays makes it easier for the port to match, so name the plan item that allows it in the PR.

## The trace

`trace.h` defines `FrameTrace`, and `trace_write.h` writes it as `name=value` fields. Positions are in the original's units: x in pixels from the left of the play field, and y in pixels up from its bottom row. `Game::upstreamPosition` converts a port screen position with the exact inverse of `Game::tilePosition`: it removes `X_OFFSET` and maps screen row `Y` to `239 - Y`. The original anchors tile `(x, y)` at pixel `(x * 8, y * 8 + 7)` (`raster_4bit.c`), and that is where the inverse sends the tile's top-left corner. Never change the conversion to make a trace match. A position that differs after it is a real difference.

`Game::Snapshot`, `Game::upstreamPosition`, and the `trace.h` include compile only when `CHUCKIE_PARITY` is defined. Only the `parity-port` target defines it, so device and web builds hold no trace code.

The fields are Henry's x, y, tile, partial position, and mode, whether he died this frame, then the score, lives, bonus, timer, the player whose turn it is, and the level as the HUD numbers it minus one (`current_level`), then the lift positions on a level with a lift, the duck timer, the hen countdown that picks which hen moves next (`current_duck`), the mother duck's position, direction and wing frame, the hen count, and each hen's position and mode. The mother duck's position and wing frame are traced on every level, because upstream keeps the duck in its cage on levels 1 to 8 and flaps its wings there. Hens past the level's count are left out, because both games keep stale values there.

## Building without the 32Blit engine

`Game` cannot build for the host without the 32Blit engine. `game.cpp` calls `Surface::sprite`, `Surface::text`, `minimal_font`, and `debugf` from the engine library, and the engine library calls `blit::api` and `blit::api_data`, which only a platform layer defines. The SDK's SDL platform layer defines `main` and needs the game's `init`, `update`, and `render`, so a driver with its own `main` cannot link it. `port_driver.cpp` links the engine library and defines those two objects itself, with only the debug hook set. It never opens a window.

## Two quirks the port does not copy

Both read as bugs to a player, so the port plays the game as a player would expect. This is a decision, not a gap. Each is a difference a trace can show, and a later change that copies one of them would fail the pinned report.

**A restart after game over keeps the bonus of the level reached, and a stuck `zero_bonus`.** After the last death upstream goes to `new_game` at once (`chuckie.c:1139-1144`, `:1113`) with no game-over screen. `start_game` (`:1077-1090`) calls `ResetPlayer` (`:1046`) for each player before `RestorePlayerState` (`:1090`), so the new game's bonus comes from `current_level`, the level Henry had reached, not from level 1. The level itself is reset by `level[i] = 0`. `zero_bonus` (`:18`) is not reset either. It is set when a bonus counts down to 0 (`:778`) and cleared only when a level is completed (`:1169`). So a game that ended after the bonus ran out starts the next game with `zero_bonus` still set, and the timer path never takes a point off the bonus (`:891`).

Measured with the original driver, `skip` on frames 199 and 399 (two levels completed) and then idle until game over: the fifth death on level 3 is at frame 36379. Frame 36380 is a new game on level 1 with score 0, five lives, bonus 3000 (level 3's) and `zero_bonus` 1. The bonus stays 3000 through all five lives of that game, and the game after it starts with bonus 1000 and `zero_bonus` still 1. The port starts a new game from the player-count screen with level 1's bonus, and its bonus counts down. `game-over` pins the frame where the two games part: the original's lives, score and bonus are the new game's, and the port's are those of the dead player.

**`zero_bonus` is shared by every player.** It is one global (`:18`), so when one player's bonus reaches 0 (`:778`) it freezes every other player's bonus (`:891`), and it makes the level-complete loop award nothing (`:1157`) until a level is completed (`:1169`). Measured with two players idling on level 1 (`PROBE_PLAYERS=2` with the original driver): player 1's bonus reaches 0 at frame 8484, on its last life. Player 2 then plays from frame 8485 with its bonus frozen at 40 where it would have counted down. With `skip` on frame 8600, player 2 completes the level with 40 bonus left. Frame 8601 is level 2 with score 0 and bonus 2000, so the 40 bonus points are never awarded. The port keeps each player's bonus in that player's own data, so its bonus counts down and its level-complete award is paid. `two-players-zero-bonus` pins the difference: player 2's bonus differs from frame 8520 on, the first frame it would have dropped, and nothing else differs. `two-players-zero-bonus-complete` adds the `skip` on frame 8600: the port's bonus also differs from frame 8520 on, and from frame 8601 on its score holds the bonus it paid, where the original's stays 0.
