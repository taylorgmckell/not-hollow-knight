# Movement metrics

Measured reach with the values in `src/player/player_tuning.tres`.
Level design should rely on these numbers. **Re-measure whenever tuning changes:**

```bash
godot --headless --fixed-fps 60 res://tests/measure_reach.tscn
```

It prints the first six rows of the table below. One tile = 32 px. The
player's collision box is 20 × 40 px.

Last measured 2026-10-22, `jump_height` = 176 (tuned in playtest), other values default.

| Metric | Value | Tiles |
|---|---|---|
| Run speed | 266 px/s | 8.3 tiles/s |
| Full jump peak (feet) | 176.9 px | 5.5 |
| Highest pillar reachable | 160 px | 5 |
| Running jump, edge to edge | 250 px | 7.8 |
| Running jump with late coyote jump | 272 px | 8.5 |
| Airtime, full running jump | 52 ticks | 0.87 s |
| Coyote time | 0.09 s | ~5 ticks |
| Jump buffer | 0.12 s | ~7 ticks |

## Design rules that follow

- **Gaps:** up to 7 tiles is comfortable, 8 is an expert-only coyote jump
  (jump just after running off the edge), 9+ needs an ability (dash, double jump).
- **Heights:** up to 5 tiles reachable from flat ground; 6+ needs an ability
  or a stepping stone.
- **Ceilings:** a 3-tile-high corridor (96 px) lets the player jump without
  always bonking; under 2 tiles makes jumping feel cramped.

## Assists (forgiveness)

| Assist | Limit | Graybox section |
|---|---|---|
| Corner correction | 6 px sideways | `corner`: an overhang to jump out from under, and a floating platform to jump onto from close. Forgives about 1 frame of mistimed running jump (headless sweep: 4 of 31 overhang timings that bonk without it clear with it) |
| Ledge forgiveness | 6 px upward | `ledge`: top 3 px above the jump peak (`jump_height` + half the limit), reachable only with the assist |

In the graybox, press **F1** to see assists marked where they fire (magenta =
corner, yellow = ledge) with a running count, and **F3** to switch them off
and compare. Keys **1–4** jump to the gaps, pillars, corner and ledge sections;
**R** returns to the last one. Missed gaps drop into a 2-tile pit you can climb out of.
