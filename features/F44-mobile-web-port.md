# F44 — Mobile Web Port (Play on Phone via GitHub Pages)

**Status:** Not started.

## Background
User asked to get the game onto their phone. `feature.md`'s "Explicitly Out of Scope (MVP)" list names
"Touch/mobile input" — this feature knowingly expands past that original MVP boundary at the user's direct
request, not scope creep.

Asked the user to pick a delivery path, since each has very different tooling requirements:
native Android (needs Android SDK/JDK installed locally + a signing keystore), native iOS (needs a Mac +
Xcode — not achievable from this Windows machine), or a Web (HTML5/WASM) export played in the phone's
browser. **User picked: Web export, hosted on GitHub Pages** — no app store, no SDK install, works on any
phone's browser via a link.

## Constraints specific to this path
1. **No custom HTTP headers on GitHub Pages.** Godot 4's Web export defaults to wanting
   `Cross-Origin-Opener-Policy`/`Cross-Origin-Embedder-Policy` response headers (for `SharedArrayBuffer`/
   thread support), which GitHub Pages cannot be configured to send. The export preset must have **Thread
   Support disabled** — runs single-threaded, which is fine for a 2D platformer this size.
2. **No touch input exists today.** `player.gd` reads Godot's built-in `ui_left`/`ui_right`/`ui_up`/
   `ui_down`/`ui_accept` actions (`input_left`/etc. exported vars, default to those `ui_*` names) via
   `Input.get_axis`/`is_action_pressed`/`is_action_just_pressed`. A touch overlay just needs to drive those
   same action names via `Input.action_press()`/`action_release()` — **zero changes needed in `player.gd`
   itself**.
3. **Portrait phone screens vs. the game's fixed 1280x720 landscape viewport.** `project.godot` currently
   has no `window/stretch/mode` set (defaults to `disabled`, no scaling). Needs
   `stretch/mode="canvas_items"` + `stretch/aspect="keep"` so the game letterboxes cleanly on a tall phone
   screen instead of clipping or distorting. True lock-to-landscape isn't reliably available across mobile
   browsers (notably Safari), so this plan relies on letterboxing + a one-time "rotate your phone"
   on-screen hint rather than a forced orientation lock.
4. **2P co-op is keyboard/WASD-only** (`p2_left/right/up/down/jump` custom actions in `project.godot`) —
   out of scope on a single touchscreen. Mobile is Player-1-only for this pass.
5. **`export_presets.cfg` is gitignored** (repo convention — each machine keeps its own). Adding the Web
   preset is a one-time local Godot Editor setup on this machine, not a tracked code change.

## Implementation
1. **Project settings** — `project.godot`: add `window/stretch/mode="canvas_items"` and
   `window/stretch/aspect="keep"` under `[display]`.
2. **Export preset** — in the Godot Editor, add a `Web` export preset (requires the Web export template,
   installed once via Editor > Manage Export Templates): thread support **off**, PWA/offline install
   **off** (not needed for a browser-link use case), export path `docs/index.html`.
3. **On-screen touch controls** — new `scenes/TouchControls.tscn` + `scripts/touch_controls.gd`:
   - A `CanvasLayer` with a left/right d-pad (bottom-left) and a jump button (bottom-right); add up/down
     buttons too if a level has spin-dash/tomato-seed unlocked, mirroring whichever abilities that level
     already grants.
   - Each button's `button_down`/`button_up` signals call `Input.action_press("ui_left")` /
     `Input.action_release("ui_left")` etc. — the same action names `player.gd` already reads, so no
     gameplay script changes.
   - Gate visibility with `OS.has_feature("web")` so the Windows desktop build is unaffected — simplest
     reliable check, avoids over-engineering touch-vs-mouse detection.
   - Wire once, centrally: instance `TouchControls.tscn` into `level_base.gd`'s existing `$HUD`
     `CanvasLayer` during `_ready()` (same pattern as the existing `_setup_bean_hud()`), so every level
     picks it up automatically instead of editing all 7 level scenes by hand.
4. **Export + host on GitHub Pages**
   - Export the Web build to `docs/` at the repo root — GitHub Pages' "Deploy from a branch" mode serves a
     folder literally named `docs/` on a chosen branch, no Actions/CI required.
   - In the repo's GitHub settings, enable Pages: Source = "Deploy from a branch", branch = `main`, folder
     = `/docs`.
   - Commit the exported `docs/index.html`, `.wasm`, `.pck`, `.js` files — confirmed `.gitignore` doesn't
     exclude `docs/` (it only excludes `builds/`, which is the Windows Desktop export's separate output
     folder).
   - Resulting URL: `https://<username>.github.io/<repo>/` — open that link on the phone's browser.
5. **Deliberately deferred:** a GitHub Actions workflow to auto-export and republish `docs/` on every push.
   Skipped for this first pass to keep it small — manual export-and-commit matches how the existing
   `builds/` Windows export is already handled in this repo. Revisit only if re-exporting by hand becomes
   annoying.

## Files touched
- `project.godot` (`[display]` stretch settings)
- Local-only: Godot Editor's Web export preset (`export_presets.cfg`, gitignored, not committed)
- `scripts/level_base.gd` (instance touch controls into `$HUD`)
- New: `scenes/TouchControls.tscn`, `scripts/touch_controls.gd`
- New: `docs/` (exported Web build artifacts, committed for GitHub Pages)

## Verification
- Local: export the Web build and open `docs/index.html` in a desktop browser; confirm it boots and plays
  using mouse-clicks on the on-screen buttons as a stand-in for touch.
- Real device: after pushing to GitHub Pages and enabling Pages, open the published URL on the actual
  phone. Confirm the touch buttons move/jump Cornchip through at least Level 1 start-to-finish, and that
  the letterboxed layout doesn't clip the HUD or gameplay area in either portrait or landscape.
