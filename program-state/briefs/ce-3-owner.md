# CE-3 owner brief

You own one PR, CE-3 (GitHub issue #6): build a trace diff between the port and the original. Every later gameplay PR, CE-4 to CE-9, proves itself with the tool you build, so this is the program's most important seam. The root agent coordinates and owns the stack's topology. You build, open, prove, and babysit this PR to STACK-READY. You never merge.

## Read first, in full

`<pstack>` is `/home/vscode/.claude/plugins/cache/cursor-plugins/pstack/0.15.32`.

1. `<pstack>/skills/poteto-mode/SKILL.md`, then `<pstack>/docs/harness/claude-code.md`.
2. `/workspaces/32blit-chuckie-egg/AGENTS.md`, `GLOSSARY.md`, and `docs/adr/` if present.
3. The plan: `git show origin/main:docs/plans/port-completion.md`. Read it all. Your section is "Build a trace diff between the port and the original (CE-3)". Also "PR mechanics, for every PR", "Boot recipe, for every live lane", Appendix A (the open question whether `Game` builds for the host without the 32Blit engine), and Appendix D.
4. `<pstack>/skills/poteto-mode/playbooks/autopilot-stack.md`, `autopilot-full.md` (you are an owner under its step 2), `opening-a-pr.md`, `babysit.md`, `../references/bugbot-triage.md`, `<pstack>/skills/technical-writing/SKILL.md`.
5. `<pstack>/skills/how/SKILL.md`. Run it on the `Game::Tickle` loop, the `Step` and `FrameTrace` split, and how upstream `chuckie.c` runs one frame, before you write the seam. The plan requires it.
6. `<pstack>/skills/interrogate/SKILL.md`. Run it on your design and code before you report code-ready. The plan requires it, because every later PR depends on this seam. Use the override sheet's panel: `interrogate reviewers: opus, fable, sonnet, haiku`.
7. `tools/live/README.md` on your base. It is the control recipe for the SDL build.
8. The original: `third_party/pbrook-chuckie-egg/`, especially `chuckie.c` (`run_game` near line 1109, `MovePlayer` near 527, `MoveDucks` near 828), `leveldata.c`, and `sdl.c`.

## The stack you sit on

CE-1 (#15, `ce-1/gpl-relicense`), then the sprite-sheet fix (#18, `fix/sprite-sheet-bounds`, issue #17, not in the plan), then CE-2 (#16, `ce-2/live-driver` at `76b68c290ff722de30c504b2735417d724fe59d2`). All three are verified clean. Branch from CE-2.

The sprite fix means the first level-1 frame is now identical across processes. CE-2's driver has a deterministic smoke gate. Issue #19 (timer digits 2 px left of upstream) is open and not yours.

## Your work

- Branch `ce-3/trace-diff` from `origin/ce-2/live-driver` at `76b68c290ff722de30c504b2735417d724fe59d2`.
- Do every box in the CE-3 section: Files, Build, You see, Verify unit, Verify perf. The plan is the source of truth. Pay attention to:
  - `Game::Step(uint8_t buttons)` runs exactly one original frame and reads no globals. The clock stays in `chuckie_egg.cpp`.
  - The start-level option, `cmake -DCHUCKIE_START_LEVEL=<n>`, both drivers' `--level <n>`, and `drive.sh start --level <n>`.
  - `FrameTrace` in upstream coordinates, converted with the exact inverse of `Game::tilePosition`. Never tune the conversion to make a trace match.
  - `idle.inputs`: do not predict its divergences. Run it and record what `run.sh` reports in `tools/parity/idle-divergences.txt`.
  - `expected-divergent.txt` can only shrink. A listed script that passes fails the run.
  - `original_driver.c` applies upstream changes as patches at build time and never edits `third_party/`.
  - The `parity` target sits behind `option(CHUCKIE_PARITY)` and is host-only. STM32 and web builds never link it.
- Settle Appendix A's open question first, with a build, not by reading: can `Game` build for the host without the 32Blit engine? If not, the port driver links the SDK's SDL engine library and never opens a window. Record what you found and why in the PR body.
- File boundary: the plan's CE-3 list (`tools/parity/**`, `tools/live/**`, `CMakeLists.txt`, `.github/workflows/build.yml`, and the `Tickle` and snapshot code in `game.hpp`, `game.cpp`, `chuckie_egg.cpp`). Appendix D also says to commit the program's decision trail with CE-3. Copy `/workspaces/32blit-chuckie-egg/.audit/port-completion.tsv` to `docs/audit/port-completion.tsv` in your last commit before code-ready, and nothing else under `docs/`.
- Every new `.cpp`, `.hpp`, `.c`, or `.h` file you add outside `third_party/` carries the SPDX header that `tools/check-license.sh` checks.
- Delete the commented-out C block in `game.cpp` that your `Tickle` and `Step` change replaces, per "PR mechanics".
- Build SDL and STM32 in the container before the PR-facing push, with zero new warnings. Never call `docker`.
- Run `/deslop` (`.claude/skills/deslop/SKILL.md`) before each commit, and the no-comments skill (`<pstack>/skills/no-comments/SKILL.md`) as a subagent before code-ready.
- Title in Conventional Commits form, for example `feat(parity): diff the port's frames against the original's`. The body has `Closes #6`. End commits with a `Co-Authored-By:` trailer naming your model, and the PR body with `🤖 Generated with [Claude Code](https://claude.com/claude-code)`.
- Open the PR ready with `gh pr create --base ce-2/live-driver`.

## Self-proof

Run the CE-3 "You see", "Verify, unit", and "Verify, perf" boxes, and all ten live lanes yourself, per the boot recipe and `tools/live/README.md`. Save evidence under `/tmp/swarm-ce-3/owner/`. Use only `LIVE_LANE` 200 to 219 and Xvfb displays those lanes map to. Never kill an Xvfb, game, or ffmpeg process you did not start. Run each box literally as the plan words it; if you substitute a check, say so and why.

## Rules

- Push early and after each unit. Force-push only your own branch, with `--force-with-lease` pinned to your last push. Never rebase onto another branch. Never retarget, merge, or close a PR.
- Keep a decision trail at `/workspaces/32blit-chuckie-egg/.audit/ce-3.tsv` with `<pstack>/skills/show-me-your-work/scripts/log.sh`. Log each unit, each fork, each subagent (id, job, stuck-after time), and the how and interrogate outcomes.
- On a zero-writes order from the root, stop all writes and report.
- Have no background work running when you report.

## Lifecycle and report

1. Run `how`, settle Appendix A, then build. Push. Open the PR. Comment on #6 with the link.
2. Run `interrogate`, fix what it finds, then deslop and no-comments. Log a `code-ready` row with the SHA, and comment on #6.
3. Self-proof as above.
4. Babysit CI and review threads per `babysit.md` until green and triaged. Poll threads at least 10 minutes after green.
5. Report: branch, PR URL, code-ready SHA, final head SHA and parent, the Appendix A answer, the how and interrogate findings and what you did with each, a receipt for every box and lane, the perf numbers, the idle divergences you recorded, and anything open. Call it STACK-READY only when every box has its evidence.
