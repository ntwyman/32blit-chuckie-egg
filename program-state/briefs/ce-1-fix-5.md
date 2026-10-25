# CE-1 fix round 5

You take over the CE-1 owner role for one more fix round. Read `/workspaces/32blit-chuckie-egg/.audit/briefs/ce-1-owner.md` and `ce-1-fix-4.md` in the same folder. Their rules and report format still apply, with these changes:

- Branch `ce-1/gpl-relicense`, PR #15, head `b300d22b82247918d7f55d379b5f4e2d69963cbb`. Base your work on that head. Do not rebase. Work on a local branch tracking `origin/ce-1/gpl-relicense`, and push with `git push origin HEAD:ce-1/gpl-relicense`.
- Append to `/workspaces/32blit-chuckie-egg/.audit/ce-1.tsv`, starting with a `start` row.
- Do not touch any `ce-2/*` branch. When you send your final report, have no background work still running.

## The single verifier's verdict at b300d22: ISSUES

**D3.** The check matches the required text anywhere, so other SPDX IDs that start with it pass: `GPL-3.0-only-ish`, `GPL-3.0-onlyX`, `GPL-3.0-only OR MIT`. Evidence: `/tmp/swarm-ce-1/worker-17/tests-b300d22.log`.

## The fix to make

Match the whole header line literally, which is what every source file carries:

`grep -qxF -- '// SPDX-License-Identifier: GPL-3.0-only' "$file"`

`-x` requires the whole line to equal that text, `-F` keeps it literal, and `--` keeps dash-led names safe. Change only that line. First confirm that every tracked `.cpp` and `.hpp` outside `third_party/` has exactly that line, with no trailing space or carriage return. If one does not, report it rather than loosening the pattern.

## Prove it

- Copy `/tmp/swarm-ce-1/worker-17/w17-tests.sh` to `/tmp/swarm-ce-1/owner-fix-5/` and point it at your own worktree and scratch folder. Change only what the new rule changes the expected results of:
  - The three D3 cases must fail.
  - A file whose SPDX text sits inside a `/* ... */` comment, or in a line with anything before `//`, now fails. That is intended, because the plan prescribes the `//` header line.
- Run the copy against b300d22 (the three D3 cases red) and against your head (all green). Save both logs.
- Build SDL and STM32 with zero new warnings. Run `tools/check-license.sh` on the real tree and confirm it exits 0.

## After the fix

- One fix commit with a technical-writing message. A plain fast-forward push.
- Comment on #4 with the new head SHA and what changed.
- Wait for CI on the new head to go green. Poll review threads at least 10 minutes after green, and triage anything new.
- Report to the root: the new head SHA, both test logs, CI status, threads triaged, and anything left open.
