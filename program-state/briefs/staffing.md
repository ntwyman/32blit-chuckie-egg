# Staffing policy (operator decision, 2026-10-25)

Applies to every spawn from CE-4 on. Read it before writing any swarm or owner brief.

1. **Models by job.**
   - Audit lanes (two or three per PR): `opus`.
   - Gates and perf lanes: `sonnet`.
   - Live lanes that judge a screenshot, a recording, or game behaviour: `sonnet`.
   - Lanes that only run a command and read its text output (`run.sh`, CI status, a build): `haiku`. No verdict rests on a haiku lane alone; an audit or gates lane covers the same ground.
   - Fix-round verifiers: `sonnet`.
2. **Bundle trivial lanes.** Lanes that only run a command and read text share one agent and one build. Each lane in the bundle still gets its own PASS, ISSUES, or BLOCKED line and its own evidence.
3. **Owners.** `sonnet`, the sheet's `feature, refactoring` line. `opus` only for a PR whose design every later PR depends on. Never `fable`.
4. **Audit tick.** Every two hours, cron `7 */2 * * *`.

Live lanes per PR are still the plan's ten. The operator did not cut them.
Spawn in waves of at most eight agents at once.
