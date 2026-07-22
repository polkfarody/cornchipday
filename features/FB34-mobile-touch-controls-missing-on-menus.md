# FB34 — Touch Controls Missing on Title/Map/Ending Screens (Mobile Web)

**Status:** Implemented (option 2, d-pad for WorldMap navigation — both confirmed with user). Not yet verified on a real device.

## Background
User tested the F44 mobile web build on an actual phone (via the GitHub Pages deploy). Report:
"Touchscreen doesn't work, I can't get past the opening screen."

## Root cause
`scripts/touch_controls.gd` (`TouchControls.tscn`) is only ever instanced from **`level_base.gd`'s
`_ready()`**, into each level's `$HUD` — see F44's "Wire once, centrally" note. It does not exist
anywhere outside of gameplay levels.

Three non-level screens drive their "continue" input purely off keyboard-style `ui_*` actions, with
**no on-screen touch equivalent at all**:
- `scripts/title_screen.gd:51` — `Input.is_action_just_pressed("ui_accept")` to leave the title screen
  and go to `WorldMap.tscn`.
- `scripts/world_map.gd:76,80-86` — `ui_accept` to select a level, `ui_left/right/up/down` to move the
  map cursor.
- `scripts/ending_screen.gd` — same `ui_accept` pattern (not yet inspected in detail this session).

A phone browser has no keyboard, so none of these actions ever fire. `run/main_scene` is
`TitleScreen.tscn` (`project.godot:14`), so this is the very first screen the player hits — matching
the user's report exactly ("can't get past the opening screen").

## Implementation options (pick one before building)
1. **Reuse `TouchControls.tscn` on these 3 screens too** — same d-pad + jump button already built for
   levels, since it already drives the exact same `ui_*` action names `world_map.gd`/`title_screen.gd`
   read. Simplest, zero new script logic, but the full d-pad is overkill for a title screen that only
   needs "tap to continue."
2. **A single generic "tap anywhere" handler** on `TitleScreen`/`EndingScreen` (e.g. an `_input()` check
   for `InputEventScreenTouch`, calling the same code path `ui_accept` triggers today) plus reusing
   `TouchControls.tscn`'s d-pad only on `WorldMap` (which actually needs directional navigation, not
   just advance).
3. **Promote `TouchControls` to an autoload/persistent overlay** that survives `change_scene_to_file()`
   instead of being instanced per-scene — one wiring point instead of three-plus. Bigger change than
   this bug needs; only worth it if more non-level screens keep needing this.

Recommendation going in: option 2 — matches what each screen actually needs (tap-to-continue vs.
d-pad navigation) instead of dropping a full gameplay d-pad onto a title card.

## Resolved
- Confirmed with user: option 2 (tap-anywhere on Title/Ending, `TouchControls.tscn`'s d-pad on
  WorldMap).
- `WorldMap` touch navigation: d-pad, not tap-on-node. `TouchControls.tscn` is reused there in full
  (not d-pad only) since entering the selected level still needs a touch equivalent for `ui_accept`
  — its accept button is relabeled "GO" via a new `accept_label` export (`touch_controls.gd`) instead
  of "JUMP".

## Files likely touched
- `scripts/title_screen.gd`, `scenes/TitleScreen.tscn`
- `scripts/world_map.gd`, `scenes/WorldMap.tscn`
- `scripts/ending_screen.gd`, its scene (path not yet confirmed)
- Possibly `scripts/touch_controls.gd` if it needs a variant/param (e.g. "d-pad only" vs. "tap only" mode)

## Verification
- Headless: not meaningful for touch input (same limitation F44/other input-feel items already hit —
  simulated input doesn't reliably register through this project's headless harness).
- Real device: open the published GitHub Pages URL on the actual phone, confirm tapping advances past
  the title screen, lets you pick a level on the world map, and advances past the ending screen —
  without ever needing a keyboard.
