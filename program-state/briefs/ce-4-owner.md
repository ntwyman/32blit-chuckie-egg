# CE-4 owner brief

You own one PR, CE-4 (GitHub issue #7): run one game frame every 30 ms and match the original with no input. It is the first gameplay PR and the first with an operator review gate. The root agent coordinates and owns the stack's topology. You build, open, prove, and babysit this PR to merge-ready. You never merge.

## Read first, in full

`<pstack>` is `/home/vscode/.claude/plugins/cache/cursor-plugins/pstack/0.15.32`.

1. `<pstack>/skills/poteto-mode/SKILL.md`, then `<pstack>/docs/harness/claude-code.md`.
2. `/workspaces/32blit-chuckie-egg/AGENTS.md`.
3. The plan: `git show origin/main:docs/plans/port-completion.md`. Read it all. Your section is "Run one game frame every 30 ms and match the original with no input (CE-4)". Also "PR mechanics, for every PR", "Boot recipe, for every live lane", "Hold the review gate", and Appendix D (read `chuckie.c:1109` `run_game` and `chuckie.c:527` `MovePlayer` before editing `game.cpp`).
4. `<pstack>/skills/poteto-mode/playbooks/autopilot-stack.md`, `autopilot-full.md` (you are an owner under its step 2), `opening-a-pr.md`, `babysit.md`, `../references/bugbot-triage.md`, `<pstack>/skills/technical-writing/SKILL.md`.
5. On your base: `tools/parity/README.md` and `tools/live/README.md`. They describe the trace diff and the driver as built.
6. The original: `third_party/pbrook-chuckie-egg/`, especially `chuckie.c`, `sdl.c` (the 30 ms frame at line 145), and `raster_4bit.c`.

## The stack you sit on

CE-1 is merged into `main`. Above it: the sprite fix (#18, `fix/sprite-sheet-bounds`), CE-2 (#16, `ce-2/live-driver`), and CE-3 (#20, `ce-3/trace-diff` at `3841f66ed3ce7feab1d8a56a0541d475b21e6ba1`). All are verified clean. Branch from CE-3.

What CE-3 established, all verified:
- `Game::Step(uint8_t buttons)` runs one frame. `FrameTrace` uses upstream coordinates through `Game::upstreamPosition`, with `y_u = 239 - Y`. An audit rendered both games and confirmed the conversion is exact: every frame-0 trace difference is a real on-screen difference. Do not change the conversion. Fix the game.
- `tools/parity/run.sh` pins each listed script's full divergence report in `<name>-divergences.txt`. A change to any pinned report fails the run. `--record <name>` rewrites one on purpose. `expected-divergent.txt` can only shrink.
- `tools/parity/idle-divergences.txt` holds the idle differences: `henry_x` (port 63, original 60) and `henry_y`, `hen0_y`, `hen1_y` (each 1 off) at frame 0, then the hen schedule (`current_duck` at frame 7, `hen1_mode` at 8, `hen0_x` and `hen0_mode` at 9, `hen1_x` at 49). The plan names two causes, Henry's start x and duck-timer slot 8. The y differences come from the port drawing feet on the floor row where the original leaves a one-row gap. Fix every difference, rerunning `idle` after each fix, until `idle` prints `PASS`.
- `drive.sh` now runs the game line-buffered, so `debugf` lines reach `game.log` while the game runs. The live lanes count `Step` calls from `debugf`, so you must add the step counter the plan describes.
- In live play, Henry dies to a hen within 9 to 15 seconds, and the game ends (lives arrive in CE-6). Lanes that need longer play must plan for that, for example by starting on a level with the start-level option or by steering Henry.

## Operator decisions and root changes that affect you

- **Perf metric.** The plan's perf rule compares the mean microseconds per `Step` over `long-play.inputs` at trunk and head. CE-3's perf lane showed that mean sits near the 41 ns timer resolution, and 88% of `long-play`'s frames come after Henry's first death, when `Step` does almost nothing. Time the whole batch of live frames instead: the wall time to run every frame up to the first death, repeated enough times to resolve 10%, at trunk and head interleaved, with medians. Report the plan's literal number too, as information. Fail if the head batch median is more than 10 percent above trunk's.
- **Merges.** The operator lands with merge commits, so verified heads keep their SHAs.

## Your work

- Branch `ce-4/frame-clock` from `origin/ce-3/trace-diff` at `3841f66ed3ce7feab1d8a56a0541d475b21e6ba1`.
- Do every box in the CE-4 section: Files, Build, You see, Verify unit, Verify perf (with the change above), Review gate. Hold CE-4's file boundary in "Hold the file boundaries".
- `FrameClock` in `frame_clock.hpp`, `clock_test.cpp` in the `parity` target, and `run.sh --clock`. Every new source file carries the SPDX header `tools/check-license.sh` checks.
- When a fix changes a pinned report of another script, rerun it, record it on purpose with `--record`, and explain each change in the PR body. A pinned report may only lose divergences, never gain one, unless you can show the new one is a real difference that an earlier divergence hid.
- Delete the commented-out C block in `game.cpp` your change replaces.
- Build SDL and STM32 with zero new warnings. Never call `docker`.
- Run `/deslop` (`.claude/skills/deslop/SKILL.md`) before each commit and the no-comments skill (`<pstack>/skills/no-comments/SKILL.md`) as a subagent before code-ready.
- Title in Conventional Commits form, for example `feat(game): run one frame every 30 ms and match the original at idle`. The body has `Closes #7`. End commits with a `Co-Authored-By:` trailer naming your model, and the PR body with `🤖 Generated with [Claude Code](https://claude.com/claude-code)`.
- Open the PR ready with `gh pr create --base ce-3/trace-diff`.

## Self-proof and review gate

- Run "You see", both "Verify, unit" boxes, all ten live lanes, and the perf lane yourself. Use only `LIVE_LANE` 500 to 529. Never kill an Xvfb, game, or ffmpeg process you did not start. Save evidence under `/tmp/swarm-ce-4/owner/`.
- Do the review gate's three boxes: the two screenshots in `docs/media/`, and a 30 to 60 second video of level 1 play recorded with `drive.sh record`, saved as `docs/media/ce-4-review.mp4`. Commit them. Steer Henry so the video shows play, not only a game-over screen.
- Do not post in chat yourself. List the media paths in your report. The root posts them to the operator.

## Rules

- Push early and after each unit. Force-push only your own branch, with `--force-with-lease` pinned to your last push. Never rebase onto another branch. Never retarget, merge, or close a PR.
- Keep a decision trail at `/workspaces/32blit-chuckie-egg/.audit/ce-4.tsv` with `<pstack>/skills/show-me-your-work/scripts/log.sh`. Log each unit, fork, and subagent (id, job, stuck-after).
- On a zero-writes order from the root, stop all writes and report.
- Have no background work running when you report.

## Lifecycle and report

1. Build. Push. Open the PR. Comment on #7 with the link.
2. After deslop and no-comments, log `code-ready` with the SHA, and comment on #7.
3. Self-proof and the review-gate media.
4. Babysit CI and review threads until green and triaged. Poll threads at least 10 minutes after green.
5. Report: branch, PR URL, code-ready SHA, final head SHA and parent, every idle fix and its cause, every pinned-report change and why, a receipt for every box and lane, the perf numbers, the media paths, and anything open. Call it merge-ready only when every box has its evidence.
