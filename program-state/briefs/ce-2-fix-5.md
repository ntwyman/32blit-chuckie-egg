# CE-2 fix round 5: Copilot review findings

You take over the CE-2 owner role for one short round. Read `/workspaces/32blit-chuckie-egg/.audit/briefs/ce-2-owner.md`, `ce-2-fix-4.md`, `copilot-review.md`, and `staffing.md` in the same folder. Their rules and report format apply, with these changes:

- Branch `ce-2/live-driver`, PR #16, head `76b68c290ff722de30c504b2735417d724fe59d2`. PR #16 now targets `main`, because CE-1 and the sprite fix have landed. Base your work on `76b68c2`. Do not rebase. Work on a local branch tracking `origin/ce-2/live-driver`, and push with `git push origin HEAD:ce-2/live-driver`.
- Append to `/workspaces/32blit-chuckie-egg/.audit/ce-2.tsv`, starting with a `start` row.
- Use only `LIVE_LANE` 530 to 559 and `LIVE_TEST_LANE_BASE=530`. Never kill a process you did not start.
- Have no background work running when you report.

## Copilot's review at 76b68c2: two findings, both confirmed real by the root

1. **Comment 4370814210, `tools/live/drive.sh:273`.** `cmd_keys` sends `xdotool keydown`, sleeps, then `keyup`, with no trap. If a standalone `drive.sh keys` is interrupted or killed during a hold, the key stays down in the running game and leaks into the next script. `smoke` and `golden` set their own traps (lines 366 and 409) and call `cmd_keys`, so keep their cleanup working. Fix: track the keys currently held, and release them on error, INT, and TERM in `cmd_keys`, without replacing the caller's traps. Add a `test-drive.sh` check that starts a long hold, sends TERM to `drive.sh keys`, and shows the key is released, for example with `xdotool` querying the key state or by watching Henry stop moving. It must fail at `76b68c2`.
2. **Comment 4370814228, `tools/live/test-drive.sh:258`.** `t_numbers_parse_as_decimal` runs `LIVE_LANE=08 drive.sh stop`, which stops lane 8, outside the suite's reserved lanes. A live session on lane 8 would be killed and its logs removed. Fix: check the parsed lane by sourcing the driver, as the next assertions in that test already do, and run nothing against a lane outside the reserved range. Show the check still fails for the old octal bug, for example by running the new check against the round-2 driver at `05102f5`.

## Then

- Run `tools/live/test-drive.sh` (base 530), `test-smoke.sh`, and `drive.sh smoke` 5 times at your head.
- One commit per finding, with technical-writing messages. A plain fast-forward push.
- Reply on both Copilot threads with the fix and the commit SHA, per `copilot-review.md`.
- Request a fresh Copilot review at your new head, per `copilot-review.md`, and wait for it. Triage and reply to any new comments.
- Comment on #5 with the new head SHA and what changed.
- Wait for CI to go green.
- Report: new head SHA, red and green receipts for both findings, test results, CI status, every Copilot comment with its verdict and reply URL, and anything open. Save evidence under `/tmp/swarm-ce-2/owner-fix-5/`.
