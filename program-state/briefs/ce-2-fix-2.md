# CE-2 fix round 2: regenerate the golden and restore strict checks

You take over the CE-2 owner role for one short round. Read `/workspaces/32blit-chuckie-egg/.audit/briefs/ce-2-owner.md` and `ce-2-fix-1.md` in the same folder. Their rules and report format apply, with these changes:

- Branch `ce-2/live-driver`, PR #16, head `a7d012c7b8b15d33330bc9c4fbfe188e5c78ecd4`. The root rebased it onto the sprite-sheet fix (PR #18, branch `fix/sprite-sheet-bounds` at `60f8f6e`), which removes the per-process garbage pixel under TIME and widens the TIME label to 34 px. PR #16 now targets `fix/sprite-sheet-bounds`. Base your work on `a7d012c`. Do not rebase. Work on a local branch tracking `origin/ce-2/live-driver`, and push with `git push origin HEAD:ce-2/live-driver`.
- Append to `/workspaces/32blit-chuckie-egg/.audit/ce-2.tsv`, starting with a `start` row.
- Use only `LIVE_LANE` values 40 to 49 for your own runs, and only Xvfb displays those lanes map to. Never kill an Xvfb, game, or ffmpeg process you did not start.
- Have no background work running when you report.

## Work

1. **Regenerate the golden image** with `tools/live/drive.sh golden tools/live/golden/level1-start.png` at your head. Look at it: level 1, TIME 900 with the full-width label, Henry unmoved, nothing under the TIME label.
2. **Prove smoke is deterministic.** Run `drive.sh smoke` 20 times at your head. Every run must pass on its first attempt with 0 differing pixels. Report every run's result and any retry with its printed reason.
3. **Restore `test-smoke.sh` to zero tolerance.** It allows 8 differing pixels for the selected frame. Set it to 0 and rerun it.
4. **Explain and restore the side-by-side lanes check.** Commit `c24c364` (now `a7d012c`) dropped the requirement that neither of two parallel smoke lanes prints "run failed", after one CI run failed it with no logged cause. Find the cause:
   - Pull the failing job's log for the run on `b4693ee` (`gh run list --branch ce-2/live-driver`, then `gh run view --log`), and read what the driver printed.
   - Run the parallel lanes check 20 times locally, and in CI if you can make the job print enough to tell.
   - If the cause is a real interference between lanes (shared display, shared file, port, or recorder), fix the driver, and restore the strict check.
   - If the cause is the CI runner being slow (for example the window wait is too short under two lanes), fix that with a measured wait, and restore the strict check.
   - Restore the strict check either way, unless you can prove the failure comes from outside the driver. If so, say exactly what and show it. The root decides whether to accept that.
5. Rerun `tools/live/test-drive.sh` and `test-smoke.sh` at your head and save the logs.

## After the work

- Build SDL and STM32 with zero new warnings. The `.blit` size must equal the parent's (`60f8f6e`).
- Run `/deslop` and the pstack no-comments skill (`<pstack>/skills/no-comments/SKILL.md`, as a subagent). Record their outcomes.
- Small commits with technical-writing messages. A plain fast-forward push.
- Comment on #5 with the new head SHA and what changed.
- Wait for CI to go green, including Live smoke and the driver tests. Poll review threads at least 10 minutes after green.
- Report: new head SHA, the 20-run smoke receipt, the cause of the CI failure with evidence, test logs, CI status, threads, and anything open. Save everything under `/tmp/swarm-ce-2/owner-fix-2/`.
