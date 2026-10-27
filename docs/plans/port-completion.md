# Chuckie Egg port completion plan

This plan finishes the 32Blit port of Paul Brook's GPLv3 Chuckie Egg so that a player can play from the first level through game over, on device and in the browser.
It fixes the license first, because `levels.cpp` copies `leveldata.c` byte for byte and `game.cpp` is a translation of `chuckie.c`, yet `LICENSE` is MIT.
The rule the program enforces is that the port behaves like the original, frame for frame, and every gameplay PR proves that with a trace diff against the original C code.
The PRs land in this order. CE-1, CE-2, CE-3, CE-4, CE-5, CE-6, CE-7, CE-8, then CE-9 if the operator keeps it. GitHub issue #3 tracks the program, and its sub-issues #4 to #12 track CE-1 to CE-9.

## How to read this

One box is one unit of work. Every box names the evidence that checks it. A nested box is a sub-step of the box above it. Check a box only when its evidence exists, a file, a log line, a screenshot, a test run, or a SHA. The body is a how-to. The appendices explain and record.

The program runs `<pstack>/skills/poteto-mode/playbooks/autopilot-stack.md`, where `<pstack>` is the installed pstack plugin folder that `ls -d ~/.claude/plugins/cache/cursor-plugins/pstack/*` prints. The repo's `.claude/settings.json` enables pstack, so Claude Code in the dev container offers to install it on first start. Every PR is a link in one linear stack, because CE-4 through CE-9 all edit `game.cpp`. The operator lands the stack bottom-up. CE-4 through CE-9 change an interaction and stop at merge-ready for the operator's review.

Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

Level numbers in this plan are the numbers the HUD shows, which are `current_level + 1` in both `chuckie.c` and `game.cpp`. Level 1 is `current_level` 0.

In every **Verify** block, trunk means the PR's base, which is its parent branch at the exact SHA the PR was built on. CE-1's base is `main`. A regression or perf lane runs its trunk side at that SHA, so the tools that earlier links add exist on both sides.

## Program checklist

### Arm the program

- [ ] State the protocol and this plan to the operator, then stop. Start execution only on the operator's explicit go.
- [ ] Run inside the dev container. Check that `/opt/32blit-sdk` exists and that `claude plugin list` shows `pstack@cursor-plugins` enabled.
- [ ] Once CE-1 lands, read the original's source in `third_party/pbrook-chuckie-egg/`. Before then, the CE-1 owner reads its import clone in `/tmp/upstream-import`. Every later reference to upstream source means that folder. Never edit it outside a PR that changes the pinned commit.
- [ ] Read these from trunk at program start. Re-read them at every tick.
  - [ ] `git show origin/main:docs/plans/port-completion.md`
  - [ ] `<pstack>/skills/poteto-mode/playbooks/autopilot-stack.md` and `<pstack>/skills/poteto-mode/playbooks/autopilot-full.md`
  - [ ] `<pstack>/skills/swarm/SKILL.md`
  - [ ] `git show origin/main:tools/live/README.md` once CE-2 lands. It is the control recipe for the SDL build, because no control skill covers 32Blit.
  - [ ] `<pstack>/skills/poteto-mode/playbooks/opening-a-pr.md`
  - [ ] `<pstack>/skills/technical-writing/SKILL.md` for CE-1 and `<pstack>/skills/how/SKILL.md` for CE-3.
- [ ] On the operator's go, arm the audit tick as `/loop 1h` with the tick prompt below. Never leave the cadence to memory.
- [ ] Use this tick prompt, verbatim. "Re-read the execution playbook from trunk. Audit the operation against it and fix drift in this tick. Probe every active lane and judge progress by side effects only. Stand down a stuck lane and dispatch its replacement now. Then post a short status message to the operator in chat only when the audit found a tracked change that no earlier status message reported, such as a PR opened, a code-ready head, a round launched or closed, a verdict, a merge, a stuck agent and the action taken, a blocker added or cleared, or a decision only the operator can make. Name every such change and nothing else. Do not repeat a table, the merged list, or an unchanged blocker. If the audit found none, end the turn with no reply text. Either way, log this tick's row in your decision trail. The row names the items reported, or none."
- [ ] On the operator's hold or stand-down, send every owner a zero-writes order at once.

### Spawn owners

