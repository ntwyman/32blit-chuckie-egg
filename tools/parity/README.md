# Trace diff against the original

`run.sh` runs the port and Paul Brook's original C code on the same scripted input and compares their state frame by frame. Every gameplay change proves itself here: a script that matches the original prints `PASS`.

## Run it

```
tools/parity/run.sh --all
tools/parity/run.sh --script idle
tools/parity/run.sh --record held-through-death
tools/parity/run.sh --clock
tools/parity/run.sh --self-test
```

`--all` prints one line per script in `scripts/`, `<name> PASS` or `<name> DIVERGES at frame <n> field <field>`, and exits zero only when every script matches what is expected of it:

- A script that passes must not be listed in `expected-divergent.txt`. A listed script that passes fails the run, so the list only shrinks.
- A script that diverges must be listed, and its full report must equal the one pinned in `<name>-divergences.txt`. A change that moves, adds, or removes any divergence fails the run and prints the difference.

`--script <name>` prints the full report: the result line, then one line per field that ever differs, with the first frame it differs on and both values. A `-` value means that side has no such field on that frame. Fields that first differ on the same frame keep the original's field order.

The last line of a diverging report, `every difference: <n> field values over <m> frames, sha256 <digest>`, covers every frame and field that differs, not only the first difference per field. The digest hashes the list of `<frame> <field> <port> <original>` for each differing value. Without it, a field that already differs would pass CI however it changed afterwards, so a listed script could regress unnoticed. A change to any later value of any field changes the digest and fails the run.

`--record <name>` rewrites `<name>-divergences.txt` from the current report. Run it only for a change the PR means to make, and say so in the PR, because the pinned reports are what holds later PRs to the original. When a fix makes a script pass, delete its report and its line in `expected-divergent.txt`.

`--clock` runs `clock_test`, which feeds `FrameClock::due` fixed timestamps and checks how many `Game::Step` calls it returns. The trace diff cannot see the clock, because it calls `Step` once per input frame. `--all` runs it after the scripts.

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
- `<frames> <keys>` holds the keys for that many frames. `-` or no keys means no buttons. Keys are `right`, `left`, `down`, `up`, and `jump`, joined with `+`.  A leading, trailing, or doubled `+` is an error.
- Frame 0 must not hold `jump`. The port enters the level on an A press, so a jump held into frame 0 is no new press there, while the original jumps. That difference would come from the driver, not the game.

## The drivers

Both drivers take `[--level <n>] [--score <n>] <script.inputs>`, write one trace line per input frame to stdout, and send logs to stderr. `--level` and `--score` override the script's lines.

- `build.parity/parity-port` runs `Game` with no screen. Before the first frame it presses A, releases, and presses A again, to pass the how-many-players and ready screens. It then calls `Game::Step` once per input frame and writes `Game::Snapshot` after it. With `--bench <frames>` after the script it writes no trace. It times that many `Game::Step` calls with the debug hook silenced, repeats the batch 200 times, and prints the median wall time. It refuses a count that runs past Henry's first death, because a game-over frame does almost nothing and would hide the cost of a live one. It also prints the mean time of one `Step` over the whole script, for information. To compare two builds, give both the same count, no larger than the earlier first death. The batch median is the perf metric, because the mean per `Step` sits near the timer's resolution and most of a script's frames come after Henry's first death.
- `build.parity/parity-original` builds `third_party/pbrook-chuckie-egg/chuckie.c` and `leveldata.c` with a raster that draws nothing and no sound. It sets the original's `buttons` from the script each frame and ignores `button_ack`, as upstream's SDL input does. It records the trace in `RenderFrame` and stops when the script runs out. If upstream calls `abort()`, the trace ends with a `frame=<n> abort=1` line.

The two sides record at slightly different points. The original records before its death and level-complete checks. The port records after `Step`, which has already counted the bonus into the score when the last egg goes. So on the frame a level ends the port's score and bonus show the count one frame early. `dead` is 1 on the frame Henry dies on both sides. Both then take the life and reload the level at the start of the next frame, so that frame shows one fewer life and the level as it restarts.

The port ignores a button held into a level start, including the start after a death, until it is released (`chuckie.c:218` sets `button_ack`). The original driver ignores `button_ack`. A script that holds a key through a death therefore differs by design, and `held-through-death` pins that difference. The other scripts let go of every key on the respawn frame.

After Henry's last life the original starts a new game at once. The port shows its game-over screen, and a press of A returns to the player-count screen. A script that goes on past the last death would only compare the port's menu with the original's new game, so `long-play` ends on the fifth death.

The build copies `chuckie.c` and applies `patches/*.patch` to the copy in name order, with no fuzz, so `third_party/` is never edited. `start-level.patch` makes a new game start on the requested level. `start-score.patch` gives a new game the requested score. `timer-death.patch` deletes the `abort()` that upstream calls when the timer reaches zero (`chuckie.c:884`), so the timer kills Henry as it does in the port; the plan allows it in CE-6. `original_driver.c` also sets `current_level` once before the first game, so the start level gets its bonus and a restart after game over plays as upstream. A later change to the original is another patch. A patch that changes how the original plays makes it easier for the port to match, so name the plan item that allows it in the PR.

## The trace

`trace.h` defines `FrameTrace`, and `trace_write.h` writes it as `name=value` fields. Positions are in the original's units: x in pixels from the left of the play field, and y in pixels up from its bottom row. `Game::upstreamPosition` converts a port screen position with the exact inverse of `Game::tilePosition`: it removes `X_OFFSET` and maps screen row `Y` to `239 - Y`. The original anchors tile `(x, y)` at pixel `(x * 8, y * 8 + 7)` (`raster_4bit.c`), and that is where the inverse sends the tile's top-left corner. Never change the conversion to make a trace match. A position that differs after it is a real difference.

`Game::Snapshot`, `Game::upstreamPosition`, and the `trace.h` include compile only when `CHUCKIE_PARITY` is defined. Only the `parity-port` target defines it, so device and web builds hold no trace code.

The fields are Henry's x, y, tile, partial position, and mode, whether he died this frame, then the score, lives, bonus, and timer, then the lift positions on a level with a lift, the duck timer, the hen countdown that picks which hen moves next (`current_duck`), the hen count, and each hen's position and mode. Hens past the level's count are left out, because both games keep stale values there.

## Building without the 32Blit engine

`Game` cannot build for the host without the 32Blit engine. `game.cpp` calls `Surface::sprite`, `Surface::text`, `minimal_font`, and `debugf` from the engine library, and the engine library calls `blit::api` and `blit::api_data`, which only a platform layer defines. The SDK's SDL platform layer defines `main` and needs the game's `init`, `update`, and `render`, so a driver with its own `main` cannot link it. `port_driver.cpp` links the engine library and defines those two objects itself, with only the debug hook set. It never opens a window.
