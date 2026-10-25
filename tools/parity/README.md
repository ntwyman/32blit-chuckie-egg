# Trace diff against the original

`run.sh` runs the port and Paul Brook's original C code on the same scripted input and compares their state frame by frame. Every gameplay change proves itself here: a script that matches the original prints `PASS`.

## Run it

```
tools/parity/run.sh --all
tools/parity/run.sh --script idle
```

`--all` prints one line per script in `scripts/`, `<name> PASS` or `<name> DIVERGES at frame <n> field <field>`. It exits zero when the results match `expected-divergent.txt`. A script that diverges but is not listed fails the run, and so does a listed script that passes, so the list only shrinks.

`--script <name>` prints the same line, then one line per field that ever differs: the first frame it differs on and both values. A `-` value means that side has no such field on that frame.

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

## The drivers

Both drivers take `[--level <n>] <script.inputs>`, write one trace line per input frame to stdout, and send logs to stderr. `--level` overrides the script's level line.

- `build.parity/parity-port` runs `Game` with no screen. It calls `Game::Step` once per input frame and writes `Game::Snapshot` after it. Before the first frame it presses A, releases, and presses A again, to pass the how-many-players and ready screens. With `--bench` after the script it writes no trace and prints the mean time of one `Game::Step`.
- `build.parity/parity-original` builds `third_party/pbrook-chuckie-egg/chuckie.c` and `leveldata.c` with a raster that draws nothing and no sound. It records the trace in `RenderFrame`, after the frame's movement and before the death and level-complete checks, and stops when the script runs out. If upstream calls `abort()`, the trace ends with a `frame=<n> abort=1` line.

The build copies `chuckie.c` and applies `patches/*.patch` to the copy in name order, so `third_party/` is never edited. `start-level.patch` makes a new game start on the requested level. A later change to the original, such as making the timer kill Henry rather than abort, is another patch.

## The trace

`trace.h` defines `FrameTrace` and writes it as `name=value` fields. Positions are in the original's units: x in pixels from the left of the play field, and y in pixels up from its bottom row. `Game::upstreamPosition` converts a port screen position with the exact inverse of `Game::tilePosition`: it removes `X_OFFSET` and maps screen row `Y` to `239 - Y`. The original anchors tile `(x, y)` at pixel `(x * 8, y * 8 + 7)` (`raster_4bit.c`), and that is where the inverse sends the tile's top-left corner. Never change the conversion to make a trace match. A position that differs after it is a real difference.

The fields are Henry's x, y, tile, partial position, and mode, then the score, lives, bonus, and timer, then the lift positions on a level with a lift, the duck timer, the hen countdown that picks which hen moves next (`current_duck`), the hen count, and each hen's position and mode. Hens past the level's count are left out, because both games keep stale values there.

## Building without the 32Blit engine

`Game` cannot build for the host without the 32Blit engine. `game.cpp` calls `Surface::sprite`, `Surface::text`, `minimal_font`, and `debugf` from the engine library, and the engine library calls `blit::api` and `blit::api_data`, which only a platform layer defines. The SDK's SDL platform layer defines `main` and needs the game's `init`, `update`, and `render`, so a driver with its own `main` cannot link it. `port_driver.cpp` links the engine library and defines those two objects itself, with only the debug hook set. It never opens a window.
