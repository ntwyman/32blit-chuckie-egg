# CE-2 owner brief

You own one PR, CE-2 (GitHub issue #5), in the Chuckie Egg port program. The root agent coordinates the program and owns the stack's topology. You build, open, prove, and babysit this one PR to STACK-READY. You never merge.

## Read first, in full

`<pstack>` is `/home/vscode/.claude/plugins/cache/cursor-plugins/pstack/0.15.32`.

1. `<pstack>/skills/poteto-mode/SKILL.md`, then `<pstack>/docs/harness/claude-code.md`. The adapter maps Cursor names to Claude Code. There are no Cursor cloud agents here. You run locally in the dev container.
2. `/workspaces/32blit-chuckie-egg/AGENTS.md`.
3. `git show origin/main:docs/plans/port-completion.md`. Read the whole plan. Your section is "Add a scripted driver for the SDL build (CE-2)". Also follow "PR mechanics, for every PR" and "Boot recipe, for every live lane". The plan is the source of truth, except where this brief records an operator decision or a measured correction.
4. `<pstack>/skills/poteto-mode/playbooks/autopilot-stack.md` and `<pstack>/skills/poteto-mode/playbooks/autopilot-full.md`. You are an owner under autopilot-full step 2, as autopilot-stack step 1 changes it.
5. `<pstack>/skills/poteto-mode/playbooks/opening-a-pr.md`, `<pstack>/skills/poteto-mode/playbooks/babysit.md`, `<pstack>/skills/poteto-mode/references/bugbot-triage.md`, `<pstack>/skills/technical-writing/SKILL.md`, `<pstack>/skills/unslop/SKILL.md`.

## Operator decisions and corrections

- CE-2's live swarm keeps only lanes 1, 2, and 6. The root runs that swarm. Run those three lanes yourself as self-proof too, plus the plan's "You see" and "Verify, unit" boxes, and the perf probe.
- Measured by the CE-1 owner: the SDL window is 640x480, so Xvfb at the plan's 320x240 shows a black root. `drive.sh` must run Xvfb at 640x480 or larger. Say so in `tools/live/README.md`.
- Measured by the CE-1 owner: the A button is the `z` key. From boot, `z` at "How many players", then `z` at "Ready player", and play starts. `start-one-player.keys` should encode that.
- The SDK in this container is `/opt/32blit-sdk` at `db99cb7fad2ee163bf7251193566bfcf6781da7c`. Pin `SDK_REF` to that SHA, so the pin matches what the container already runs and the operator's later image rebuild changes nothing. The Dockerfile clones with `git clone --depth 1 --branch ${SDK_REF}`, and `--branch` does not take a SHA. Change the clone so a SHA works, for example `git init`, `git fetch --depth 1 origin ${SDK_REF}`, `git checkout FETCH_HEAD`. The container cannot rebuild its own image, so you cannot test the Dockerfile here. Say that in the PR body. The operator rebuilds on the host.
- `Xvfb`, `xdotool`, `import`, `compare`, and `ffmpeg` already exist in this container. Still add them to the Dockerfile if it does not install them, so a fresh image has them.

## Your work

- Branch `ce-2/live-driver` from `origin/ce-1/gpl-relicense` at `b1c3c6ec54cb3d90148c6f16c086332e249c880d`. Work in the worktree you were given, or create one at `/tmp/owner-ce-2`.
- Do every box in the CE-2 section. Hold CE-2's file boundary from the plan's "Hold the file boundaries" list, plus `tools/live/golden/**` and `tools/live/scripts/**`, which the plan's boxes name.
- Generate `tools/live/golden/level1-start.png` from the real game at your head, and make `smoke` deterministic enough to compare with zero differing pixels. If a moving element makes zero impossible at a fixed time, find a frame where it is stable rather than loosening the threshold. Loosening it needs the root's countersign.
- The CI job runs `drive.sh smoke` on Linux. CI does not use the dev image, so the job must install what it needs.
- Build the SDL and STM32 targets in the container before the PR-facing push. Zero new warnings. Never call `docker`.
- Run `/deslop` (the project skill at `.claude/skills/deslop/SKILL.md`) before each commit, and the pstack no-comments skill (`<pstack>/skills/no-comments/SKILL.md`) before you report code-ready.
- Commit messages and the PR body follow technical-writing and unslop. Title in Conventional Commits form, for example `feat(live): add a scripted driver for the SDL build`. The body has `Closes #5`. End each commit message with a `Co-Authored-By:` trailer naming the model you run on, and the PR body with `🤖 Generated with [Claude Code](https://claude.com/claude-code)`.
- Open the PR ready, not draft, with `gh pr create --base ce-1/gpl-relicense`. The `gh` token can now create PRs and comment on issues.

## Rules you must hold

- Push your branch early and after every unit worth keeping. Force-push only your own branch, with `--force-with-lease` pinned to the SHA you last pushed. If you see a push you did not make, stop and report. The root may rebase your branch onto a new CE-1 head. Take that push as your new base and lease.
- Never rebase onto another branch, trunk or CE-1 included. Never retarget, merge, or close a PR, and never arm auto-merge.
- Keep a decision trail at `/workspaces/32blit-chuckie-egg/.audit/ce-2.tsv` with `<pstack>/skills/show-me-your-work/scripts/log.sh`. Log each unit, each fork, and each subagent you spawn (its id, what it does, and when it would count as stuck).
- On a zero-writes order from the root, stop all writes at once and report where you stand.

## Lifecycle and reports

1. Build. Push. Open the PR. Comment on #5 with the link.
2. After deslop and no-comments, log a `code-ready` row with the head SHA in your trail, and comment on #5 with the PR link and that SHA.
3. Self-proof per the boxes above. Save screenshots under `/tmp/swarm-ce-2/owner/`.
4. Babysit CI and review threads per `babysit.md`, in drive mode, until checks are green and every thread is triaged. Poll review threads again at least 10 minutes after CI goes green, because Copilot reviews arrive late.
5. Return a final report to the root. It names the branch, the PR URL, the code-ready SHA, the final head SHA and its intended parent (`ce-1/gpl-relicense` at its SHA), a receipt for each box (command and outcome, or file path), the perf numbers, the screenshot paths, and anything left open. Call it STACK-READY only when every box is checked with its evidence. Run each box literally as the plan words it, and if you substitute a check, say so.
