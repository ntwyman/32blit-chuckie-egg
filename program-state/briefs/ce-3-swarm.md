# CE-3 verification swarm brief

You are one independent verifier for CE-3, PR https://github.com/ntwyman/32blit-chuckie-egg/pull/20. You did not write this code. Do not trust the PR body, the owner's report, or its README. Check everything yourself against the real artifacts.

## Fixed inputs

- Head: `ddd835f20c1ae5511d17938280f99ae391c492f6` (branch `ce-3/trace-diff`).
- Parent (trunk for this PR): `76b68c290ff722de30c504b2735417d724fe59d2` (branch `ce-2/live-driver`, verified clean). Below it are the sprite fix (#18) and CE-1 (#15).
- Plan: `git show ddd835f:docs/plans/port-completion.md`, section "Build a trace diff between the port and the original (CE-3)", plus "Boot recipe, for every live lane" and Appendix A.
- The original: `third_party/pbrook-chuckie-egg/`.
- The driver recipe: `tools/live/README.md` at head. Note: the owner found that the game's `debugf` output only reaches `game.log` when the process exits, because stdout is buffered. If your lane needs live `debugf`, run through `stdbuf -oL` with `LIVE_BIN` pointing at a wrapper script, and report that you did.

## Rules

- Work only in your own worktree at the exact SHA: `git worktree add /tmp/lane-ce-3-<n> <SHA>`. Never edit `/workspaces/32blit-chuckie-egg`. Never push or comment on GitHub.
- Build there. Configure the parity target the way `tools/parity/README.md` and `run.sh` do. Never call `docker`.
- Use only the `LIVE_LANE` values your brief gives you, and only their displays. Never kill an Xvfb, game, or ffmpeg process you did not start.
- Evidence under `/tmp/swarm-ce-3/worker-<n>/`. Write your own scripts. Save each screenshot the lane names.
- Report `PASS`, `ISSUES`, or `BLOCKED` first, with the SHA and exact commands. List every defect you can prove, with its command and output.

## Lanes

Your brief names exactly one lane. Do only that lane.

- **Lane G, gates.** The plan's CE-3 "You see" and both "Verify, unit" boxes, literally. Also: every changed path from `76b68c2` is inside CE-3's file boundary in "Hold the file boundaries", plus `docs/audit/port-completion.tsv`, which Appendix D allows. Every new source file passes `tools/check-license.sh`. SDL and STM32 build with zero new warnings against `76b68c2`. `tools/live/test-drive.sh` passes. CI on `ddd835f` is green, including the parity step. Poll PR #20's reviews, review comments, and issue comments with `gh api`.
- **Lanes 1 to 10.** Run the plan's CE-3 live lane with your number, exactly as worded, and save its screenshot. Lane 1 compares trunk `76b68c2` with head. Lane 6 must show the game running for the full 60 seconds. If Henry dies and the game ends before 60 seconds, say so, and say whether the plan's "no crash" pass condition is still met. Lane 8 edits a scratch copy of `leveldata.c`, never the real one.
- **Lane P, perf.** The plan's "Verify, perf" for CE-3. Report both the plan's literal metric (mean microseconds per `Step` over all 10,000 frames of `long-play.inputs`) and the mean over the frames before Henry's first death, five runs each, with medians. Say how many of the 10,000 frames are live. Build STM32 at parent and head, interleaved, and record the `.blit` sizes. Fail if `Step` costs more than 200 us or the `.blit` grows by more than 512 bytes.
- **Lane A1, audit: is the coordinate conversion exact?** The plan says `FrameTrace` is in upstream coordinates, converted with the exact inverse of `Game::tilePosition`, never tuned to make traces match. The owner chose `y_u = 239 - Y` and rejected `240 - Y`. With that choice, Henry, both hens, the big duck, and lift 0 all differ from upstream by exactly 1 in y at frame 0, and Henry's x differs by 3. Decide which conversion is right, from evidence, not argument:
  - Read `Game::tilePosition`, `Game::upstreamPosition`, and how the port draws a sprite at a position (`game.cpp` render code). Read how upstream turns `player_y` and tile rows into screen rows (`raster_4bit.c`, `sdl.c`, and `chuckie.c`).
  - Render the first level-1 frame in both games. For the port use the SDL build. For upstream, render its frame with its own raster code: build a small host program from `third_party/pbrook-chuckie-egg/` (or reuse `original_driver.c`'s build) that dumps upstream's framebuffer, never editing `third_party/`. Find Henry's and each hen's sprite on screen in both, and compare their screen rows and columns.
  - If both games draw the same sprite on the same screen row, while the trace says their y differs by 1, the conversion is off by one. If the games really draw them one row apart, the divergence is real.
  - Do the same for x: is Henry's 3-pixel difference real on screen? The plan predicts that it is.
  - Report which formula makes positions that agree on screen also agree in the trace, with your measurements.
- **Lane A2, audit: the seam and the comparator.** Read `git diff 76b68c2 ddd835f`. Check that `Game::Step(uint8_t buttons)` runs exactly one frame and reads no globals (grep every global and static it touches). Check that the clock stays in `chuckie_egg.cpp`, and that `update` behaves the same as before for the SDL build. Check that `original_driver.c` only applies patches at build time with `--fuzz=0` and never edits `third_party/`, and that each patch is minimal and justified. Check `run.sh`: the pinned `<name>-divergences.txt` reports, `--record`, `--self-test`, the rule that a listed script that passes fails the run, and that the first divergent frame and field it prints are right. Prove each rule with a scratch edit that should fail it. Check that STM32 and web builds never compile parity code.
- **Lane A3, audit: start level, drivers, and CI.** Check `-DCHUCKIE_START_LEVEL=<n>`, both drivers' `--level <n>`, a script's first-line level, and `drive.sh start --level <n>`, at levels 1, 3, 9, and 40, against upstream's level setup. Each must start the same level with the same bonus and layout as upstream. Check the parity CI step's setup and that it would fail the job on a divergence change. Check the driver changes under `tools/live/` against CE-2's verified behaviour: rerun `test-drive.sh`, and confirm `drive.sh smoke` still passes 5 times on the first attempt at 0 px. Measure the `debugf` buffering the owner found: does `game.log` stay empty while the game runs at head, and was that also true at `76b68c2`? Say what a CE-4 live lane that counts `Step` calls from `debugf` would see.
