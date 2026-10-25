# CE-2 verification swarm brief

You are one independent verifier for CE-2, PR https://github.com/ntwyman/32blit-chuckie-egg/pull/16. You did not write this code. Do not trust the PR body or the owner's claims. Check everything yourself against the real artifacts.

## Fixed inputs

- Head SHA: `eb4ed882fdd2e1de91f1d48f15af2d27cf448c70` (branch `ce-2/live-driver`).
- Trunk for this PR is its parent: `1ff20c342e9390459e4519a7099b6b05cae0bd2d` (branch `ce-1/gpl-relicense`).
- Plan: `git show eb4ed88:docs/plans/port-completion.md`, section "Add a scripted driver for the SDL build (CE-2)", plus "Boot recipe, for every live lane".
- Operator decision: CE-2's live swarm keeps only lanes 1, 2, and 6.
- Measured corrections the owner was told to apply: Xvfb at 640x480, not 320x240. The A button is `z`; from boot, `z` at "How many players", then `z` at "Ready player". `SDK_REF` is pinned to `db99cb7fad2ee163bf7251193566bfcf6781da7c`, the SDK this container runs.

## Rules

- Work only in your own worktree at the exact SHA: `git worktree add /tmp/lane-ce-2-<n> <SHA>`, where `<n>` is your lane number. Never edit files in `/workspaces/32blit-chuckie-egg` itself. Never push. Never comment on the PR or issues.
- Build with `cmake -B build.sdl && cmake --build build.sdl -j`, and STM32 with `-DCMAKE_TOOLCHAIN_FILE=/opt/32blit-sdk/32blit.toolchain` when your lane needs it. Never call `docker`.
- Drive the game only through `tools/live/drive.sh` from your worktree. Give your lane its own display with the driver's `LIVE_LANE` or `LIVE_DISPLAY` setting (read `tools/live/README.md`), so lanes never share one. Stop your game and Xvfb when done.
- Save every screenshot and log under `/tmp/swarm-ce-2/worker-<n>/`.
- Your report starts with `PASS`, `ISSUES`, or `BLOCKED`. It names the SHA and the exact commands. List every defect you can prove, each with its command and output. A defect counts even if you think it is minor.

## Lanes

Your brief names exactly one lane. Do only that lane.

- **Lane G, gates.** Run the plan's CE-2 "You see" and "Verify, unit" boxes literally at head: `tools/live/drive.sh smoke` prints `smoke: ok`, writes `smoke.png` showing level 1 after one player starts, and compares against `tools/live/golden/level1-start.png` with `compare -metric AE` at zero. Check every changed path is inside CE-2's file boundary in the plan's "Hold the file boundaries" list, or under `tools/live/`. Build SDL and STM32 at head and parent and confirm zero new warnings. Run `tools/check-license.sh`. Confirm CI on eb4ed88 is green, including the Live smoke job, with `gh run list --branch ce-2/live-driver` and `gh run view`. If CI on eb4ed88 has not finished, wait for it.
- **Lane 1.** Plan lane 1. Trunk has no driver, so record that. Run `drive.sh smoke` at head from a clean worktree. Save `smoke.png`. Pass when it shows level 1 with Henry at his start tile.
- **Lane 2.** Plan lane 2. Start one player and run `keys walk-right.keys`. Save `walked.png` and a before image. Measure Henry's x before and after from the images. Pass when he moved at least 40 pixels right.
- **Lane 6.** Plan lane 6. Feed a key script with an unknown key name. Save `bad-key.png` of the output. Pass when `drive.sh` exits non-zero and names the bad line. Also feed a malformed line (missing hold time, a negative or non-numeric time) and report what happens.
- **Lane P, perf.** Plan "Verify, perf" for CE-2. Run `time tools/live/drive.sh smoke` five times in one container and report each wall time and the median. Fail if the median exceeds 20 seconds. Build STM32 at parent, head, parent, head, each clean, and record the `.blit` size each time. Fail if the size changes at all. Report how many smoke runs needed a retry.
- **Lane A1, audit: is the smoke gate honest?** The plan says smoke compares one frame against the golden image and fails above zero differing pixels. The owner instead records a burst of frames, searches for one identical to the golden image, and retries the whole run up to 5 times. Read `drive.sh` and decide, with proof, whether this still fails when the game is wrong. At minimum: replace the golden image with a frame from a different screen (for example the "How many players" screen, or level 1 after Henry moved) and show smoke fails; make the game never reach level 1 (for example a key script that never presses `z`) and show smoke fails within a bounded time; and check what the retry loop does to a real failure (how long it takes and what it prints). Run smoke 20 times at head and report how often the first attempt misses. Explain why the first attempt misses, from evidence: read `chuckie_egg.cpp` and `game.cpp` for how often the game steps and renders, and look at the recorded frames around a miss. Say whether a single fixed-frame compare is achievable at this head. The root decides whether to countersign this gate, so give it the facts.
- **Lane A2, audit: pin, Dockerfile, CI, and driver robustness.** Read the diff to `.devcontainer/Dockerfile`, `.devcontainer/devcontainer.json`, and `.github/workflows/build.yml`. Check `SDK_REF` is the same SHA in all three, that the Dockerfile's SDK clone works with a SHA (run the same `git init`, `git fetch --depth 1 origin <sha>`, `git checkout FETCH_HEAD` sequence in a scratch folder against the real SDK remote, since the container cannot build its image), and that nothing else in the image build changed. Check the CI Live smoke job installs what it needs and would fail the job on a smoke failure. Read `drive.sh` for robustness: what `start` does when a stale pid file exists, whether `stop` kills only its own lane's processes, whether two lanes with different `LIVE_LANE` values can run at once without interfering (run two at once and show it), and whether temporary files and recordings are cleaned up.
