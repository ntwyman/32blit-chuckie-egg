# Sprite-sheet fix, round 2

You take over the sprite-fix owner role (issue #17, PR #18) for one fix round. Read `/workspaces/32blit-chuckie-egg/.audit/briefs/sprite-fix-owner.md` in full. Its rules and report format apply, with these changes:

- Branch `fix/sprite-sheet-bounds`, head `20ba124a7651f4a04d95590c6af836a477228dbc`. Base your work on that head. Do not rebase. Work on a local branch tracking `origin/fix/sprite-sheet-bounds`, and push with `git push origin HEAD:fix/sprite-sheet-bounds`.
- Append to `/workspaces/32blit-chuckie-egg/.audit/sprite-fix.tsv`, starting with a `start` row.
- Use your own Xvfb display numbers between 140 and 149. Never kill an Xvfb or game process you did not start.
- Have no background work running when you report.

## The root's swarm verdict at 20ba124: all five lanes PASS

The padding fix is verified. The blast-radius audit also found an older defect in the same sprite, which goes in this PR.

**The TIME label is drawn 2 pixels too narrow.** Upstream `SPRITE_TIME` (`third_party/pbrook-chuckie-egg/spritedata.c:186-189`) is 40 px wide, and its filled HUD block covers columns 0 to 33. The port's `SpriteTime = Sprite(0,14,4,2)` (`sprites.cpp:20`) is 4 tiles, 32 px, so label columns 32 and 33 never draw, though the sheet holds them. Evidence: `/tmp/swarm-sprite/worker-34/audit.txt`. This was found by reading the code and sheet, not from a frame, so confirm it first.

## The fix

1. Capture the first level-1 frame at 20ba124 and crop the TIME block. Confirm columns 32 and 33 of the label are black where upstream shows HUD colour. Render upstream's `SPRITE_TIME` from `spritedata.c` the way `raster_4bit.c` draws it (the audit's decoder is at `/tmp/swarm-sprite/worker-34/scripts/audit.py`), and put the two side by side.
2. Widen the sprite to `Sprite(0,14,5,2)`, which reads sheet columns 0 to 39, inside the 88-wide sheet. Check that the wider draw does not cover anything drawn after it: the timer digits at `game.cpp:215` and anything else in that HUD row. If it does, report it instead of changing draw order.
3. Show the TIME block now matches upstream's rendering pixel for pixel (scaled), and the rest of the HUD is unchanged.
4. Show the first level-1 frame is still identical across 10 separate processes at your head.

Keep the SPDX header in `sprites.cpp`. Run `tools/check-license.sh`. Build SDL and STM32 with zero new warnings and record the `.blit` size. Save crops and logs under `/tmp/sprite-fix/owner-2/`.

## After the fix

- One commit with a technical-writing message. A plain fast-forward push. Update the PR body to mention the width fix.
- Comment on #17 with the new head SHA and what changed.
- Wait for CI to go green. Poll review threads at least 10 minutes after green.
- Report: new head SHA, the before, after, and upstream crops, the 10-process receipt, the `.blit` size, CI status, threads, and anything open.
