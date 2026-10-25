# CE-1 fix round 3

You take over the CE-1 owner role for one more fix round. Read `/workspaces/32blit-chuckie-egg/.audit/briefs/ce-1-owner.md`, `ce-1-fix-1.md`, and `ce-1-fix-2.md` in the same folder. Their reading list, rules, and report format still apply, with these changes:

- Branch `ce-1/gpl-relicense`, PR #15, head `f908c606d99f44e11a346963d1e909d33006933a`. Base your work on that head. Do not rebase. Work on a local branch tracking `origin/ce-1/gpl-relicense`, and push with `git push origin HEAD:ce-1/gpl-relicense`.
- Append to `/workspaces/32blit-chuckie-egg/.audit/ce-1.tsv`, starting with a `start` row.
- Do not touch any `ce-2/*` branch.
- When you send your final report, have no background work still running.

## The single verifier's verdict at f908c60: ISSUES

Every earlier case passes. One defect remains. Fix it and nothing else.

**The script passes having checked nothing when git fails.** `git ls-files` runs inside `< <(...)`, so `set -euo pipefail` never sees its exit status. Proof from `/tmp/swarm-ce-1/worker-15/test.sh`:
- In a folder with no `.git` and an unlicensed `bad.cpp`, the script prints git's "not a git repository" error and exits 0. At e33e5b9 it exited 1.
- With a fake `git` on `PATH` that exits 128, and `game.cpp` missing its SPDX line, the script exits 0 with no output.

**The fix to make.** Add both guards:
1. A failing `git ls-files` fails the script. Run it as its own command whose status `set -e` sees, for example into a temp file or with `mapfile -d '' -t files < <(...)` followed by a check of that command's status. Pick whichever reads simplest.
2. The script fails with a clear message when it found zero source files to check. This repo always has tracked `.cpp` files, so zero means the listing went wrong.

Keep the rest: `git ls-files -z -- '*.cpp' '*.hpp' ':!:third_party/**'`, the `cd` line, and the `LICENSE` comparison.

## Prove it

Write the proof script under `/tmp/swarm-ce-1/owner-fix-3/`, and run every case against f908c60 (old) and your head (new).
- Red at f908c60, green after: no `.git` with an unlicensed `bad.cpp` fails. A fake `git` that exits 128 fails. A fake `git` that exits 0 and prints nothing fails with the zero-files message.
- Every case from `/tmp/swarm-ce-1/worker-15/test.sh` still gives the same result at your head. Rerun that script against your head, and include its log.

## After the fix

- Build SDL and STM32 with zero new warnings.
- Run `/deslop` and the no-comments skill on your diff. Record their outcome.
- One fix commit with a technical-writing message. A plain fast-forward push.
- Comment on #4 with the new head SHA and what changed.
- Wait for CI on the new head to go green. Poll review threads at least 10 minutes after green, and triage anything new.
- Report to the root: the new head SHA, the red and green receipts, CI status, threads triaged, the deslop and no-comments outcomes, and anything left open.
