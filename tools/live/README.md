# Drive the SDL build

`drive.sh` runs the SDL build under `Xvfb`, sends it keys with `xdotool`, and takes screenshots and video. No control skill covers a 32Blit window, so this is the control recipe for it.

## Prerequisites

- The SDL build at `build.sdl/chuckie-egg`. Build it with `cmake -B build.sdl && cmake --build build.sdl -j`. Set `LIVE_BIN` to use another path.
- `Xvfb`, `xdotool`, ImageMagick (`import` and `compare`), and `ffmpeg`. The dev container has them.

## Commands

| Command | What it does |
| --- | --- |
| `drive.sh start` | Starts `Xvfb` and the game. If the game already runs, it says so and does nothing. |
| `drive.sh keys <script>` | Sends a key script. `<script>` is a path, or a name in `tools/live/scripts/`. |
| `drive.sh shot <path>` | Saves a screenshot of the display as a PNG. |
| `drive.sh record <seconds> <path>` | Records the display as an MP4 for that long. It blocks, so run it in the background while a key script plays. |
| `drive.sh stop` | Stops the game and `Xvfb`. It exits zero when nothing runs. |
| `drive.sh smoke` | Starts a fresh game, starts one player, and compares the first frame of level 1 with `golden/level1-start.png`. It prints `smoke: ok` and writes `out/smoke.png`. |

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
| `1`, `2`, `3`, `esc` | Home, menu, and the joystick button. |

From boot, `z` at "How many players" and `z` at "Ready player" starts play. `scripts/start-one-player.keys` does this. `scripts/walk-right.keys` walks Henry right along the floor.

## Running lanes in parallel

`LIVE_LANE=<n>` puts the game on display `:<99+n>` with its own state directory, so lanes never share a display. `LIVE_DISPLAY` sets the display number directly.

## How `smoke` stays exact

The game steps on wall-clock time, so a screenshot at a fixed delay shows a different frame each run. `smoke` records the display at 100 frames per second while the key script runs, then looks for a frame that is identical to the golden image. The golden image is the first frame of level 1. It is the one state the game always shows, because it holds for several ticks. The threshold stays at zero differing pixels. If no frame matches, `smoke` retries the whole sequence up to three times.

To regenerate the golden image after a deliberate change to the first frame of level 1, run `drive.sh golden tools/live/golden/level1-start.png`. Review the image before you commit it.

## Environment

| Variable | Default | Meaning |
| --- | --- | --- |
| `LIVE_LANE` | `0` | Lane number. The display is `:<99+lane>`. |
| `LIVE_DISPLAY` | `99+lane` | Display number. |
| `LIVE_SCREEN` | `640x480x24` | `Xvfb` screen. Keep it at 640x480 or larger. |
| `LIVE_BIN` | `build.sdl/chuckie-egg` | The game binary. |
| `LIVE_STATE` | `/tmp/chuckie-live-<display>` | Pid files, logs, and recordings. |
| `LIVE_OUT_DIR` | `tools/live/out` | Where `smoke` writes `smoke.png`. |
| `LIVE_SMOKE_ATTEMPTS` | `3` | How many times `smoke` retries. |