- [ ] Spawn one owner per PR with the full lifecycle the execution playbook names.
- [ ] Follow this dependency graph. Each owner branches from its parent's branch, because the playbook stacks.
  - [ ] CE-1 (#4) is first and branches from `main`.
  - [ ] CE-2 (#5) after CE-1.
  - [ ] CE-3 (#6) after CE-2.
  - [ ] CE-4 (#7) after CE-3.
  - [ ] CE-5 (#8) after CE-4.
  - [ ] CE-6 (#9) after CE-5.
  - [ ] CE-7 (#10) after CE-6.
  - [ ] CE-8 (#11) after CE-7.
  - [ ] CE-9 (#12) after CE-8, and only if the operator keeps it.
- [ ] Hold the file boundaries.
  - [ ] CE-1 touches only `third_party/pbrook-chuckie-egg/**`, `LICENSE`, `README.md`, `metadata.yml`, `CMakeLists.txt`, `tools/check-license.sh`, `.github/workflows/build.yml`, and the header comment of each `*.cpp` and `*.hpp` file.
  - [ ] CE-2 touches only `tools/live/**`, `.devcontainer/Dockerfile`, `.devcontainer/devcontainer.json`, and `.github/workflows/build.yml`.
  - [ ] CE-3 touches only `tools/parity/**`, `tools/live/**`, `CMakeLists.txt`, `.github/workflows/build.yml`, and the `Tickle` and snapshot code in `game.hpp`, `game.cpp`, and `chuckie_egg.cpp`.
  - [ ] CE-4 through CE-9 touch `game.hpp`, `game.cpp`, `chuckie_egg.cpp`, `frame_clock.hpp`, `tools/parity/**`, `tools/live/**`, and `docs/media/**`. CE-4 and CE-6 also touch `CMakeLists.txt`. CE-9 also touches `assets/**`, `assets.yml`, and `metadata.yml`.
- [ ] Hold the review gate. CE-4, CE-5, CE-6, CE-7, CE-8, and CE-9 change an interaction. They wait for the operator's review in chat with screenshots and a video before merge.

### PR mechanics, for every PR

- [ ] Resolve the forge once. Default to `gh`; if `command -v origin` succeeds and Origin can resolve the repository, use `origin pr` for every PR operation. Record any fallback to `gh`. Never require `gt`.
- [ ] Write `Closes #<issue>` in the PR body, with the issue number from the dependency graph. Comment on that issue with the PR link at code-ready, at merge-ready, and at each verdict. Record decisions the operator makes on the issue too, not only in chat.
- [ ] Open the PR ready, never draft, per **Opening a PR**. Use the run's built-in PR tool when it has one, else `origin pr create --status open --base <base-branch>` or `gh pr create --base <base-branch>` according to the resolved forge. A stack child targets its parent branch.
- [ ] Build the SDL and STM32 targets in the dev container once before the PR-facing push. The repo has no lint or typecheck beyond `-Wall -Wextra`, so a build with zero new warnings is the check. Push with hooks on.
- [ ] Run `/deslop` before each commit and `/no-comments` before review. `/deslop` is the project skill in `.claude/skills/deslop/`, and `/no-comments` comes from pstack. Each gameplay PR deletes the commented-out C block it replaces in `game.cpp`.
- [ ] Triage every Bugbot and security-reviewer comment per `<pstack>/skills/poteto-mode/references/bugbot-triage.md`.
- [ ] Leave rebasing to the root. Owners never rebase onto another branch, per `autopilot-stack.md` step 1.

### Verdict and merge, for every PR

- [ ] A full swarm runs once, at the code-ready head. Another full swarm runs only for new behavior, a redesign, or a large new diff. A rebase, a merge-conflict resolution, or a minor fix gets a single verifier at the new head. Run each full swarm per `<pstack>/skills/swarm/SKILL.md`. One gates lane. The ten live lanes from the PR's **Verify, live** block. The perf lane from its **Verify, perf** block. Two or more audit lanes, each with its own focus, that read the diff and the receipts and distrust the PR body. The root audits the receipts in the merge-ready report before the verdict.
- [ ] Clean only when every lane is `PASS`. Findings go back to the owner, including a defect that a lane filed as a note. A new head gets a fresh verdict, except for results that stay valid under the patch-id rule in `playbooks/shipping.md`.
- [ ] Append each clean PR to the stack with its base set to its parent's branch. A link whose patch-id is unchanged after a root rebase keeps its verdict, per `playbooks/shipping.md`. The operator lands the stack bottom-up.

### Boot recipe, for every live lane

Each live lane runs in its own git worktree at the PR head, inside the dev container. There is no `control-ui` or `control-cli` for a 32Blit SDL window, so lanes drive the game through `tools/live/drive.sh`, which CE-2 adds.

- [ ] `git fetch origin <head-branch>`.
- [ ] Create the lane's worktree with `git worktree add /tmp/lane-<pr-id>-<n> <head SHA>` and work in it. The dev container has the SDK, so build there with `cmake -B build.sdl && cmake --build build.sdl -j4`. Wait for `build.sdl/chuckie-egg` to exist. The container cannot run Docker, so never call `docker`.
- [ ] Start the game with `tools/live/drive.sh start`, which runs it under `Xvfb` at 320x240 on display `:<99+n>` for lane `n`, so parallel lanes never share a display. Deliver input only through `tools/live/drive.sh keys <script>`, which sends `xdotool` key events. The read-only diagnostics are the game's `debugf` output on stdout and `tools/parity/run.sh --script <name>` traces.
- [ ] Save every screenshot to `/tmp/swarm-<pr-id>/worker-<n>/<slug>.png` with `tools/live/drive.sh shot <path>` and return the paths with the report.

## Add the original source, relicense under GPLv3, and credit the original (CE-1)

**Depends on.** None.

**Files.**

- [ ] Create `third_party/pbrook-chuckie-egg/` with every file upstream tracks except `models/blender/`.
- [ ] Create `third_party/pbrook-chuckie-egg/README.md`.
- [ ] Edit `LICENSE`. Replace the MIT text with a copy of `third_party/pbrook-chuckie-egg/COPYING`.
- [ ] Edit `README.md`. Add a credits section, delete the boilerplate usage section, and point the build badge at this repository.
- [ ] Edit `metadata.yml`.
- [ ] Edit `CMakeLists.txt`.
- [ ] Edit `chuckie_egg.cpp`, `game.cpp`, `game.hpp`, `levels.cpp`, `levels.hpp`, `sprites.cpp`, and `sprites.hpp`.

**Build.**

- [ ] Copy upstream in with `git clone https://github.com/pbrook/Chuckie-Egg /tmp/upstream-import && git -C /tmp/upstream-import archive e18004643193a8ff9434cf77b15a13219f6d745e | tar -x -C third_party/pbrook-chuckie-egg --exclude 'models/blender'`. The 2 MB of Blender files in `models/blender/` feed only upstream's 3D renderer.
- [ ] Write `third_party/pbrook-chuckie-egg/README.md`. It names the upstream URL, the commit `e18004643193a8ff9434cf77b15a13219f6d745e`, the GPLv3 license, and the excluded `models/blender/` folder. It says that the folder is a read-only reference copy.
- [ ] Give every source file the header `SPDX-License-Identifier: GPL-3.0-only`, then "Copyright (C) 2009-2011 Paul Brook" and "32Blit port Copyright (C) 2020-2026 ntwyman". `levels.cpp` and `sprites.cpp` also say that the data comes from `leveldata.c` and `spritedata.c`.
- [ ] Write the `README.md` credits. The game is based on the original by A & F Software. The C source is Paul Brook's [Chuckie Egg](https://github.com/pbrook/Chuckie-Egg), released under the GNU GPL v3. This port is GPLv3 and states what it changed.
- [ ] Set `metadata.yml` `description` to "A 32blit port of Paul Brook's GPLv3 Chuckie Egg, based on the original by A & F Software".

**You see.**

- [ ] `rg -l "MIT License" LICENSE README.md` prints nothing, and `rg --files-without-match "GPL-3.0-only" -g '*.{cpp,hpp}'` prints nothing.
- [ ] `git -C /tmp/upstream-import ls-files | grep -v '^models/blender/'` lists exactly the files in `third_party/pbrook-chuckie-egg/` other than its `README.md`, and `diff -r` against the clone shows no content changes.
- [ ] The release archive from `cpack` holds `LICENSE` with the GPLv3 text and a `README.md` that names Paul Brook and A & F Software.

**Verify, unit.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] The repo has no test target yet. Add `tools/check-license.sh`, which fails when any `*.cpp` or `*.hpp` file lacks the SPDX line or when `cmp LICENSE third_party/pbrook-chuckie-egg/COPYING` fails. Run `tools/check-license.sh` and add it as a CI step.

**Verify, live.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked. Ten lanes on `inherit-parent` at the PR head, per the boot recipe. CE-2 has not landed at this point, so each lane starts the game by hand under `Xvfb` and takes screenshots with `import -window root`.

- [ ] Lane 1. Regression lane against trunk. Start the SDL build at trunk and at head, and press A once on the player-count screen. Save `ready-trunk.png` and `ready-head.png`. Pass when the two images match pixel for pixel.
- [ ] Lane 2. Run `cpack` in `build.sdl`. Save `cpack-listing.png` of `tar tzf` output. Pass when the archive lists `LICENSE` and `README.md`, and `LICENSE` contains "GNU GENERAL PUBLIC LICENSE Version 3".
- [ ] Lane 3. Build the STM32 target. Save `stm32-build.png` of the build tail. Pass when `build.stm32/chuckie-egg.blit` exists and the build prints no new warnings.
- [ ] Lane 4. Run `32blit metadata` on the `.blit` file, or its equivalent in the installed tools. Save `blit-metadata.png`. Pass when the description names Paul Brook.
- [ ] Lane 5. Build the web target and serve it with `python3 -m http.server 8000`. Save `web-load.png` from headless Chromium, driven by Playwright from `/opt/venv`. Pass when the player-count screen renders.
- [ ] Lane 6. Render `README.md` with GitHub's own renderer, `gh api markdown -f mode=gfm -f text="$(cat README.md)"`, and open the HTML in Playwright's Chromium. Save `readme.png`. Pass when the credits section shows both links and no boilerplate "Use this template" text remains.
- [ ] Lane 7. Run `tools/check-license.sh` after deleting the SPDX line from `game.cpp` in a scratch copy. Save `license-check-red.png`. Pass when the script exits non-zero and names `game.cpp`.
- [ ] Lane 8. Run `tools/check-license.sh` on the clean head. Save `license-check-green.png`. Pass when it exits zero.
- [ ] Lane 9. Start the SDL build, choose one player, and walk Henry right for five seconds. Save `walk.png`. Pass when the game still runs and Henry has moved.
- [ ] Lane 10. Push the head branch and watch the CI run. Save `ci.png` of `gh run view`. Pass when every matrix job is green.

**Verify, perf.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] Metric. Size in bytes of `build.stm32/chuckie-egg.blit` at trunk and at head.
- [ ] Probe. Build the STM32 target at trunk, then head, then trunk, then head, and record `stat -c %s` each time.
- [ ] Baseline. Record the trunk size first.
- [ ] Rule. Fail if the head size differs from trunk by more than 64 bytes, because comments must not change the binary.

**Review gate.** None. CE-1 is not review-gated.

**Merge.**

- [ ] Root's clean verdict at the exact head SHA.
- [ ] Bugbot triage done.
- [ ] Rebased onto current trunk after the verdict, patch-id unchanged.
- [ ] The root appends CE-1 to the base-branch stack and the operator lands it bottom-up.

## Add a scripted driver for the SDL build (CE-2)

**Depends on.** CE-1.

**Files.**

- [ ] Create `tools/live/drive.sh`.
- [ ] Create `tools/live/README.md`.
- [ ] Create `tools/live/scripts/start-one-player.keys` and `tools/live/scripts/walk-right.keys`.
- [ ] Edit `.devcontainer/Dockerfile` and `.devcontainer/devcontainer.json`.
- [ ] Edit `.github/workflows/build.yml` to add a Linux job that runs `tools/live/drive.sh smoke`.

**Build.**

- [ ] Pin `SDK_REF` to one 32blit-sdk commit SHA in the Dockerfile default, in the `SDK_REF` build argument in `devcontainer.json`, and in the CI checkout. `devcontainer.json` passes `SDK_REF` explicitly, so the Dockerfile default alone pins nothing.
- [ ] `drive.sh` has the subcommands `start`, `keys <script>`, `shot <path>`, `record <seconds> <path>`, `stop`, and `smoke`. A key script holds one line per step, `<key> <hold-ms>` or `wait <ms>`.

**You see.**

- [ ] `tools/live/drive.sh smoke` prints `smoke: ok` and writes `smoke.png` that shows the first level after one player starts.

**Verify, unit.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] `tools/live/drive.sh smoke` compares `smoke.png` against `tools/live/golden/level1-start.png` with `compare -metric AE` and fails above zero differing pixels. Run `tools/live/drive.sh smoke` in the container and in CI.

**Verify, live.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked. Ten lanes on `inherit-parent` at the PR head, per the boot recipe.

- [ ] Lane 1. Regression lane against trunk. Trunk has no driver, so record that fact. Gate that head's `drive.sh smoke` reaches level 1 in a fresh container. Save `smoke.png`. Pass when the image shows level 1 with Henry at his start tile.
- [ ] Lane 2. Run `keys walk-right.keys`. Save `walked.png`. Pass when Henry's x position in the image is at least 40 pixels right of the start.
- [ ] Lane 3. Run `start` twice in a row. Save `double-start.png`. Pass when the second call reports that the game is already running and one game process exists.
- [ ] Lane 4. Run `stop` with no game running. Save `stop-idle.png`. Pass when it exits zero and prints nothing alarming.
- [ ] Lane 5. Run `record 10 walk.mp4` during `walk-right.keys`. Save `record-frame.png` from frame 150 of the video. Pass when the video is 10 seconds long and the frame shows the game.
- [ ] Lane 6. Feed a key script with an unknown key name. Save `bad-key.png`. Pass when `drive.sh` exits non-zero and names the bad line.
- [ ] Lane 7. Run `xdotool --version`, `Xvfb -help`, `import -version`, and `ffmpeg -version` in the running container. Save `tools.png`. Pass when all four run. The container cannot rebuild its own image, so the operator rebuilds it on the host after the pin changes.
- [ ] Lane 8. Hold the jump key for 500 ms on level 1. Save `jump.png` at the top of the arc. Pass when Henry is off the floor.
- [ ] Lane 9. Climb the first ladder with `up` held. Save `climb.png`. Pass when Henry is on the ladder above the floor.
- [ ] Lane 10. Push and watch the new CI job. Save `ci-smoke.png`. Pass when the smoke job is green.

**Verify, perf.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] Metric. Wall time of `drive.sh smoke` from `start` to `smoke: ok`. Trunk lacks the driver, so this is an absolute budget for the work the diff adds.
- [ ] Probe. Run `time tools/live/drive.sh smoke` five times in one container.
- [ ] Baseline. Trunk has no driver. Record that, and record the `.blit` size at trunk and head, which must not change.
- [ ] Rule. Fail if the median smoke time exceeds 20 seconds or the `.blit` size changes at all.

**Review gate.** None. CE-2 is not review-gated.

**Merge.**

- [ ] Root's clean verdict at the exact head SHA.
- [ ] Bugbot triage done.
- [ ] Rebased onto current trunk after the verdict, patch-id unchanged.
- [ ] The root appends CE-2 to the base-branch stack and the operator lands it bottom-up.

## Build a trace diff between the port and the original (CE-3)

**Depends on.** CE-2.

**Files.**

- [ ] Create `tools/parity/trace.h`, the frame record that both drivers write.
- [ ] Create `tools/parity/original_driver.c`, which builds `third_party/pbrook-chuckie-egg/chuckie.c` and `leveldata.c` with a no-op `raster` and scripted input. It applies upstream changes, such as the CE-6 `abort()` fix, as patches at build time and never edits `third_party/`.
- [ ] Create `tools/parity/port_driver.cpp`, which runs `Game` with scripted input and no rendering.
- [ ] Create `tools/parity/run.sh`, `tools/parity/scripts/*.inputs`, `tools/parity/expected-divergent.txt`, and `tools/parity/idle-divergences.txt`.
- [ ] Edit `game.hpp`, `game.cpp`, and `chuckie_egg.cpp`.
- [ ] Edit `CMakeLists.txt` to add a host-only `parity` target behind `option(CHUCKIE_PARITY)`.
- [ ] Edit `.github/workflows/build.yml` to run `tools/parity/run.sh --all`.

**Build.**

- [ ] Split `Game::Tickle` into a clock part, which stays in `chuckie_egg.cpp`, and `Game::Step(uint8_t buttons)`, which runs exactly one original frame. `pollKeys` moves to the caller, so `Step` reads no globals.
- [ ] Add a start-level option. `cmake -DCHUCKIE_START_LEVEL=<n>` sets the level a new game starts on, as a displayed level number. Both drivers take `--level <n>`, and a script's first line can name its level. `drive.sh start --level <n>` builds with that option. It lands here, so every later PR's parent already has it.
- [ ] Write `FrameTrace` in upstream coordinates. `port_driver.cpp` converts the port's screen positions with the exact inverse of `Game::tilePosition` in `game.cpp`, so it removes `X_OFFSET` and flips y. Never tune the conversion to make a trace match. A position that still differs after the conversion is a real difference to fix. The trace also records Henry's tile and partial position, which both games keep with the same meaning.
- [ ] Add `Game::Snapshot()`, which returns a `FrameTrace` with Henry's x, y, tile, partial position, and mode, the score, lives, bonus, timer, the lift positions, the duck timer, the index of the hen due to move next, and every hen's position and mode.
- [ ] `run.sh` runs both drivers on each script, diffs the traces, and prints the first frame and field that differ.
- [ ] `expected-divergent.txt` lists the scripts that diverge today. A script that passes but is still listed fails the run, so the list can only shrink.

**You see.**

- [ ] `tools/parity/run.sh --all` prints one line per script, `PASS` or `DIVERGES at frame <n> field <name>`, and exits zero when the results match `expected-divergent.txt`.

**Verify, unit.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] `tools/parity/scripts/idle.inputs` holds no input for 300 frames. Do not predict its divergences. Run it, and record each frame and field that `run.sh` reports in `tools/parity/idle-divergences.txt`, then list `idle` in `expected-divergent.txt`. Reading the code finds at least two differences, so expect `idle` to diverge. Henry starts 3 pixels right of upstream, because `Game::loadLevel` sets `pos.x` to `tilex*8 + partial_x` (`game.cpp:148-151`) and upstream sets `player_x` to `0x3c`, which is `tilex*8 + partial_x - 3` (`chuckie.c:208`). `Game::moveDucks` also advances the hen schedule in duck-timer slot 8, where upstream `MoveDucks` returns (`chuckie.c:828-861`). Run `tools/parity/run.sh --script idle`.
- [ ] Remove a script from `expected-divergent.txt` that still diverges, and check that `run.sh --all` fails. Run `tools/parity/run.sh --all`.

**Verify, live.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked. Ten lanes on `inherit-parent` at the PR head, per the boot recipe.

- [ ] Lane 1. Regression lane against trunk. Run `walk-right.keys` with `drive.sh` at trunk and at head. Save `walk-trunk.png` and `walk-head.png`. Pass when the two images match, because the `Step` split must not change behavior.
- [ ] Lane 2. Run `run.sh --all`. Save `parity-all.png`. Pass when the exit code is zero and every listed divergence names a frame and field.
- [ ] Lane 3. Run `run.sh --script walk-right`. Save `parity-walk.png`. Pass when the output names the first divergent frame or `PASS`.
- [ ] Lane 4. Run the original driver alone on `jump-left.inputs`. Save `orig-jump.png` of the trace. Pass when Henry's y rises then falls back to the floor value.
- [ ] Lane 5. Run the port driver alone on `jump-left.inputs`. Save `port-jump.png` of the trace. Pass when the trace has one row per input frame.
- [ ] Lane 6. Play level 1 for 60 seconds with `drive.sh`. Save `play-60s.png`. Pass when the game shows no crash and `debugf` shows no `abort`.
- [ ] Lane 7. Build STM32 and web with `CHUCKIE_PARITY` off. Save `targets.png`. Pass when both build and neither links the `parity` target.
- [ ] Lane 8. In a scratch copy, change the first hen's start x in `level1` of `third_party/pbrook-chuckie-egg/leveldata.c`. Save `parity-red.png`. Pass when `run.sh --script idle` reports a hen position divergence on frame 0.
- [ ] Lane 9. Run `run.sh --all` twice. Save `parity-repeat.png`. Pass when both runs print the same lines.
- [ ] Lane 10. Push and watch CI. Save `ci-parity.png`. Pass when the parity step runs and is green.

**Verify, perf.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] Metric. Mean microseconds per `Game::Step` call in the port driver over `long-play.inputs`, which is 10,000 frames. Trunk lacks `Step`, so this is an absolute budget. Also the `.blit` size at trunk and head.
- [ ] Probe. Run the port driver on `long-play.inputs` five times and take the median. Build STM32 at trunk and head, interleaved, for the size.
- [ ] Baseline. Record the trunk `.blit` size first.
- [ ] Rule. Fail if one `Step` costs more than 200 microseconds on the host or the `.blit` grows by more than 512 bytes.

**Review gate.** None. CE-3 is not review-gated.

**Merge.**

- [ ] Root's clean verdict at the exact head SHA.
- [ ] Bugbot triage done.
- [ ] Rebased onto current trunk after the verdict, patch-id unchanged.
- [ ] The root appends CE-3 to the base-branch stack and the operator lands it bottom-up.

## Run one game frame every 30 ms and match the original with no input (CE-4)

**Depends on.** CE-3.

**Files.**

- [ ] Edit `game.hpp` and `game.cpp`.
- [ ] Edit `chuckie_egg.cpp`.
- [ ] Edit `tools/parity/expected-divergent.txt`.
- [ ] Delete `tools/parity/idle-divergences.txt`.
- [ ] Create `frame_clock.hpp`.
- [ ] Create `tools/parity/clock_test.cpp`, and add it to the `parity` target in `CMakeLists.txt`.

**Build.**

- [ ] Move the clock out of `chuckie_egg.cpp` into `FrameClock` in `frame_clock.hpp`. `FrameClock::due(uint32_t now)` returns how many `Step` calls to run, at one per 30 ms and at most two per call. It advances its last time by 30 ms per step, and it drops the rest of a longer backlog. 30 ms matches `sdl.c:145` upstream.
- [ ] `update` in `chuckie_egg.cpp` calls `Game::Step` the number of times `FrameClock::due` returns. It logs the running `Step` count and the steps run in each `update` with `debugf`, which the live lanes read.
- [ ] Fix every difference in `tools/parity/idle-divergences.txt`, then delete that file. Rerun `idle` after each fix, because a fix can expose a later difference. The two known differences are Henry's start x and duck-timer slot 8. For slot 8, return from `Game::moveDucks` after the mother duck runs, as `chuckie.c:861` does. Every later gate compares Henry and hen fields, so these fixes come first.

**You see.**

- [ ] Henry crosses level 1 from left wall to right wall in the same number of frames as the original driver, and in about the same wall time as the original running on the host.

**Verify, unit.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] `clock_test.cpp` feeds `FrameClock::due` timestamps every 10 ms for 3 seconds and checks for exactly 100 steps. It then jumps 500 ms and checks for 2 steps, then 1 step per 30 ms after that. The trace diff cannot see the clock, because it calls `Step` once per input frame. Run `tools/parity/run.sh --clock`.
- [ ] `idle` prints `PASS` and leaves `expected-divergent.txt`. Every script that passed at trunk still prints `PASS`. Run `tools/parity/run.sh --all`.

**Verify, live.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked. Ten lanes on `inherit-parent` at the PR head, per the boot recipe.

- [ ] Lane 1. Regression lane against trunk. Hold right for 3 seconds at trunk and at head. Save `walk3s-trunk.png` and `walk3s-head.png`. Pass when head runs 100 `Step` calls within one, counted from the `debugf` step counter. Do not infer frames from Henry's position, because a wall or collision stops him sooner.
- [ ] Lane 2. Record 10 seconds of walking. Save `cadence.png` of the frame-step plot. Pass when Henry moves on 33 plus or minus 1 frames per second.
- [ ] Lane 3. Jump from standing. Save `jump-apex.png`. Pass when the apex height matches the original driver's trace.
- [ ] Lane 4. Climb a full ladder. Save `ladder-top.png`. Pass when the climb takes the same frame count as the original.
- [ ] Lane 5. Watch a hen for 10 seconds. Save `hen.png`. Pass when the hen's steps match the original's every-12-frame rate.
- [ ] Lane 6. Watch the timer for 20 seconds. Save `timer.png`. Pass when the timer drops by the same amount as the original driver over 667 frames.
- [ ] Lane 7. Run the web build for 30 seconds. Save `web-cadence.png`. Pass when the timer value matches the SDL build within one unit.
- [ ] Lane 8. Pause the game with `kill -STOP`, wait 500 ms, and resume it with `kill -CONT`. Save `backlog.png`. Pass when `debugf` shows at most two steps in the first `update` after the resume, and one step per 30 ms after that.
- [ ] Lane 9. Walk off a ledge. Save `fall.png`. Pass when the fall frame count matches the original.
- [ ] Lane 10. Run `run.sh --all` and `run.sh --clock`. Save `parity.png`. Pass when both exit zero.

**Verify, perf.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] Metric. Mean microseconds per `Game::Step` over `long-play.inputs`, at trunk and head.
- [ ] Probe. Run the port driver at trunk and head, interleaved, five times each.
- [ ] Baseline. Record the trunk median first.
- [ ] Rule. Fail if the head median is more than 10 percent above trunk.

**Review gate.** The operator reviews before merge.

- [ ] Copy lane 1 and lane 2 screenshots into `docs/media/ce-4-review-walk.png` and `docs/media/ce-4-review-cadence.png`.
- [ ] Record a 30 to 60 second video of level 1 play with `drive.sh record`. Save it as `docs/media/ce-4-review.mp4`.
- [ ] Post the screenshots and the video in chat. Stop at merge-ready. Wait for the operator's click.

**Merge.**

- [ ] Root's clean verdict at the exact head SHA.
- [ ] Bugbot triage done.
- [ ] Rebased onto current trunk after the verdict, patch-id unchanged.
- [ ] The root appends CE-4 to the base-branch stack and the operator lands it bottom-up.

## Let Henry ride the lifts (CE-5)

**Depends on.** CE-4.

**Files.**

- [ ] Edit `game.cpp` and `game.hpp`.
- [ ] Edit `tools/parity/expected-divergent.txt`.
- [ ] Create `tools/parity/scripts/lift-ride.inputs` and `tools/parity/scripts/lift-crush.inputs`.

**Build.**

- [ ] Use level 3 for every lift scenario, with the CE-3 start-level option. Level 3 is the first layout with a lift, because the third header byte of `level1` and `level2` in `levels.cpp` is `0x00`.
- [ ] Port `PlayerHitLift` (`chuckie.c:421`) into `Game::henryHitLift`, including the Y check and the +10 landing and +9 staying edges.
- [ ] Port the LIFT mode of `MovePlayer` (`chuckie.c:614`) into `Game::liftHenry`, and the crush death at `chuckie.c:630`.

**You see.**

- [ ] On level 3, Henry jumps onto a lift, rides it up, and steps off onto a ledge. Riding it to the top kills him.

**Verify, unit.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] `lift-ride` and `lift-crush` print `PASS`. Run `tools/parity/run.sh --all`.

