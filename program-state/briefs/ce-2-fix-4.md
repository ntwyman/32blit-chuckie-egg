# CE-2 fix round 4: one finding

You take over the CE-2 owner role for one short round. Read `/workspaces/32blit-chuckie-egg/.audit/briefs/ce-2-owner.md` and `ce-2-fix-3.md` in the same folder. Their rules and report format apply, with these changes:

- Branch `ce-2/live-driver`, PR #16, head `e64ea59a44c13dae9bba609c5f2fc6fc2bbae753`. Base your work on it. Do not rebase. Work on a local branch tracking `origin/ce-2/live-driver`, and push with `git push origin HEAD:ce-2/live-driver`.
- Append to `/workspaces/32blit-chuckie-egg/.audit/ce-2.tsv`, starting with a `start` row.
- Use only `LIVE_LANE` 100 to 129 and `LIVE_TEST_LANE_BASE=100` for your runs. Never kill a process you did not start.
- Have no background work running when you report.

## The single verifier's verdict at e64ea59: ISSUES

Findings 1 to 7 and 9 from round 3 are closed. Finding 8 is half closed. The smoke step's CI condition is fixed. The test-drive artifacts are not.

**The defect.** The self-check `t_failing_checks_leave_artifacts` (`tools/live/test-drive.sh:311`) runs a nested `test-drive.sh` with the same `LIVE_TEST_LANE_BASE`. The nested run's `cleanup` removes `$LIVE/out/lane$lane` for lanes base to base+9 before the outer run's `keep_artifacts` runs, so frames from checks that failed earlier are deleted. In a full run with two checks forced to fail, `tools/live/out/test-drive/` held no frames from either. Run alone with `LIVE_TEST_ONLY`, each check's frames were kept. Evidence: `/tmp/swarm3-ce-2/worker-90/item8-sabotage.diff`, `item8-sabotaged-run.log`, `item8-only-side-by-side.log`.

**The fix.** Make the nested self-check use lanes outside the outer run's range (for example base+10 to base+19) and its own output folder, so it cannot touch the outer run's lanes or artifacts. Change nothing else.

## Prove it

- Apply the verifier's sabotage (two checks forced to fail) in a scratch copy of your head. Run the full `test-drive.sh`, and show that both failed checks' frames and logs land under `tools/live/out/test-drive/`. Show the same sabotage at `e64ea59` loses them.
- Run the unmodified `test-drive.sh` at your head and show every check passes.
- Save logs under `/tmp/swarm-ce-2/owner-fix-4/`.

## After the fix

- One commit with a technical-writing message. A plain fast-forward push.
- Comment on #5 with the new head SHA.
- Wait for CI to go green, including Live smoke. Poll review threads at least 10 minutes after green.
- Report: new head SHA, the sabotage receipts at both SHAs, test-drive results, CI status, and threads.
