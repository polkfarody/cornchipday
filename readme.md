# Cornchip Day

A 2D single-player platformer starring Cornchip, a walking corn chip on a quest across seven levels to reunite with his brother Wrap and make the ultimate crunch wrap.

## Status
Pre-alpha — vertical-slice MVP in development. See [plan.md](plan.md) for the roadmap and [feature.md](feature.md) for feature-level detail.

## Tech Stack
- **Engine:** Godot 4 (2D)
- **Language:** GDScript
- **Target platform (MVP):** Desktop, keyboard input

## Getting Started
1. Install [Godot 4.x](https://godotengine.org/download).
2. Clone or open this repository.
3. Open `project.godot` in Godot.
4. Press **Run** (F5) to play the current Level 1.

## Project Documentation
| File | Purpose |
|---|---|
| `game-brief.txt` | Design vision, premise, design philosophy |
| `characters.txt` | Character bible |
| `plan.md` | Roadmap and milestones |
| `feature.md` | Feature backlog and spec |
| `instructions-ai.txt` | AI collaboration charter / working agreement |

## Design Pillars
- **Gentle stakes, not a fail state** — hits cost a life (icon HUD only, no numbers), but running out just restarts the level from the beginning, never a game-over screen.
- **No reading required** — every instruction and story beat is communicated visually.
- **Physical comedy over verbal jokes** — puns land through animation, not text or voice.
- **Built to extend** — architecture should absorb more levels and the planned 2-player co-op mode without large rewrites.
