# CE-2 fix round 1

You take over the CE-2 owner role for one fix round. Read `/workspaces/32blit-chuckie-egg/.audit/briefs/ce-2-owner.md` in full. Its reading list, rules, and report format apply, with these changes:

- Branch `ce-2/live-driver`, PR #16, head `eb4ed882fdd2e1de91f1d48f15af2d27cf448c70`. The root rebased it onto CE-1's clean head `1ff20c3`. Base your work on `eb4ed88`. Do not rebase. Work on a local branch tracking `origin/ce-2/live-driver`, and push with `git push origin HEAD:ce-2/live-driver`.
- Append to `/workspaces/32blit-chuckie-egg/.audit/ce-2.tsv`, starting with a `start` row.
- Have no background work running when you report.

## The root's swarm verdict at eb4ed88: ISSUES

Gates, lanes 1 and 2, and perf passed. Three lanes found defects. Evidence is under `/tmp/swarm-ce-2/worker-26/` (lane 6), `/tmp/swarm-ce-2/worker-28/` (smoke-gate audit), and `/tmp/swarm-ce-2/worker-29/` (driver audit). Read those reports' logs before you start.

### The smoke gate (no countersign)

The root will not countersign the current smoke gate. It searches about 190 recorded frames for any frame whose hash equals the golden image, and retries up to 5 times. So:
- a golden from the "How many players" screen, the "Ready player" screen, or a later level-1 frame also passes;
- the `compare -metric AE` step runs on the frame chosen for matching, so it is 0 by construction;
- the retries hide a real game bug: the TIME sprite reads past the sprite sheet (issue #17), so one HUD pixel is heap garbage that differs per process. The golden image has one such pixel baked in.

A separate PR fixes the sprite bug (issue #17). After it lands under CE-2, the root rebases CE-2 onto it, and a short later round regenerates the golden image. **Do not regenerate the golden image in this round.**

Change smoke to:
- select the first level-1 frame deterministically, the way `cmd_golden` already finds it (the third distinct-hash run in the recording), and write exactly that frame to `smoke.png`;
- compare `smoke.png` against the golden with `compare -metric AE` and fail above zero, with no search over other frames;
- retry only when the run itself failed (no window, no level-1 frame found, the recorder died), never on a pixel mismatch, and print why each retry happened.

Until the sprite fix lands, this smoke will fail some runs on the garbage pixel. That is expected. Prove instead that frame selection is deterministic: in 10 runs, the selected frame's index is the same relative to the key press, and every selected frame shows level 1 with TIME 900 and Henry unmoved. Prove that a golden from the "How many players" screen, from "Ready player", or from a later level-1 frame now fails. Fix `tools/live/README.md`, which says the game "renders every other tick". The audit's recordings show that is wrong. Describe the real cause (issue #17).

### Key-script parser (lane 6)

1. `parse_keys` expands an unquoted `${key//+/ }`, so `* 100` is matched against the current directory. Disable globbing there.
2. A script with no steps calls `xdotool keydown` with no arguments and crashes. Make an empty script a no-op that exits 0.
3. Empty combo parts (`left++up 100`, `+z 100`) are silently accepted. Reject them, with the file:line.
4. `u`, `i`, `o`, and `p` are accepted but not in the README's key table. Either drop them or document them. Pick whichever matches the SDK's key map for 32Blit buttons.

### Driver robustness (driver audit)

5. `start` and `stop` trust any live pid in a pid file (`pid_alive` is only `kill -0`). Check the pid is the process the driver started (for example its command line or its start time) before reporting it running or killing it.
6. Killing smoke orphans its `ffmpeg` recorder, which `stop` cannot see. The smoke and golden traps must kill the recorder, and `stop` must stop any recorder the lane started, including a background `record`.
7. `OUT_DIR` does not depend on the lane, so lanes in one worktree share `out/smoke.png`. Make the output folder per lane by default.
8. State folders `/tmp/chuckie-live-<display>/` keep recordings and logs forever. `stop` removes recordings. Keep logs only when a run failed, and say where they are.
9. Smaller: the README says "640x480 or larger", but smoke needs exactly 640x480; say so, or reject other sizes for smoke. `start` prints success when no window appeared after its wait; fail instead. `stop` sends one `kill` and forgets the pid; confirm the process ended, escalating to `KILL` after a short wait. `start` deletes `/tmp/.X<n>-lock` blind; only delete it when no process holds that display. A non-numeric `LIVE_LANE` gives a cryptic arithmetic error; validate it with a clear message. On a failed smoke, CI uploads nothing; write the selected or nearest frame and `game.log` into the uploaded folder.
10. `resolve_script` checks the current directory before the repo's script folder, so a `start-one-player.keys` in the current directory hijacks smoke. Smoke must use the repo's script. For user scripts, prefer an explicit path over a bare name, and document the order.

## Prove it

For every numbered item, add a check to a test script under `tools/live/` (for example `tools/live/test-drive.sh`) that fails at `eb4ed88` and passes at your head, where the item can be tested without a judgment call. Run it in CI next to the smoke job if it takes under a minute. Save the logs of both runs under `/tmp/swarm-ce-2/owner-fix-1/`. Run two lanes at once and show they do not interfere.

## After the fix

- Build SDL and STM32 with zero new warnings. The `.blit` size must not change.
- Run `/deslop` and the no-comments skill. Commit in small commits with technical-writing messages. A plain fast-forward push.
- Comment on #5 with the new head SHA and what changed.
- Wait for CI to go green. The Live smoke job may fail on the garbage pixel until the sprite fix lands. If it does, report that with the job log, and do not loosen the gate to make it pass.
- Report: the new head SHA, the test logs, CI status, threads triaged, and anything open.
