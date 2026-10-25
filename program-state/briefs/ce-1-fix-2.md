# CE-1 fix round 2

You take over the CE-1 owner role for one more fix round. Read `/workspaces/32blit-chuckie-egg/.audit/briefs/ce-1-owner.md` and `/workspaces/32blit-chuckie-egg/.audit/briefs/ce-1-fix-1.md` in full. Their reading list, rules, and report format still apply, with these changes:

- The `gh` token works for PRs and issue comments.
- Branch `ce-1/gpl-relicense`, PR #15, head `e33e5b9c666b113432d4f6d5bfb8eb2d06943708`. Base your work on that head. Do not rebase. The branch is checked out in other agent worktrees, so work on a local branch tracking `origin/ce-1/gpl-relicense` and push with `git push origin HEAD:ce-1/gpl-relicense`.
- Append to `/workspaces/32blit-chuckie-egg/.audit/ce-1.tsv`, starting with a `start` row.
- Do not touch any `ce-2/*` branch.

## The single verifier's verdict at e33e5b9: ISSUES

Both round 1 findings are closed. The round 1 brief's wording caused one new defect. Fix it and nothing else.

**The `./build*` prune is too wide.** `-path './build*'` also prunes root files and folders whose names only start with "build". An unlicensed `./buildinfo.cpp` or `./builders/x.cpp` exits 0 at e33e5b9, and `./buildinfo.cpp` failed correctly at b1c3c6e. Evidence: `/tmp/swarm-ce-1/worker-14/run-tests.sh`, case `build-prefix-nonbuild-paths`.

**The fix to make.** Stop pruning by name. List the files to check with git, so the script checks exactly the tracked source files outside `third_party/`. For example, read NUL-separated output from `git ls-files -z -- '*.cpp' '*.hpp' ':!:third_party/**'`. Build folders, `.git`, and agent worktrees under `.claude/` are not tracked, so they drop out with no pattern. Keep the `cd "$(dirname "$0")/.."` line and the `LICENSE` comparison. The CI step runs inside a full checkout, so `git ls-files` works there. Confirm that from the workflow's checkout step.

## Prove it

In scratch git repos made from the head (for example `git worktree add` or `git clone` into your scratchpad, not `git archive`, because the script now needs `.git`), `git add` each test file, then run the script:

- Red at e33e5b9, green after the fix: tracked unlicensed `buildinfo.cpp` at the root and `builders/x.cpp` must fail and be named.
- Tracked unlicensed `src/new.cpp`, `src/new.hpp`, and `tools/parity/x.cpp` fail and are named.
- A tracked file with a space in its name and path fails and is named correctly. The same file with the SPDX line passes.
- Root `game.cpp` without its SPDX line fails. A changed `LICENSE` fails.
- A tracked unlicensed file under `third_party/` is ignored. Untracked unlicensed files under `build.sdl/` and `.claude/worktrees/` are ignored.
- The clean tree exits 0, run from the repo root and from `/` by absolute path.

Save the proof script and its logs under `/tmp/swarm-ce-1/owner-fix-2/`.

## After the fix

- Build SDL and STM32 with zero new warnings.
- Run `/deslop` (`.claude/skills/deslop/SKILL.md`) and the no-comments skill (`<pstack>/skills/no-comments/SKILL.md`) on your diff, even though it is small. Record their outcome.
- One fix commit with a technical-writing message. A plain fast-forward push.
- Comment on #4 with the new head SHA and what changed.
- Wait for CI on the new head to go green, including the Linux "Check licenses" step. Poll review threads at least 10 minutes after green, and triage anything new.
- Report to the root: the new head SHA, the red and green receipts, CI status, threads triaged, the deslop and no-comments outcomes, and anything left open.