**Verify, live.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked. Ten lanes on `inherit-parent` at the PR head, per the boot recipe.

- [ ] Lane 1. Regression lane against trunk. Start on level 3 and jump onto the lift at trunk and head. Save `lift-trunk.png` and `lift-head.png`. Pass when head Henry stands on the lift and trunk Henry falls through it.
- [ ] Lane 2. Ride the lift for 5 seconds. Save `riding.png`. Pass when Henry's y changes by 2 pixels per lift frame.
- [ ] Lane 3. Step off the lift onto the nearest ledge. Save `step-off.png`. Pass when Henry walks on the ledge.
- [ ] Lane 4. Ride the lift to the top. Save `crush.png`. Pass when Henry dies.
- [ ] Lane 5. Jump from the lift. Save `lift-jump.png`. Pass when the jump arc matches the original's trace.
- [ ] Lane 6. Walk off the lift edge. Save `lift-fall.png`. Pass when Henry falls.
- [ ] Lane 7. Land on the lift as it passes its wrap point. Save `wrap.png`. Pass when Henry lands on the platform that is on screen.
- [ ] Lane 8. Play level 1, which has no lift, for 30 seconds. Save `no-lift.png`. Pass when nothing about lifts appears.
- [ ] Lane 9. Collect an egg from the lift. Save `lift-egg.png`. Pass when the score rises by 100.
- [ ] Lane 10. Run `run.sh --all`. Save `parity.png`. Pass when both lift scripts print `PASS`.

