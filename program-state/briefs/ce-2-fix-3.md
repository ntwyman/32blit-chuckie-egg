# CE-2 fix round 3: minor findings from the second swarm

You take over the CE-2 owner role for one short round. Read `/workspaces/32blit-chuckie-egg/.audit/briefs/ce-2-owner.md` and `ce-2-fix-2.md` in the same folder. Their rules and report format apply, with these changes:

- Branch `ce-2/live-driver`, PR #16, head `05102f5b6cae7df720de1a3a096e6fbd1997af7d`. Base your work on that head. Do not rebase. Work on a local branch tracking `origin/ce-2/live-driver`, and push with `git push origin HEAD:ce-2/live-driver`.
- Append to `/workspaces/32blit-chuckie-egg/.audit/ce-2.tsv`, starting with a `start` row.
- Use only `LIVE_LANE` values 80 to 89 for your own runs, and `LIVE_TEST_LANE_BASE=80` for `test-drive.sh`. Never kill a process you did not start.
- Have no background work running when you report.

## The root's second swarm at 05102f5: ISSUES, all minor

The smoke gate passed its audit, and the root countersigned it. Live lanes 1 and 2 and perf passed. Fix exactly these findings, and nothing else. Evidence is under `/tmp/swarm2-ce-2/worker-60/`, `worker-64/`, `worker-66/`, and `worker-70/`.

1. **Stale README.** `tools/live/README.md:69` ("How `smoke` stays exact") still says one HUD pixel is heap garbage and smoke fails on some runs until #17 is fixed. The parent fixes #17, and the golden was regenerated. Rewrite the paragraph to describe the gate as it is now.
2. **README key table.** `escape` is accepted (`drive.sh:199`) but not listed. The row "`1`, `2`, `3`, `esc` | Home, menu, and the joystick button" gives four keys and three meanings. Per the SDK key map in `/opt/32blit-sdk/32blit-sdl/Input.cpp`, list every accepted key with its 32Blit button.
3. **`test-smoke.sh` frame-spread check.** `test-smoke.sh:59` fails when the selected frame's offset from the ready screen spreads more than 6 frames. Under host load the spread reached 14 (and 43 to 69 in another lane), while every picked image was byte-identical and matched the golden. The offset measures key-script timing, not the game. Replace that check with one that asserts every run's picked image is byte-identical and matches the golden, and report the offset spread as information only.
4. **Final attempt says "retrying".** `drive.sh:385` prints "attempt 5 of 5: run failed, retrying" on the last attempt. Print that no attempts remain instead.
5. **Leading-zero numbers.** `LIVE_LANE=08` passes validation (`drive.sh:15-20`), then `$((99 + LANE))` reads it as octal and fails with "value too great for base". `LIVE_LANE=010` silently maps to display :107. A 23-digit lane passes and wraps. `LIVE_WINDOW_WAIT=08` hits the same octal read. Make every numeric setting parse as decimal (for example `$((10#$LANE))` after validating digits only) and bound `LIVE_LANE` so the display number stays sensible (for example 0 to 899). Give a clear error otherwise.
6. **Lock check and other users' processes.** `drive.sh:124` uses `kill -0`, which fails with EPERM for a live process owned by another user, so the lock gets deleted. Treat EPERM as alive (for example check `/proc/<pid>` exists), and keep the lock.
7. **`LIVE_SCREEN` message.** `LIVE_SCREEN=640x480` is rejected with "need an exact 640x480 screen, got LIVE_SCREEN=640x480", and `640x480x16` is accepted. Require exactly `640x480x24` for smoke and golden, and say so in the message.
8. **CI artifacts when driver tests fail.** In `.github/workflows/build.yml` the Smoke test step has no `if: always()`, so a driver-test failure skips it. `test-drive.sh`'s cleanup (lines 13 to 21) deletes `tools/live/out/lane$lane` and the state folders, so a failed side-by-side check uploads nothing. Make a failing test-drive check leave its lanes' frames and logs under the uploaded folder, and run the smoke step even if driver tests fail.
9. **`golden` failures drop logs.** `cmd_golden` (`drive.sh:393-410`) exits through `die` or `set -e` without `keep_logs`, so the EXIT trap deletes the logs. Keep them on failure, as smoke does.

## Prove it

- For items 4 to 9, add a check to `test-drive.sh` that fails at `05102f5` and passes at your head, where a check can be written without judgment. Run `test-drive.sh` at both SHAs and save the logs.
- Run `test-smoke.sh` and 10 smoke runs at your head.
- Save everything under `/tmp/swarm-ce-2/owner-fix-3/`.

## After the fix

- Build SDL and STM32 with zero new warnings. The `.blit` size must equal the parent's.
- Run `/deslop` and the no-comments skill as a subagent.
- Small commits with technical-writing messages. A plain fast-forward push.
- Comment on #5 with the new head SHA and what changed.
- Wait for CI to go green. Poll review threads at least 10 minutes after green.
- Report: new head SHA, test logs at both SHAs, smoke receipts, CI status, threads, and anything open.
