# CE-1 owner brief

You own one PR, CE-1 (GitHub issue #4), in the Chuckie Egg port program. The root agent coordinates the program and owns the stack's topology. You build, open, prove, and babysit this one PR to STACK-READY. You never merge.

## Read first, in full

`<pstack>` is `/home/vscode/.claude/plugins/cache/cursor-plugins/pstack/0.15.32`.

1. `<pstack>/skills/poteto-mode/SKILL.md`, then `<pstack>/docs/harness/claude-code.md`. The adapter maps Cursor names to Claude Code. There are no Cursor cloud agents here. You run locally in the dev container.
2. `/workspaces/32blit-chuckie-egg/AGENTS.md`.
3. `git show origin/main:docs/plans/port-completion.md`. Read the whole plan. Your section is "Add the original source, relicense under GPLv3, and credit the original (CE-1)". Also follow "PR mechanics, for every PR" and "Boot recipe, for every live lane". The plan is the source of truth.
4. `<pstack>/skills/poteto-mode/playbooks/autopilot-stack.md` and `<pstack>/skills/poteto-mode/playbooks/autopilot-full.md`. You are an owner under autopilot-full step 2, as autopilot-stack step 1 changes it.
5. `<pstack>/skills/poteto-mode/playbooks/opening-a-pr.md`, `<pstack>/skills/poteto-mode/playbooks/babysit.md`, `<pstack>/skills/poteto-mode/references/bugbot-triage.md`.
6. `<pstack>/skills/technical-writing/SKILL.md` and `<pstack>/skills/unslop/SKILL.md`, because CE-1 is mostly prose: README credits, the third-party README, license headers, the PR body.

## Operator decisions that change the plan

- CE-1's live swarm keeps only lanes 2, 5, and 9. The root runs that swarm, not you. Run those three lanes yourself as self-proof too, per the boot recipe. CE-2 has not landed, so start the game by hand under `Xvfb` and take screenshots with `import -window root`.
- CE-9 stays in the program. It does not affect you.

## Your work

- Branch `ce-1/gpl-relicense` from `origin/main` (currently `4927e4c`). Work in the worktree you were given, or create one at `/tmp/owner-ce-1` with `git worktree add`.
- Do every box in the CE-1 section: Files, Build, You see, Verify unit, Verify perf. Run the perf probe yourself (STM32 `.blit` size at trunk and head, interleaved trunk, head, trunk, head) and keep the numbers.
- Hold the file boundary in the plan's "Hold the file boundaries" list for CE-1. Touch nothing else.
- Never edit `third_party/pbrook-chuckie-egg/` contents after the import. It must equal upstream commit `e18004643193a8ff9434cf77b15a13219f6d745e` minus `models/blender/`.
- Build the SDL and STM32 targets in the container before the PR-facing push. Zero new warnings is the check. Never call `docker`.
- Run `/deslop` (the project skill at `.claude/skills/deslop/SKILL.md`) before each commit, and the pstack no-comments skill (`<pstack>/skills/no-comments/SKILL.md`) before you report code-ready.
- Commit messages and the PR body follow technical-writing and unslop. Title in Conventional Commits form, for example `chore(license): relicense under GPLv3 and import the original source`. The body contains `Closes #4`. End each commit message with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`, and the PR body with `🤖 Generated with [Claude Code](https://claude.com/claude-code)`.
- Open the PR ready, not draft, with `gh pr create --base main`.

## Rules you must hold

- Push your branch early and after every unit worth keeping, so a replacement can find your work. Force-push only your own branch, with `--force-with-lease` pinned to the SHA you last pushed. If you see a push you did not make, stop and report.
- Never rebase onto another branch, trunk included. Never retarget, merge, or close a PR, and never arm auto-merge. The root owns that.
- Keep a decision trail at `/workspaces/32blit-chuckie-egg/.audit/ce-1.tsv` with `<pstack>/skills/show-me-your-work/scripts/log.sh`. Log each unit, each fork, and each subagent you spawn (its id, what it does, and when it would count as stuck).
- On a zero-writes order from the root, stop all writes at once and report where you stand.

## The gh token is restricted

The `gh` token currently cannot comment on issues, and it may not be able to create PRs either. Pushing over SSH works. If `gh pr create` or `gh issue comment` fails with a permission error, do not work around it. Log it, keep the pushed branch, finish all self-proof, and write the PR title and body to `/workspaces/32blit-chuckie-egg/.audit/ce-1-pr-body.md` so the root can open the PR once the operator fixes the token. Then report `BLOCKED: gh token` for those steps only.

## Lifecycle and reports

1. Build. Push. Open the PR, or write the body file if the token blocks you.
2. After deslop and no-comments, log a `code-ready` row with the head SHA in your trail, and comment on #4 with the PR link if the token allows.
3. Self-proof: the You see boxes, the unit check, the perf probe, and lanes 2, 5, and 9. Save screenshots under `/tmp/swarm-ce-1/owner/`.
4. Babysit CI and review threads per `babysit.md`, in drive mode, until checks are green and every thread is triaged. Copilot or Bugbot comments get triaged per `bugbot-triage.md`. Lane 10's CI watch is part of this.
5. Return a final report to the root. It names the branch, the PR URL or `BLOCKED: gh token`, the code-ready SHA, the final head SHA and its intended parent (`main`), a receipt for each box you checked (command and outcome, or file path), the perf numbers, the screenshot paths, and anything left open. Call it STACK-READY only when every box is checked with its evidence.