**Verify, perf.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] Metric. Mean microseconds per `Game::Step` over `long-play.inputs`, at trunk and head.
- [ ] Probe. Run the port driver at trunk and head, interleaved, five times each.
- [ ] Baseline. Record the trunk median first.
- [ ] Rule. Fail if the head median is more than 10 percent above trunk.

**Review gate.** The operator reviews before merge.

- [ ] Copy lane 2 and lane 4 screenshots into `docs/media/ce-5-review-riding.png` and `docs/media/ce-5-review-crush.png`.
- [ ] Record a 30 to 60 second video of level 3 lift play. Save it as `docs/media/ce-5-review.mp4`.
- [ ] Post the screenshots and the video in chat. Stop at merge-ready. Wait for the operator's click.

**Merge.**

- [ ] Root's clean verdict at the exact head SHA.
- [ ] Bugbot triage done.
- [ ] Rebased onto current trunk after the verdict, patch-id unchanged.
- [ ] The root appends CE-5 to the base-branch stack and the operator lands it bottom-up.

## Lose lives and return to the start after game over (CE-6)

**Depends on.** CE-5.

**Files.**

- [ ] Edit `game.cpp` and `game.hpp`.
- [ ] Edit `tools/parity/expected-divergent.txt`.
- [ ] Create `tools/parity/scripts/die-to-hen.inputs`, `tools/parity/scripts/timeout.inputs`, and `tools/parity/scripts/extra-life.inputs`.

