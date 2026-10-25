# Trace diff against the original

`run.sh` runs the port and Paul Brook's original C code on the same scripted input and compares their state frame by frame. Every gameplay change proves itself here: a script that matches the original prints `PASS`.

## Run it

```
tools/parity/run.sh --all
tools/parity/run.sh --script idle
tools/parity/run.sh --record idle
tools/parity/run.sh --self-test
```

`--all` prints one line per script in `scripts/`, `<name> PASS` or `<name> DIVERGES at frame <n> field <field>`, and exits zero only when every script matches what is expected of it:

- A script that passes must not be listed in `expected-divergent.txt`. A listed script that passes fails the run, so the list only shrinks.
- A script that diverges must be listed, and its full report must equal the one pinned in `<name>-divergences.txt`. A change that moves, adds, or removes any divergence fails the run and prints the difference.

`--script <name>` prints the full report: the result line, then one line per field that ever differs, with the first frame it differs on and both values. A `-` value means that side has no such field on that frame. Fields that first differ on the same frame keep the original's field order.

`--record <name>` rewrites `<name>-divergences.txt` from the current report. Run it only for a change the PR means to make, and say so in the PR, because the pinned reports are what holds later PRs to the original. When a fix makes a script pass, delete its report and its line in `expected-divergent.txt`.

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

- `level <n>` names the level, as the HUD numbers it, from 1 to 256. It is optional, must come first, and defaults to 1.
- `<frames> <keys>` holds the keys for that many frames. `-` or no keys means no buttons. Keys are `right`, `left`, `down`, `up`, and `jump`, joined with `+`.
- Frame 0 must not hold `jump`. The port enters the level on an A press, so a jump held into frame 0 is no new press there, while the original jumps. That difference would come from the driver, not the game.

## The drivers

Both drivers take `[--level <n>] <script.inputs>`, write one trace line per input frame to stdout, and send logs to stderr. `--level` overrides the script's level line.

- `build.parity/parity-port` runs `Game` with no screen. Before the first frame it presses A, releases, and presses A again, to pass the how-many-players and ready screens. It then calls `Game::Step` once per input frame and writes `Game::Snapshot` after it. With `--bench` after the script it writes no trace and prints the mean time of one `Game::Step`, over the whole script and over the frames up to Henry's first death.
- `build.parity/parity-original` builds `third_party/pbrook-chuckie-egg/chuckie.c` and `leveldata.c` with a raster that draws nothing and no sound. It sets the original's `buttons` from the script each frame and ignores `button_ack`, as upstream's SDL input does. It records the trace in `RenderFrame` and stops when the script runs out. If upstream calls `abort()`, the trace ends with a `frame=<n> abort=1` line.

The two sides record at slightly different points. The original records before its death and level-complete checks. The port records after `Step`, which has already moved to its game-over screen on a death and has already counted the bonus into the score when the last egg goes. So `dead` is 1 on the frame Henry dies on both sides, but on the frame a level ends the port's score and bonus show the count one frame early.

The build copies `chuckie.c` and applies `patches/*.patch` to the copy in name order, with no fuzz, so `third_party/` is never edited. `start-level.patch` makes a new game start on the requested level. A later change to the original, such as making the timer kill Henry rather than abort, is another patch. A patch that changes how the original plays makes it easier for the port to match, so name the plan item that allows it in the PR.

## The trace

`trace.h` defines `FrameTrace`, and `trace_write.h` writes it as `name=value` fields. Positions are in the original's units: x in pixels from the left of the play field, and y in pixels up from its bottom row. `Game::upstreamPosition` converts a port screen position with the exact inverse of `Game::tilePosition`: it removes `X_OFFSET` and maps screen row `Y` to `239 - Y`. The original anchors tile `(x, y)` at pixel `(x * 8, y * 8 + 7)` (`raster_4bit.c`), and that is where the inverse sends the tile's top-left corner. Never change the conversion to make a trace match. A position that differs after it is a real difference.

`Game::Snapshot`, `Game::upstreamPosition`, and the `trace.h` include compile only when `CHUCKIE_PARITY` is defined. Only the `parity-port` target defines it, so device and web builds hold no trace code.

The fields are Henry's x, y, tile, partial position, and mode, whether he died this frame, then the score, lives, bonus, and timer, then the lift positions on a level with a lift, the duck timer, the hen countdown that picks which hen moves next (`current_duck`), the hen count, and each hen's position and mode. Hens past the level's count are left out, because both games keep stale values there.

## Building without the 32Blit engine

`Game` cannot build for the host without the 32Blit engine. `game.cpp` calls `Surface::sprite`, `Surface::text`, `minimal_font`, and `debugf` from the engine library, and the engine library calls `blit::api` and `blit::api_data`, which only a platform layer defines. The SDK's SDL platform layer defines `main` and needs the game's `init`, `update`, and `render`, so a driver with its own `main` cannot link it. `port_driver.cpp` links the engine library and defines those two objects itself, with only the debug hook set. It never opens a window.
