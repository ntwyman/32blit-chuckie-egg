# CE-2 verification swarm brief, second full swarm

You are one independent verifier for CE-2, PR https://github.com/ntwyman/32blit-chuckie-egg/pull/16. You did not write this code. Do not trust the PR body or the owner's claims. Check everything yourself against the real artifacts.

## Fixed inputs

- Head SHA: `05102f5b6cae7df720de1a3a096e6fbd1997af7d` (branch `ce-2/live-driver`).
- Parent: `60f8f6e6588d36471c5e9ba211502e5501a3ea32` (branch `fix/sprite-sheet-bounds`, PR #18), which sits on CE-1 at `1ff20c3`. The parent fixes the TIME sprite reading past the sheet (issue #17), so the first level-1 frame is now identical across processes.
- Plan: `git show 05102f5:docs/plans/port-completion.md`, section "Add a scripted driver for the SDL build (CE-2)", plus "Boot recipe, for every live lane". Operator decision: CE-2 keeps live lanes 1, 2, and 6.
- The first swarm at `eb4ed88` found defects, listed in `/workspaces/32blit-chuckie-egg/.audit/briefs/ce-2-fix-1.md`. Fix round 2 is in `ce-2-fix-2.md`. Read both. Your lane checks that its share of those findings is closed, as well as its plan box.

## Rules

- Work only in your own worktree at the exact SHA: `git worktree add /tmp/lane2-ce-2-<n> <SHA>`. Never edit `/workspaces/32blit-chuckie-egg`. Never push or comment on GitHub.
- Build with `cmake -B build.sdl && cmake --build build.sdl -j`, and STM32 with `-DCMAKE_TOOLCHAIN_FILE=/opt/32blit-sdk/32blit.toolchain` when needed. Never call `docker`.
- Drive the game only through `tools/live/drive.sh`. Use only the `LIVE_LANE` values your brief gives you. Never kill an Xvfb, game, or ffmpeg process you did not start.
- Evidence under `/tmp/swarm2-ce-2/worker-<n>/`. Write your own scripts.
- Report `PASS`, `ISSUES`, or `BLOCKED` first, with the SHA and exact commands. List every defect you can prove, with its command and output.

## Lanes

- **Lane G, gates (LIVE_LANE 60 to 61).** The plan's CE-2 "You see" and "Verify, unit" boxes, literally: `drive.sh smoke` prints `smoke: ok` and `smoke.png` matches `tools/live/golden/level1-start.png` with `compare -metric AE` 0. Look at the golden: level 1, TIME 900, full-width TIME label, nothing under it, Henry at his start. Run `tools/live/test-drive.sh` and `tools/live/test-smoke.sh` and report the results. Every changed path from `60f8f6e` is inside CE-2's file boundary or `tools/live/`. SDL and STM32 build with zero new warnings against `60f8f6e`. `tools/check-license.sh` passes. CI on `05102f5` is green, including Live smoke and driver tests. Poll PR #16's reviews, review comments, and issue comments with `gh api`.
- **Lane 1 (LIVE_LANE 62).** Plan lane 1. Trunk has no driver; record that. `drive.sh smoke` from a clean worktree. Save `smoke.png`. Level 1 with Henry at his start tile.
- **Lane 2 (LIVE_LANE 63).** Plan lane 2. One player, then `keys walk-right.keys`. Save before and `walked.png`. Measure Henry's x. At least 40 px right.
- **Lane 6 (LIVE_LANE 64).** Plan lane 6, plus the parser findings from round 1. An unknown key exits non-zero and names the line. Malformed lines (no hold, negative, non-numeric, extra field, CRLF) are rejected. `* 100` is not glob-expanded, wherever you run it from. An empty script exits 0 and sends nothing. `left++up 100` and `+z 100` are rejected with file:line. The README key table matches what the parser accepts.
- **Lane P, perf (LIVE_LANE 65).** Plan "Verify, perf": five sequential `time drive.sh smoke` runs, report each and the median, fail above 20 s, and report retries. Four clean STM32 builds, parent, head, parent, head, and fail if the `.blit` size changes at all.
- **Lane A1, audit: the smoke gate (LIVE_LANE 66 to 68).** Decide with proof whether the gate is now honest. Run smoke 30 times at head and report how many pass on the first attempt and any retry reason. Show each of these fails at once, with no retry: a golden from "How many players"; a golden from "Ready player"; a golden from a later level-1 frame; a mutant build whose start timer is 901; a key script that never presses `z` (this should fail with a clear message within a bounded time). Check that the selected frame is chosen deterministically (its index relative to the ready screen across your runs). Check that a `start-one-player.keys` in the current directory does not change what smoke sends. Check that the `compare` is no longer run on a frame chosen by matching. Read the retry code and say exactly which conditions retry.
- **Lane A2, audit: driver robustness (LIVE_LANE 70 to 79).** Recheck each driver finding from round 1 (items 5 to 10 in `ce-2-fix-1.md`) and the round 2 Xvfb wait. A live unrelated pid in a pid file is neither reported as the game nor killed. Killing smoke with TERM and with KILL leaves no recorder running, and `stop` cleans up after either. Two lanes in one worktree write separate output folders. Recordings are removed after a clean run, and logs are kept after a failure. Smoke rejects a screen other than 640x480. `start` fails when no window appears. `stop` confirms the kill. The X lock file is only removed when no process holds the display. A bad `LIVE_LANE` gives a clear error. A failed smoke leaves a frame and `game.log` where CI uploads them. Run two lanes in parallel 10 times pinned to one CPU with `taskset -c 0` and report any "run failed". Read the CI workflow's Live smoke job and driver-test step.