**Build.**

- [ ] Move the score into `Player` so `loadLevel` stops resetting it. Restore each player's collected eggs and grain on respawn, from `Player.egg` and `Player.grain`.
- [ ] On death, take one life and restart the level for that player. On zero lives, go to `GAME_OVER`. A on `GAME_OVER` returns to `HOW_MANY`.
- [ ] Kill Henry when the timer reaches zero, and delete both `abort()` calls in `game.cpp`. Upstream calls `abort()` at `chuckie.c:884`, so the trace driver patches that line to `is_dead++`.
- [ ] Port `MaybeAddExtraLife` (`chuckie.c:1009`). Grant one life per 10,000 points and show lives in the HUD.
- [ ] Add a start-score option for testing. `cmake -DCHUCKIE_START_SCORE=<n>` sets the score a new game starts with, and both drivers take `--score <n>`. `extra-life.inputs` starts at 9,950 on level 1. Do not test the extra life on a high level, because the level rules do not match upstream until CE-7.

**You see.**

- [ ] Henry dies to a hen, loses a life, and restarts level 1 with the eggs he already took still gone. After the fifth death the game shows game over, and A returns to the player-count screen.

**Verify, unit.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] `die-to-hen`, `timeout`, and `extra-life` print `PASS`. Run `tools/parity/run.sh --all`.

