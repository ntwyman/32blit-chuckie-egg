# Sprite-sheet fix verification swarm brief (issue #17, PR #18)

You are one independent verifier for https://github.com/ntwyman/32blit-chuckie-egg/pull/18. You did not write this code. Do not trust the PR body or the owner's claims.

## Fixed inputs

- Head: `20ba124a7651f4a04d95590c6af836a477228dbc` (branch `fix/sprite-sheet-bounds`).
- Parent: `1ff20c342e9390459e4519a7099b6b05cae0bd2d` (branch `ce-1/gpl-relicense`).
- The bug (issue #17): `sprites.cpp:20` `SpriteTime = Sprite(0,14,4,2)` covers sheet rows 112 to 127, but `assets/sheet.png` was 88x121, so the HUD read one row past the image and drew a per-process garbage pixel under TIME. The fix pads the sheet to 88x128 with transparent rows.
- Upstream reference: `third_party/pbrook-chuckie-egg/`.

## Rules

- Work only in your own worktree: `git worktree add /tmp/lane-sprite-<n> <SHA>`. Never edit `/workspaces/32blit-chuckie-egg`. Never push or comment on GitHub.
- There is no driver on this branch. Run the SDL build under `Xvfb :<99+n> -screen 0 640x480x24`, send keys with `xdotool`, press `z` at "How many players" and `z` at "Ready player". Record with `ffmpeg -f x11grab -framerate 100` if you need frames. Stop everything you start.
- Evidence under `/tmp/swarm-sprite/worker-<n>/`. Write your own scripts. Do not reuse the owner's.
- Report `PASS`, `ISSUES`, or `BLOCKED` first, with the SHA, commands, and evidence. List every defect you can prove.

## Lanes

- **Lane G, gates.** `git diff --stat 1ff20c3 20ba124` touches only `assets/sheet.png`. Rows 0 to 120 of the new sheet are pixel-identical to the old one (compare crops), the new rows are fully transparent, and the PNG's colour type and palette are unchanged (`identify -verbose`). SDL and STM32 build at both SHAs with zero new warnings. Record the `.blit` size at both, and fail if it grows by more than 64 bytes. `tools/check-license.sh` passes. CI on 20ba124 is green (`gh run list --branch fix/sprite-sheet-bounds`). Poll the PR's reviews, review comments, and issue comments (`gh api`), and report any that exist.
- **Lane H, HUD determinism.** Your own 20 separate game processes at head: take the first level-1 frame from each and show all are pixel-identical. Do 10 at parent and show at least two differ, so the red is real. Crop the HUD TIME area at head and look at it: the label reads TIME with its number and no stray pixel. Then let level 1 run for 10 seconds in 5 processes at head, take a frame at the same wall time, crop only the HUD's static label areas (PLAYER, LEVEL, BONUS, TIME labels, not the numbers), and show they match across processes.
- **Lane W, web and gameplay.** Build the web target at head and load it in Playwright's Chromium from `/opt/venv`. Get to level 1 and save a screenshot. The TIME label reads correctly. Then at head and at parent in the SDL build, walk Henry right for 3 seconds and save both frames. Gameplay matches apart from the one HUD pixel and timing noise.
- **Lane A1, audit: the asset pipeline.** Read `assets.yml`, the SDK's asset tooling in `/opt/32blit-sdk/tools` or the installed `32blit` tool, and how `asset_sprites` is loaded at runtime. Confirm the padded sheet is packed as you expect: the packed sheet's height is now 128 and no palette entry was added or reordered. Check that a transparent padding row is actually transparent when drawn (not black) by drawing the TIME sprite's rows 121 to 127 over a non-black background, or by reading the pixel values the runtime would use. Say whether padding could change any other sprite's colours.
- **Lane A2, audit: blast radius.** List every `Sprite(...)` rectangle and every `s.sprite` or `blit` call in `sprites.cpp`, `game.cpp`, `chuckie_egg.cpp`, and anything else that reads `asset_sprites`. For each, compute the sheet rows and columns it reads and check they are inside 88x128. Report any other read past the sheet, at head, with file:line. Compare the TIME label's art with upstream `SPRITE_TIME` in `third_party/pbrook-chuckie-egg/spritedata.c` and say whether it matches.
