# Drive the SDL build

`drive.sh` runs the SDL build under `Xvfb`, sends it keys with `xdotool`, and takes screenshots and video. No control skill covers a 32Blit window, so this is the control recipe for it.

## Prerequisites

- The SDL build at `build.sdl/chuckie-egg`. Build it with `cmake -B build.sdl && cmake --build build.sdl -j`. Set `LIVE_BIN` to use another path.
- `Xvfb`, `xdotool`, ImageMagick (`import` and `compare`), and `ffmpeg`. The dev container has them.

## Commands

| Command | What it does |
| --- | --- |
| `drive.sh start` | Starts `Xvfb` and the game. If the game already runs, it says so and does nothing. |
| `drive.sh keys <script>` | Sends a key script. A `<script>` with a `/` is a path. A bare name is looked up in `tools/live/scripts/` (as given, then with `.keys`) and only then in the current directory. Use `./name.keys` for a file in the current directory. An empty script does nothing and exits zero. |
| `drive.sh shot <path>` | Saves a screenshot of the display as a PNG. |
| `drive.sh record <seconds> <path>` | Records the display as an MP4 for that long. It blocks, so run it in the background while a key script plays. |
| `drive.sh stop` | Stops the game and `Xvfb`. It exits zero when nothing runs. |
| `drive.sh smoke` | Starts a fresh game, starts one player, and compares the first frame of level 1 with `golden/level1-start.png`. It prints `smoke: ok` and writes `out/lane<n>/smoke.png`. |

The game's `debugf` output goes to `$LIVE_STATE/game.log`, where `LIVE_STATE` defaults to `/tmp/chuckie-live-<display>`.

## Display size

The SDL window is 640x480. `Xvfb` must be at least that size, or the root window shows black. `drive.sh` starts `Xvfb` at 640x480x24. Do not shrink it to the 320x240 of the game's own screen.

## Key scripts

A script has one step per line. Blank lines and text after `#` are ignored.

```
<key> <hold-ms>
wait <ms>
```

`drive.sh` checks the whole script before it sends a key. A bad line stops it with exit code 2 and a message that names the file and line.

| Key | Game input |
| --- | --- |
| `up`, `down`, `left`, `right` | The d-pad. `w`, `a`, `s`, `d` work too. |
| `z` | The A button. It starts the game, readies a player, and jumps. |
| `x`, `c`, `v` | The B, X, and Y buttons. |
| `u`, `i`, `o`, `p` | A, B, X, and Y again, as in the SDK's key map. |
| `1`, `2`, `3`, `esc` | Home, menu, and the joystick button. |

Join keys with `+` to hold them together, as in `left+up 330`.

From boot, `z` at "How many players" and `z` at "Ready player" starts play. `scripts/start-one-player.keys` does this. Run it first, then another script.

| Script | What it does |
| --- | --- |
| `start-one-player.keys` | Starts a one-player game and lands on level 1. |
| `walk-right.keys` | Walks Henry right along the floor for two seconds. |
| `jump.keys` | Holds the jump key for 500 ms. |
| `climb-first-ladder.keys` | Walks to the big ladder on level 1 with up held, so Henry grabs it, then climbs. |

Henry grabs a ladder only on one exact pixel, and the game steps on wall-clock time. `left+up` held while walking past the ladder grabs it without aiming.

## Running lanes in parallel

`LIVE_LANE=<n>` puts the game on display `:<99+n>` with its own state directory, so lanes never share a display. `LIVE_DISPLAY` sets the display number directly.

## How `smoke` stays exact

The game steps on wall-clock time, so a screenshot at a fixed delay shows a different frame each run. `smoke` records the display at 100 frames per second while `start-one-player.keys` runs. The recording shows three screens in order: "How many players", "Ready player", and level 1. `smoke` takes the first frame of the third run of identical frames, writes it to `smoke.png`, and compares that one frame with the golden image using `compare -metric AE`. Any differing pixel fails the run. It does not search other frames.

`smoke` retries only when the run itself failed: the game or its window did not start, the recorder died, or the recording has no level-1 frame. It prints why before each retry. A pixel mismatch fails at once.

One HUD pixel is heap garbage that differs per process: the TIME sprite reads past the end of the sprite sheet (issue #17). Until that is fixed, `smoke` fails on the runs where that pixel differs from the one baked into the golden image. Regenerate the golden image once the fix lands.

`smoke` and `golden` need exactly 640x480. They stop with a message for any other `LIVE_SCREEN`.

On a failed `smoke`, `out/lane<n>/` holds `smoke.png` (the selected frame, or the last frame when none was level 1) and `game.log`.

To regenerate the golden image after a deliberate change to the first frame of level 1, run `drive.sh golden tools/live/golden/level1-start.png`. Review the image before you commit it.

## Environment

| Variable | Default | Meaning |
| --- | --- | --- |
| `LIVE_LANE` | `0` | Lane number. The display is `:<99+lane>`. |
| `LIVE_DISPLAY` | `99+lane` | Display number. |
| `LIVE_SCREEN` | `640x480x24` | `Xvfb` screen. Use 640x480 or larger for the other commands. `smoke` and `golden` need exactly 640x480. |
| `LIVE_BIN` | `build.sdl/chuckie-egg` | The game binary. |
| `LIVE_STATE` | `/tmp/chuckie-live-<display>` | Pid files, logs, and recordings. |
| `LIVE_OUT_DIR` | `tools/live/out/lane<n>` | Where `smoke` writes `smoke.png`. |
| `LIVE_SMOKE_ATTEMPTS` | `5` | How many runs `smoke` tries when a run itself fails. |
| `LIVE_WINDOW_WAIT` | `10` | Seconds `start` waits for `Xvfb` to answer, and again for the game window, before it fails. A busy CI runner can take several seconds to start `Xvfb` when two lanes start together. |

`LIVE_LANE`, `LIVE_DISPLAY`, `LIVE_SMOKE_ATTEMPTS`, and `LIVE_WINDOW_WAIT` must be whole numbers.

## Processes and logs

The pid files record each process's start time as well as its pid. `start` and `stop` act on a pid only when it is still the process the driver started, so a reused pid is never killed. `stop` sends `TERM`, waits up to three seconds, then sends `KILL`. It also stops any recorder the lane started, including a background `record`.

`stop` removes recordings and logs. After a failed `start` or `smoke` it keeps the logs and prints the state folder.

`start` removes a stale `/tmp/.X<n>-lock` only when no live process holds it. If a live process holds the lock and the display does not answer, `start` fails and names the pid.

## Tests

`tools/live/test-drive.sh` checks the driver's edge cases and finishes in under a minute. `tools/live/test-smoke.sh` runs `smoke` ten times and checks frame selection. Set `DRIVE` to test another copy of `drive.sh`.