**Verify, live.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked. Ten lanes on `inherit-parent` at the PR head, per the boot recipe.

- [ ] Lane 1. Regression lane against trunk. Walk into the first hen at trunk and head. Save `hen-death-trunk.png` and `hen-death-head.png`. Pass when trunk shows game over with 5 lives and head shows level 1 again with 4 lives.
- [ ] Lane 2. Take two eggs, then die. Save `eggs-kept.png`. Pass when those two eggs are gone after the restart and the score is unchanged.
- [ ] Lane 3. Die five times. Save `game-over.png`. Pass when the game over screen shows.
- [ ] Lane 4. Press A on game over. Save `back-to-start.png`. Pass when the player-count screen shows.
- [ ] Lane 5. Start a second game. Save `second-game.png`. Pass when lives are 5 and the score is 0.
- [ ] Lane 6. Wait for the timer to reach zero. Save `timeout.png`. Pass when Henry dies and the process is still running.
- [ ] Lane 7. Fall off the bottom of the screen. Save `fall-death.png`. Pass when Henry loses one life.
- [ ] Lane 8. Start with `drive.sh start --score 9950` and take one egg. Save `extra-life.png`. Pass when lives rise by one on the frame the score crosses 10,000.
- [ ] Lane 9. Die to the lift crush. Save `crush-death.png`. Pass when Henry loses one life.
- [ ] Lane 10. Run `run.sh --all`. Save `parity.png`. Pass when the three new scripts print `PASS`.

**Verify, perf.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] Metric. Mean microseconds per `Game::Step` over `long-play.inputs`, at trunk and head.
- [ ] Probe. Run the port driver at trunk and head, interleaved, five times each.
- [ ] Baseline. Record the trunk median first.
- [ ] Rule. Fail if the head median is more than 10 percent above trunk.

**Review gate.** The operator reviews before merge.

- [ ] Copy lane 1 and lane 3 screenshots into `docs/media/ce-6-review-death.png` and `docs/media/ce-6-review-game-over.png`.
- [ ] Record a 30 to 60 second video of dying, respawning, and reaching game over. Save it as `docs/media/ce-6-review.mp4`.
- [ ] Post the screenshots and the video in chat. Stop at merge-ready. Wait for the operator's click.

**Merge.**

- [ ] Root's clean verdict at the exact head SHA.
- [ ] Bugbot triage done.
- [ ] Rebased onto current trunk after the verdict, patch-id unchanged.
- [ ] The root appends CE-6 to the base-branch stack and the operator lands it bottom-up.

## Advance through levels with the original difficulty curve (CE-7)

**Depends on.** CE-6.

**Files.**

- [ ] Edit `game.cpp` and `game.hpp`.
- [ ] Edit `tools/parity/expected-divergent.txt`.
- [ ] Create `tools/parity/scripts/level-skip-40.inputs`, which uses a debug level skip like upstream's `l` key. Other lanes start on a level with the CE-3 start-level option.

**Build.**

- [ ] After the bonus drains, advance `current_level`, save and restore player state, and load level data with `current_level & 7`, per `chuckie.c:1155-1174`.
- [ ] Port the difficulty rules from `chuckie.c:193-196`, `chuckie.c:360`, and `chuckie.c:1097-1101`. No hens on levels 9 to 16. Five hens from level 25. The mother duck from level 9. `duck_speed` 5 from level 33. The timer and bonus start values. The egg value is `min((current_level>>2)+1, 10)` x 100.
- [ ] Rotate turns between players after each death when more than one player is playing.
- [ ] Draw the mother duck only when `hasBigDuck` is set.

**You see.**

- [ ] Finishing level 1 shows level 2. Level 9 shows the first layout again, with the mother duck out and no hens.

**Verify, unit.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] `level-skip-40` prints `PASS`, which covers every rule change up to level 40. Run `tools/parity/run.sh --all`.

**Verify, live.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked. Ten lanes on `inherit-parent` at the PR head, per the boot recipe.

