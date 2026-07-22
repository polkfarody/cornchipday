# Remaining Features — Index

Standalone planning files, one per remaining/open feature, so a new session can open exactly one file
instead of re-reading all of `plan.md`/`feature.md` to get oriented. Each file is self-contained (goal,
current state, open questions to confirm, implementation sketch, verification approach).

| File | What it is | Blocked on |
|---|---|---|
| [F39-ability-gated-upgrade-system.md](F39-ability-gated-upgrade-system.md) | FB1/FB7: systemize/persist abilities (double jump, spin dash, tomato power), optionally gate content behind them | Scope confirmation from user |
| [F40-coop-rollout-to-real-levels.md](F40-coop-rollout-to-real-levels.md) | Roll the F38 2P co-op prototype into the real 7 levels | A human 2-controller playtest of `CoOpTest.tscn` |
| [F41-l4-l5-background-repositioning.md](F41-l4-l5-background-repositioning.md) | Reposition/enlarge the Level 4/5 window backgrounds to meet the ground line | Nothing — safe to build directly |
| [F42-art-consistency-pass.md](F42-art-consistency-pass.md) | FB4: full art consistency pass | A concrete list of inconsistent assets from the user (don't build blind) |
| [F43-pending-playtest-verification.md](F43-pending-playtest-verification.md) | Checklist (not code) of shipped features only verified headlessly, never played live | A real human playthrough |
| [F44-mobile-web-port.md](F44-mobile-web-port.md) | Get the game on the user's phone: Web export + touch controls, hosted on GitHub Pages | Nothing — safe to build directly |
| [FB34-mobile-touch-controls-missing-on-menus.md](FB34-mobile-touch-controls-missing-on-menus.md) | Bug: TouchControls only exists inside levels — TitleScreen/WorldMap/EndingScreen have no touch input, so phone players are stuck on the opening screen | Confirm implementation option (1/2/3) with user |

Source docs these were extracted from: `plan.md` (Phase 2/6 open checkboxes), `feature.md` (Backlog
section, FB1/FB4/FB6-followups), `full-run-feedback.txt` (L4/L5 background notes).
