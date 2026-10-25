# CE-3 fix round 1

You take over the CE-3 owner role for one fix round. Read `/workspaces/32blit-chuckie-egg/.audit/briefs/ce-3-owner.md` in full. Its rules and report format apply, with these changes:

- Branch `ce-3/trace-diff`, PR #20, head `ddd835f20c1ae5511d17938280f99ae391c492f6`. Base your work on it. Do not rebase. Work on a local branch tracking `origin/ce-3/trace-diff`, and push with `git push origin HEAD:ce-3/trace-diff`.
- Append to `/workspaces/32blit-chuckie-egg/.audit/ce-3.tsv`, starting with a `start` row.
- Use only `LIVE_LANE` 400 to 429 and `LIVE_TEST_LANE_BASE=400`. Never kill a process you did not start.
- Have no background work running when you report.

## The root's first-wave verdict at ddd835f: ISSUES, all minor

Gates, perf, and the start-level and driver audit passed. The coordinate audit confirmed `239 - Y` is exact by rendering both games: every frame-0 trace difference is a real on-screen difference. Keep the conversion as it is. Evidence is under `/tmp/swarm-ce-3/worker-300/`, `worker-330/`, `worker-340/`, `worker-350/`, and `worker-360/`. Fix exactly these three findings.

1. **Parity code compiles into device and web builds.** `game.hpp:7` includes `tools/parity/trace.h`, and `Game::Snapshot` and `Game::upstreamPosition` are compiled into the STM32 and web objects. The linker drops them, but the plan wants the parity seam kept out of device builds. Guard the include, the declarations, and the definitions with the `CHUCKIE_PARITY` compile definition that only the parity target sets. Show that `arm-none-eabi-nm` on the STM32 `game.cpp.obj` no longer lists either symbol, that the dependency files for STM32 and web no longer list `trace.h`, and that the parity build still works.
2. **The start-level patch and a restart after game over.** `start-level.patch` sets `level[i] = current_level = parity_start_level`. Upstream's `start_game` reads `current_level` on a restart after game over (`chuckie.c:1049-1052`), so a script that completes a level and then loses every life would restart differently from upstream. No current script hits this. Either change the patch so a restart behaves exactly as upstream while the start level still gets the right bonus, and prove it, or explain why that is not possible and document the limit in `tools/parity/README.md` with the case that breaks. Prefer the fix.
3. **`debugf` never reaches `game.log` while the game runs.** `drive.sh start` runs the game with stdout block-buffered, so `game.log` holds only the SDL banner until the game exits, and `stop` deletes it after a clean run. CE-4's live lanes count `Step` calls from `debugf`. Make `drive.sh` run the game line-buffered (for example `stdbuf -oL`, and add `coreutils` to the CI job if it is missing), document it in `tools/live/README.md`, and add a `test-drive.sh` check that a `debugf` line written by the game appears in `game.log` while the game is still running. That check must fail at `ddd835f`.

## After the fix

- Build SDL and STM32 with zero new warnings. Record the `.blit` size, which should shrink or stay the same.
- Run `tools/parity/run.sh --self-test` and `--all`, `tools/live/test-drive.sh`, and `drive.sh smoke` 5 times.
- Run `/deslop` and the no-comments skill as a subagent.
- Small commits with technical-writing messages. Refresh `docs/audit/port-completion.tsv` from `/workspaces/32blit-chuckie-egg/.audit/port-completion.tsv` in your last commit. A plain fast-forward push.
- Comment on #6 with the new head SHA and what changed.
- Wait for CI to go green. Poll review threads at least 10 minutes after green.
- Report: new head SHA, the receipts for each finding (red at `ddd835f`, green at head), the test results, the `.blit` size, CI status, and threads. Save everything under `/tmp/swarm-ce-3/owner-fix-1/`.
