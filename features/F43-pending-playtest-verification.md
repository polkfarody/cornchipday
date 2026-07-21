# F43 — Pending Human-Playtest Verification Checklist

**Status:** Not a code feature — a checklist. Nothing here should be "built"; it's a list of things
already shipped that only a real human playthrough can confirm, because they were verified by headless
script and/or a single static screenshot, not by actually playing. Keep this file until each item below
has been played and confirmed, then delete the file (or fold the confirmation into `plan.md`).

## Why this exists
`plan.md`'s Phase 6 note flags: "the broader 'needs a real human playtest of F28-F37' item from Phase 5 is
also still open." That's a real gap spanning many shipped features, not one item — this file exists so a
fresh session doesn't have to re-scan all of `feature.md` to reconstruct the list.

## Checklist
- [ ] **Level 5 ice-sliding feel** (F14/F27) — `move_toward`-based drift verified analytically and via
      toggle-state headless test, never via actual simulated input (project's headless harness can't
      register `Input.action_press()` for this).
- [ ] **Level 6 heat-cycle fairness** (F15, texture fixed in F34) — the escape-timing bug from
      `full-run-feedback.txt` was fixed (`aa67189`) and the flat-color-fill complaint was fixed with a real
      texture (F34), but neither fix has been played live since.
- [ ] **L3-6 two-tier maze jump-feel** (F22) — reachability proven via exact jump-arc math against real
      `player.gd` constants, not via a live playthrough.
- [ ] **F19/F21 bonus-platform reachability while sliding (L5) or mid-heat-cycle (L6)** — flagged in F21's
      own notes as worth confirming; geometry is proven safe in isolation, not in the busy live scene.
- [ ] **Level 7 chase-corridor pacing** (F24) — the inescapable-hazard bug was fixed (`aa67189`), but the
      260px/s-vs-220px/s chase speed and 100px head start were never feel-tested, only headless-verified
      for correctness (hazard fires, contact costs a life, node positions are correct).
- [ ] **Ambient background music loop** (F37) — cannot be verified by the AI at all (it can't hear audio).
      Loop-point metadata is confirmed click-free by construction; whether it's actually pleasant on a long
      loop is unverified. Easy to disable (`AudioManager`'s `_ambient_player.play()` call) if it doesn't
      land.
- [ ] **2-player co-op prototype** (F38, `scenes/CoOpTest.tscn`) — needs two controllers/input devices, see
      [F40](F40-coop-rollout-to-real-levels.md) for why this specifically blocks further co-op work.
- [ ] **General F28-F37 batch** — this whole batch (hazard animation, window-art fixes, balance pass,
      bean/basket UI, Air Fryer onboarding, L2 climbing, world map/title/ending screens, HeatZone texture,
      SFX, ambient loop) shipped across one long 2026-07-21 session and was verified per-feature (headless
      + individual screenshots) but never played start-to-finish as one continuous session since landing.

## How to use this file
Play the game start to finish, watching specifically for the items above. For each one: if it feels right,
check it off here (or just delete the line). If something feels wrong, open a new note in
`user-input.txt` (per the existing Additions Log Workflow in `instructions-ai.txt`) describing what's
wrong — don't fix it inline while playtesting, triage it the same way every other piece of feedback in this
project has been triaged.
