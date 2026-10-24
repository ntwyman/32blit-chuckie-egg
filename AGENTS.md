## Agent skills

### Issue tracker

Issues are tracked in GitHub Issues on ntwyman/32blit-chuckie-egg, using the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Triage labels

Uses the five default labels: needs-triage, needs-info, ready-for-agent, ready-for-human, wontfix. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: one root `GLOSSARY.md` plus `docs/adr/`. See `docs/agents/domain.md`.

## Port completion plan

`docs/plans/port-completion.md` is the plan for finishing the port. GitHub issue #3 tracks it, and sub-issues #4 to #12 track its PRs, CE-1 to CE-9, in order.

- Run the plan from the dev container. It needs the SDK in `/opt/32blit-sdk`, and it cannot run Docker.
- `.claude/settings.json` enables the `pstack` and `mattpocock-skills` plugins. Accept the install prompt on the first Claude Code start in the container.
- Start with the plan's **Arm the program** checklist. Execution starts only on the maintainer's explicit go.
- After you edit the plan, run `node "$(ls -d ~/.claude/plugins/cache/cursor-plugins/pstack/* | tail -1)/skills/poteto-mode/scripts/check-plan.mjs" docs/plans/port-completion.md` and fix every line it prints.
