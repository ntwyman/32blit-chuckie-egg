# CE-1 fix round 1

You take over the CE-1 owner role for one fix round. First read `/workspaces/32blit-chuckie-egg/.audit/briefs/ce-1-owner.md` in full. Its reading list, rules, and report format all still apply, with these changes:

- The `gh` token now works for PRs and issue comments. Ignore the brief's section on the restricted token.
- The PR exists: https://github.com/ntwyman/32blit-chuckie-egg/pull/15, branch `ce-1/gpl-relicense`, head `b1c3c6ec54cb3d90148c6f16c086332e249c880d`. Base your work on that head. Your force-with-lease SHA is that head. Do not rebase.
- The prior owner's trail is `/workspaces/32blit-chuckie-egg/.audit/ce-1.tsv`. Append to it. Your first row has phase `start` per the show-me-your-work skill.
- The CE-2 owner is building on `b1c3c6e` right now. Do not touch the `ce-2/*` branch. The root rebases it after your fix.

## The root's swarm verdict at b1c3c6e: ISSUES

Six of seven lanes passed. Fix exactly these two findings and nothing else.

1. **`tools/check-license.sh` skips subfolders.** Line 13 uses `find . -maxdepth 1`, so a `*.cpp` or `*.hpp` file in a subfolder is never checked. The plan says the script fails when "any" such file lacks the SPDX line, and later PRs add `tools/parity/port_driver.cpp` and `tools/parity/clock_test.cpp`. Proof: in a scratch copy, `mkdir src; echo 'int x;' > src/new.cpp` and the script exits 0. Fix: search recursively, and prune `./third_party`, `./.git`, and build folders (`./build*`). Agent worktrees can live under `./.claude/worktrees/`, so prune `./.claude` too.
   - Prove it red first. At `b1c3c6e`, in a scratch copy, a subfolder `.cpp` and a subfolder `.hpp` without the SPDX line must make the script exit non-zero and name both files. Show it exits 0 before the fix and non-zero after.
   - Prove the existing behaviour holds. The clean tree exits 0. A missing SPDX line in root `game.cpp` still fails. An unlicensed file under `third_party/` and one under a `build.sdl/` folder are still ignored. A changed `LICENSE` still fails.
   - Run the script from the repo root and from `/` by absolute path.
2. **The packaged `README.md` has a broken link.** `README.md:16` links to `third_party/pbrook-chuckie-egg/` with a relative path. `cpack` ships `README.md` without that folder, so the link is dead inside the release archive. Change that link to the absolute GitHub URL of the folder on `main`, `https://github.com/ntwyman/32blit-chuckie-egg/tree/main/third_party/pbrook-chuckie-egg`. Leave the rest of the README alone.

## After the fix

- Build SDL and STM32 with zero new warnings. Run `tools/check-license.sh`.
- Run `/deslop` and the no-comments skill on your diff. Commit one fix commit with a technical-writing message. Push with `--force-with-lease=ce-1/gpl-relicense:b1c3c6ec54cb3d90148c6f16c086332e249c880d` only if a plain push is rejected. A plain fast-forward push should work.
- Comment on #4 with the new head SHA and what changed.
- Wait for CI on the new head to go green. Poll review threads again at least 10 minutes after CI is green and triage anything new per `bugbot-triage.md`.
- Report to the root: the new head SHA, the red and green receipts for finding 1, the diff for finding 2, CI status, threads triaged, and anything left open.