- [ ] Lane 1. Regression lane against trunk. Collect every egg on level 1 at trunk and head. Save `complete-trunk.png` and `complete-head.png`. Pass when trunk stays on level 1 and head shows level 2.
- [ ] Lane 2. Watch the bonus drain. Save `bonus-drain.png`. Pass when the score rises by the bonus value.
- [ ] Lane 3. Skip to level 9. Save `level9.png`. Pass when the mother duck is out and no hens show.
- [ ] Lane 4. Skip to level 1 and look for the mother duck. Save `no-duck.png`. Pass when no mother duck is drawn.
- [ ] Lane 5. Skip to level 25. Save `level25.png`. Pass when five hens show.
- [ ] Lane 6. Skip to level 33 and time a hen. Save `level33.png`. Pass when hen steps come every 8 frames.
- [ ] Lane 7. Take an egg on level 20. Save `egg-value.png`. Pass when the score rises by 500, because `current_level` is 19 there.
- [ ] Lane 8. Start a two-player game and die once. Save `two-player.png`. Pass when player 2's turn starts on level 1.
- [ ] Lane 9. Let the mother duck catch Henry on level 9. Save `duck-death.png`. Pass when Henry loses a life.
- [ ] Lane 10. Run `run.sh --all`. Save `parity.png`. Pass when `level-skip-40` prints `PASS`.

**Verify, perf.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] Metric. Mean microseconds per `Game::Step` over `long-play.inputs`, at trunk and head.
- [ ] Probe. Run the port driver at trunk and head, interleaved, five times each.
- [ ] Baseline. Record the trunk median first.
- [ ] Rule. Fail if the head median is more than 10 percent above trunk.

**Review gate.** The operator reviews before merge.

- [ ] Copy lane 1 and lane 3 screenshots into `docs/media/ce-7-review-level2.png` and `docs/media/ce-7-review-level9.png`.
- [ ] Record a 30 to 60 second video that finishes level 1 and plays level 9. Save it as `docs/media/ce-7-review.mp4`.
- [ ] Post the screenshots and the video in chat. Stop at merge-ready. Wait for the operator's click.

**Merge.**

- [ ] Root's clean verdict at the exact head SHA.
- [ ] Bugbot triage done.
- [ ] Rebased onto current trunk after the verdict, patch-id unchanged.
- [ ] The root appends CE-7 to the base-branch stack and the operator lands it bottom-up.

## Play the original sound effects (CE-8)

**Depends on.** CE-7.

**Files.**

- [ ] Edit `game.cpp` and `game.hpp`.
- [ ] Edit `chuckie_egg.cpp`.

**Build.**

- [ ] Confirm first that SDL's `disk` audio driver works in the container. Run the SDL build with `SDL_AUDIODRIVER=disk` and `SDL_DISKAUDIOFILE=/tmp/audio-check.raw`, and check that the file grows. If it does not, add a PulseAudio null sink to the Dockerfile and `drive.sh` in this PR, and record that change.
- [ ] Port `MakeSound` (`chuckie.c:690`) and the `squidge` noise onto `blit::channels`. Channel 0 is the square-wave beep and channel 1 is the noise.

**You see.**

- [ ] Walking beeps on every other frame, with the pitch set by Henry's mode. Taking an egg or grain plays the noise burst.

**Verify, unit.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] Add the beep frequency and the noise trigger to `FrameTrace`, and check that every script that passed at trunk still prints `PASS`. Run `tools/parity/run.sh --all`.

**Verify, live.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked. Ten lanes on `inherit-parent` at the PR head, per the boot recipe. Each lane captures audio with the recipe the first **Build** box recorded, then renders a spectrogram of the capture with `ffmpeg`. With the disk driver, run the game with `SDL_AUDIODRIVER=disk` and `SDL_DISKAUDIOFILE=/tmp/swarm-ce-8/worker-<n>/audio.raw`. With the PulseAudio fallback, run it with `SDL_AUDIODRIVER=pulseaudio` and record the null sink's monitor with `parec`.

- [ ] Lane 1. Regression lane against trunk. Walk right for 3 seconds at trunk and head. Save `audio-trunk.png` and `audio-head.png` spectrograms. Pass when trunk is silent and head shows a beep every other frame.
- [ ] Lane 2. Climb a ladder. Save `climb-audio.png`. Pass when the beep pitch differs from walking.
- [ ] Lane 3. Jump. Save `jump-audio.png`. Pass when the pitch follows the original's jump table.
- [ ] Lane 4. Take an egg. Save `egg-audio.png`. Pass when a noise burst starts on that frame.
- [ ] Lane 5. Take grain. Save `grain-audio.png`. Pass when a shorter noise burst starts on that frame.
- [ ] Lane 6. Stand still for 5 seconds. Save `idle-audio.png`. Pass when no sound plays.
- [ ] Lane 7. Reach game over. Save `game-over-audio.png`. Pass when sound stops.
- [ ] Lane 8. Play the web build in Playwright's headless Chromium and read its console log. Save `web-audio.png`. Pass when `debugf` shows a beep trigger on the walking frames.
- [ ] Lane 9. Build STM32. Save `stm32-audio-build.png`. Pass when it builds with no new warnings.
- [ ] Lane 10. Run `run.sh --all`. Save `parity.png`. Pass when every script that passed before still passes.

**Verify, perf.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] Metric. Mean microseconds per `Game::Step` over `long-play.inputs`, at trunk and head.
- [ ] Probe. Run the port driver at trunk and head, interleaved, five times each.
- [ ] Baseline. Record the trunk median first.
- [ ] Rule. Fail if the head median is more than 10 percent above trunk.

**Review gate.** The operator reviews before merge.

- [ ] Copy lane 1 and lane 4 spectrogram screenshots into `docs/media/ce-8-review-walk.png` and `docs/media/ce-8-review-egg.png`.
- [ ] Record a 30 to 60 second video with sound of level 1 play. Save it as `docs/media/ce-8-review.mp4`.
- [ ] Post the screenshots and the video in chat. Stop at merge-ready. Wait for the operator's click.

**Merge.**

- [ ] Root's clean verdict at the exact head SHA.
- [ ] Bugbot triage done.
- [ ] Rebased onto current trunk after the verdict, patch-id unchanged.
- [ ] The root appends CE-8 to the base-branch stack and the operator lands it bottom-up.

## Add a title screen, a high score table, and launcher art (CE-9)

**Depends on.** CE-8.

**Files.**

- [ ] Edit `game.cpp` and `game.hpp`.
- [ ] Create `assets/splash.png` and `assets/icon.png`, and edit `metadata.yml` and `assets.yml`.

**Build.**

- [ ] Add a `TITLE` state before `HOW_MANY`, and a high score table of the top 10 scores that `blit::write_save` stores and `blit::read_save` loads. Upstream never built these (`chuckie.c:1116` and `chuckie.c:1140-1142`), so they follow the 8-bit original from memory, and the operator judges them.

**You see.**

- [ ] The game opens on a title screen. A score that makes the table asks for initials, and the table survives a restart.

**Verify, unit.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] The port driver gains a `--start-at-title` flag. With it, `idle` still prints `PASS` after the title is skipped. Run `tools/parity/run.sh --all`.

