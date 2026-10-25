# Resume note: Chuckie Egg port completion program

Paused 2026-10-25 around 16:40 UTC so the operator can move to another machine. This is a pause, not a final report.

## What the program is

`docs/plans/port-completion.md` on `main`, run under pstack's `autopilot-stack` playbook (`<pstack>/skills/poteto-mode/playbooks/autopilot-stack.md`, pstack 0.15.32 from `cursor-plugins`). One owner subagent builds each PR. The root (the coordinating Claude session) verifies each PR with an independent swarm, owns the stack's topology, and never merges. The operator lands PRs bottom-up with merge commits (not squash), and the root retargets the next PR to `main` after each merge.

## Where everything is

- **Decision trail:** `port-completion.tsv` (root) and `ce-1.tsv`, `ce-2.tsv`, `ce-3.tsv`, `ce-4.tsv`, `sprite-fix.tsv` (owners). Read the last 40 rows of `port-completion.tsv` first.
- **Briefs:** `briefs/`. Every owner and swarm brief, plus two standing rules every new brief must follow:
  - `briefs/staffing.md`: the operator's cost cuts (audits on opus; gates, perf, judging lanes, and fix verifiers on sonnet; text-only lanes on haiku, bundled; owners on sonnet, never fable; audit tick every two hours; waves of at most eight agents).
  - `briefs/copilot-review.md`: every PR gets a Copilot review at its code-ready head, and the owner replies on every comment.
- **Hand-off patches:** `handoff/`. Superseded by the pushed `f1794c5`; kept for the record.

The briefs name absolute paths under `/workspaces/32blit-chuckie-egg/.audit/` and `/tmp/swarm-*`. Restore this folder to `/workspaces/32blit-chuckie-egg/.audit/` on the new machine (see below). Evidence under `/tmp/swarm-*` did not move; the trail rows name what it showed.

## State of the stack

| PR | What | Head | State |
|---|---|---|---|
| #15 | CE-1, GPLv3 and the original source | 1ff20c3 | merged (574182f) |
| #18 | sprite-sheet fix, issue #17 (not in the plan) | 60f8f6e | merged (35b8ebd) |
| #16 | CE-2, scripted SDL driver | **f1794c5** | **on hold**: Copilot fix round 5 in progress, full runs failing (below) |
| #20 | CE-3, trace diff | 3841f66 | verified CLEAN; base `ce-2/live-driver` |
| #22 | CE-4, 30 ms frame clock and idle parity | 07b9e5e | code-ready; owner self-proof reconfirmed; not yet swarm-verified |

Open issues for the operator's triage: #19 (timer digits 2 px left) and #21 (port draws walls under ladders). Both are visual only and change CE-2's golden image when fixed. The root's recommendation is one small PR after CE-3.

Ruleset "Copilot review" (id 25821171) requests a Copilot review on every new PR, all branches. The `gh` token now has Administration write.

## Next steps, in order

1. **CE-2 round 5 (PR #16).** Spawn a fresh sonnet owner with `briefs/ce-2-fix-5.md` and this context: head `f1794c5` already holds both fixes (4440573 keys release, b1d2d54 lane parse) with red/green receipts, plus an empty `wip:` commit to drop or keep. The owner's full runs at head failed: `test-drive.sh` (base 530) failed items 7 and 9 (two lanes write to separate folders; failed smoke leaves frame and game.log; failed golden keeps logs), all five `drive.sh smoke` runs on lane 545 failed with `drive.sh line 104: /tmp/chuckie-live-644/failed: No such file or directory`, and `test-smoke.sh` ran on its default lane 23 by mistake (use `LIVE_TEST_LANE`). First step: run the same suites at `76b68c2` to see whether the failures pre-exist; if not, bisect to the trap change in 4440573. Then fix, push, reply on Copilot threads 4370814210 and 4370814228, request a fresh Copilot review, comment on #5. Then a single sonnet verifier.
2. **Rebase CE-3 (#20) onto the new CE-2 head.** CE-3 also changes `tools/live/test-drive.sh`, so expect a conflict there. Check patch-id; CE-3's verdict carries only if its patch is unchanged, else a single verifier.
3. **CE-4 (#22).** Its owner paused at `07b9e5e` with these steps left, in order: view `/tmp/swarm-ce-4/owner3/g/diff.png` against the old and new golden (808 pixels differ, probably start positions; that will not exist on a new machine, so regenerate the comparison from `git show 7d44ca3:tools/live/golden/level1-start.png` and `07b9e5e`), wait for Copilot's review at 07b9e5e and reply to its comments, poll threads 10 minutes after green, confirm `docs/media/ce-4-review-{walk,cadence}.png` and `ce-4-review.mp4` exist, then report. After CE-3 is rebased, rebase CE-4 onto it. Then CE-4's full swarm per `briefs/staffing.md`, then post its screenshots and video to the operator for the review gate.
4. **CE-5 onward**, per the plan. The CE-6 brief must cover upstream restarting after game over with the stale bonus of the level reached (trail row "note for CE-6"). The CE-7 brief must cite `chuckie.c:1155-1174` for level completion (CE-3 deleted the commented-out C block).

## Restoring on the new machine

1. In the dev container, `cd /workspaces/32blit-chuckie-egg && git fetch origin && git checkout main && git pull`.
2. Copy this folder back: `git show origin/program/state:program-state/RESUME.md` confirms it exists; then `git archive origin/program/state program-state | tar -x` and `mv program-state .audit`. Add `.audit/` to `.git/info/exclude` so it is never committed by accident.
3. Check `claude plugin list` shows `pstack@cursor-plugins` 0.15.32 enabled and `pstack@pstack-claude` disabled, and `gh auth status` is logged in with the PAT.
4. Start Claude Code and run `/pstack:poteto-mode` with "resume the port completion program from .audit/RESUME.md". The root rearms the two-hourly audit tick with the plan's tick prompt and starts step 1.

## Gotchas

- Owners must use only their own `LIVE_LANE` range and never kill processes they did not start. Earlier lanes killed each other's displays.
- Launching more than about eight agents at once hit the session limit and lost a whole swarm.
- When an agent stops on a usage limit, check its worktree for unpushed commits or edits before replacing it, and hand them over as a patch or a fetch.
- Classifier outages make Bash fail transiently; read files directly and retry later.
