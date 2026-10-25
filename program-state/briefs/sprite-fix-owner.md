# Sprite-sheet fix owner brief (issue #17)

You own one small PR in the Chuckie Egg port program: fix the TIME sprite reading past the end of the sprite sheet. It is a new link in the stack, between CE-1 (PR #15, branch `ce-1/gpl-relicense`) and CE-2 (PR #16). The root agent owns the stack's topology. You build, open, prove, and babysit this PR to STACK-READY. You never merge.

## Read first, in full

`<pstack>` is `/home/vscode/.claude/plugins/cache/cursor-plugins/pstack/0.15.32`.

1. `<pstack>/skills/poteto-mode/SKILL.md`, then `<pstack>/docs/harness/claude-code.md`.
2. `/workspaces/32blit-chuckie-egg/AGENTS.md`.
3. The plan, `git show origin/main:docs/plans/port-completion.md`, for "PR mechanics, for every PR" and the program's rules. This PR is not in the plan. The root added it after an audit found the bug.
4. `<pstack>/skills/poteto-mode/playbooks/autopilot-stack.md`, `autopilot-full.md` (you are an owner under its step 2), `opening-a-pr.md`, `babysit.md`, `../references/bugbot-triage.md`, and `<pstack>/skills/technical-writing/SKILL.md`.
5. Issue #17: `gh issue view 17 -R ntwyman/32blit-chuckie-egg`.
6. The audit that found it: the CE-2 smoke-gate audit's frames and logs in `/tmp/swarm-ce-2/worker-28/` (see `frames/`, `miss/`, `20runs.log`).

## The bug

`sprites.cpp:20` is `SpriteTime = Sprite(0,14,4,2)`, covering sheet rows 112 to 127. `assets/sheet.png` is 88x121, so its last row is 120. `game.cpp:214` draws `SpriteTime` at y=12, so screen row 21 reads sheet row 121, past the image. Those pixels are heap garbage that differs per process.

## Your work

- Branch `fix/sprite-sheet-bounds` from `origin/ce-1/gpl-relicense` at `1ff20c342e9390459e4519a7099b6b05cae0bd2d`.
- Find out what the TIME label should look like. Look at the sheet rows 112 to 120, how the other HUD sprites are sized, how `assets.yml` turns `sheet.png` into `asset_sprites`, and Paul Brook's original in `third_party/pbrook-chuckie-egg/` (its sprite data and how it draws the TIME label). Then pick the smallest fix that draws the right label and never reads past the sheet: size the sprite to the rows that exist, or give the sheet the rows the sprite expects. Say in the PR why you chose it.
- Touch only `sprites.cpp`, `sprites.hpp`, `game.cpp` (only if the draw call must change), `assets/sheet.png`, and `assets.yml`. Keep the SPDX header on any source file you touch, and run `tools/check-license.sh`.
- Prove it with the real game, not by reasoning. CE-2's driver is not on your branch, so drive the SDL build by hand under `Xvfb :<display> -screen 0 640x480x24`, pressing `z` at "How many players" and `z` at "Ready player". Take the first level-1 frame in 20 separate game processes at your head, and show all 20 are pixel-identical (`compare -metric AE` 0 against each other). Do the same at `1ff20c3` and show they are not, so the red is real. Save a crop of the HUD's TIME area before and after under `/tmp/sprite-fix/owner/`, and look at it: the label must read correctly.
- Build SDL and STM32 with zero new warnings, and record the `.blit` size at the parent and at your head.
- Run `/deslop` (`.claude/skills/deslop/SKILL.md`) and the no-comments skill (`<pstack>/skills/no-comments/SKILL.md`).
- Title in Conventional Commits form, for example `fix(sprites): stop the TIME label reading past the sprite sheet`. The body has `Closes #17`. End commits with a `Co-Authored-By:` trailer naming your model, and the PR body with `🤖 Generated with [Claude Code](https://claude.com/claude-code)`.
- Open the PR ready with `gh pr create --base ce-1/gpl-relicense`.

## Rules

- Push early and after each unit. Force-push only your own branch, with `--force-with-lease` pinned to your last push. Never rebase onto another branch. Never retarget, merge, or close a PR.
- Keep a decision trail at `/workspaces/32blit-chuckie-egg/.audit/sprite-fix.tsv` with `<pstack>/skills/show-me-your-work/scripts/log.sh`.
- On a zero-writes order from the root, stop all writes and report.
- Have no background work running when you report.

## Lifecycle and report

1. Build, push, open the PR, comment on #17 with the link.
2. After deslop and no-comments, log a `code-ready` row with the SHA, and comment on #17.
3. Self-proof as above.
4. Babysit CI and review threads until green and triaged. Poll threads at least 10 minutes after green.
5. Report: branch, PR URL, code-ready SHA, final head SHA and parent, why this fix, the 20-process receipts at parent and head, the HUD crops, the `.blit` sizes, CI status, and anything open.