**Verify, live.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked. Ten lanes on `inherit-parent` at the PR head, per the boot recipe.

- [ ] Lane 1. Regression lane against trunk. Start the game at trunk and head. Save `boot-trunk.png` and `boot-head.png`. Pass when trunk opens on the player-count screen and head opens on the title.
- [ ] Lane 2. Press A on the title. Save `title-to-count.png`. Pass when the player-count screen shows.
- [ ] Lane 3. Finish a game with a score that makes the table. Save `enter-initials.png`. Pass when the game asks for initials.
- [ ] Lane 4. Enter initials. Save `table.png`. Pass when the table shows them at the right rank.
- [ ] Lane 5. Restart the game process. Save `table-persist.png`. Pass when the table still shows the entry.
- [ ] Lane 6. Finish a game with a score of 0. Save `no-entry.png`. Pass when the game skips initials.
- [ ] Lane 7. Delete the save file and start. Save `fresh-table.png`. Pass when the default table shows and nothing crashes.
- [ ] Lane 8. Check the launcher listing on the web build. Save `launcher.png`. Pass when the icon and splash show in place of the placeholders.
- [ ] Lane 9. Build STM32. Save `stm32-size.png`. Pass when the `.blit` builds.
- [ ] Lane 10. Run `run.sh --all`. Save `parity.png`. Pass when every script that passed before still passes.

**Verify, perf.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] Metric. Mean microseconds per `Game::Step` over `long-play.inputs`, and the `.blit` size, at trunk and head.
- [ ] Probe. Run the port driver and the STM32 build at trunk and head, interleaved, five times each.
- [ ] Baseline. Record the trunk median and size first.
- [ ] Rule. Fail if the head `Step` median is more than 10 percent above trunk or the `.blit` grows by more than 64 KiB.

**Review gate.** The operator reviews before merge.

- [ ] Copy lane 1 and lane 4 screenshots into `docs/media/ce-9-review-title.png` and `docs/media/ce-9-review-table.png`.
- [ ] Record a 30 to 60 second video from boot through a high score entry. Save it as `docs/media/ce-9-review.mp4`.
- [ ] Post the screenshots and the video in chat. Stop at merge-ready. Wait for the operator's click.

**Merge.**

- [ ] Root's clean verdict at the exact head SHA.
- [ ] Bugbot triage done.
- [ ] Rebased onto current trunk after the verdict, patch-id unchanged.
- [ ] The root appends CE-9 to the base-branch stack and the operator lands it bottom-up.

## Close the program

- [ ] Every box above is checked with its evidence.
- [ ] Reply to the operator with the report the execution playbook names.

## Appendix A. Prototype evidence

No prototype ran before this plan. The open questions stay unproven, and each is the first box of the PR that depends on it.

- Can the SDL build run under `Xvfb` in the dev container, take `xdotool` input, and give screenshots? Unproven. CE-2 proves it with `drive.sh smoke`. Docker is installed on the host, but the dev image builds four SDKs, so this planning run did not build it.
- Can `Game` build for the host without the 32Blit engine, given that `game.hpp` includes `32blit.hpp`? Unproven. If it cannot, `port_driver.cpp` links the SDK's SDL engine library and never opens a window. CE-3 settles it.
- Is a 30 ms frame right for the port? The upstream frame is 30 ms (`sdl.c:145`, measured by reading). The port's `UPDATE_INTERVAL_MS` is 60, and the `Tickle` clock never advances `lastTime` (`game.cpp:984-989`, read this session), so after the first 60 ms the port steps on every `update` call. CE-4 proves the fix with the trace diff.

## Appendix B. Alternatives rejected

- **GPL-3.0-or-later.** Upstream says "GNU GPL v3" with no "or later" clause, so the port cannot grant later versions for Paul Brook's code. `GPL-3.0-only` is the honest label.
- **Port from memory or video of the 8-bit game.** The C source exists and runs, so a trace diff against it is a test, and memory is not. CE-9 is the one exception, because upstream never built a title or score table.
- **Rewrite `game.cpp` from scratch.** About 60 percent of it is a working translation (player movement, hens, mother duck, pickups). The missing parts are lifts, lives, levels, and sound, which fit the current `Game` class.
- **Tests that check internal functions.** A trace of what the player can see, positions, score, and lives, keeps passing through refactors and fails when the game feels wrong.
- **Mount a local clone of upstream into the container.** It ties the container to one host path, and nothing pins the clone's version.
- **Clone upstream while the image builds.** CI does not use the image, so CE-3 would still need its own copy, and a version change would need an image rebuild.
- **Read upstream on GitHub.** Agents could not search, compile, or diff it, and the trace diff needs the files on disk.
- **Separate, parallel PRs.** CE-4 through CE-9 all edit `game.cpp` and each needs the one before, so a linear stack avoids constant conflicts.

## Appendix C. Risks

- **No control skill for 32Blit.** CE-2 builds `tools/live/drive.sh` to fill that gap. Until CE-2 lands, CE-1 lanes drive `Xvfb` by hand.
- **Ten live lanes per PR is a lot for a hobby port.** The plan template requires them. The operator can cut CE-1 and CE-2 to three lanes each without losing real coverage.
- **The SDK is unpinned.** CI and the Dockerfile both use the SDK's default branch, so an SDK change can break a build in the middle of the stack. CE-2 pins `SDK_REF` to one SHA in the Dockerfile, in `devcontainer.json`, and in the CI checkout.
- **Upstream's `abort()` at `chuckie.c:884`.** The original crashes when the timer reaches zero. The CE-6 trace driver patches it to a death, and the port does the same.
- **Hen pseudo-random sequence.** Hen paths depend on the LFSR reseed each level (`chuckie.c:1105-1106`). Any change to the order of `frobRandom` calls breaks the trace diff in CE-6 and CE-7, which is the point.
- **A & F Software's rights in the original game.** Upstream ships the level and sprite data under GPLv3 and has done so since 2011. The port inherits that position and credits A & F, but it cannot grant more than upstream holds.
- **Pico targets are not in CI.** The README documents PicoSystem builds, but `build.yml` does not run them. The plan does not add them. A later PR can.

## Appendix D. Links and reading list

- Upstream source, committed to `third_party/pbrook-chuckie-egg/` by CE-1, commit `e18004643193a8ff9434cf77b15a13219f6d745e`, remote `github.com/pbrook/Chuckie-Egg`.
- Read `chuckie.c:1109` (`run_game`) and `chuckie.c:527` (`MovePlayer`) before editing `game.cpp`.
- CE-3 gets `<pstack>/skills/how/SKILL.md` for the `Step` and `FrameTrace` split, and `<pstack>/skills/interrogate/SKILL.md` before it ships, because every later PR depends on that seam.
- Keep the decision trail per `<pstack>/skills/show-me-your-work/SKILL.md` locally, and commit it with CE-3, the PR whose design every later PR depends on.
