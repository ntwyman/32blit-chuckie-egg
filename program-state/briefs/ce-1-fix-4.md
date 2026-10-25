# CE-1 fix round 4

You take over the CE-1 owner role for one more fix round. Read `/workspaces/32blit-chuckie-egg/.audit/briefs/ce-1-owner.md` and `ce-1-fix-3.md` in the same folder. Their rules and report format still apply, with these changes:

- Branch `ce-1/gpl-relicense`, PR #15, head `7c97af169aa2d0c88536bd7501daf8daeaf65c22`. Base your work on that head. Do not rebase. Work on a local branch tracking `origin/ce-1/gpl-relicense`, and push with `git push origin HEAD:ce-1/gpl-relicense`.
- Append to `/workspaces/32blit-chuckie-egg/.audit/ce-1.tsv`, starting with a `start` row.
- Do not touch any `ce-2/*` branch. When you send your final report, have no background work still running.

## The single verifier's verdict at 7c97af1: ISSUES

Every earlier finding is closed. The verifier proved two defects in the `grep` line of `tools/check-license.sh`, present since b1c3c6e. Fix both with one change, and change nothing else.

- **D1.** `grep -q 'SPDX-License-Identifier: GPL-3.0-only' "$file"` has no `--`, so a file named `-x.cpp` is read as options. A licensed `-x.cpp` gets reported as unlicensed. Evidence: `/tmp/swarm-ce-1/worker-16/extra-dashname.log`.
- **D2.** The pattern is a regex, so its `.` matches any character. A file with `GPL-3X0-only` passes. Evidence: `/tmp/swarm-ce-1/worker-16/extra-regexdot.log`.

**The change:** `grep -qF -- 'SPDX-License-Identifier: GPL-3.0-only' "$file"`.

## Prove it

- Add both cases to a copy of the verifier's test script, `/tmp/swarm-ce-1/worker-16/w16-tests.sh`, and save the copy under `/tmp/swarm-ce-1/owner-fix-4/`. A licensed `-x.cpp` passes and an unlicensed one fails and is named. A `GPL-3X0-only` file fails. Run the copy against 7c97af1, where both new cases are red, and against your head, where all cases pass. Save both logs.
- Build SDL and STM32 with zero new warnings.

## After the fix

- One fix commit with a technical-writing message. A plain fast-forward push.
- Comment on #4 with the new head SHA and what changed.
- Wait for CI on the new head to go green. Poll review threads at least 10 minutes after green, and triage anything new.
- Report to the root: the new head SHA, both test logs, CI status, threads triaged, and anything left open.
