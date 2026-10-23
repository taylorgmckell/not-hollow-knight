# Movement metrics

Measured reach with the values in `src/player/player_tuning.tres`.
Level design should rely on these numbers. **Re-measure whenever tuning changes:**

```bash
godot --headless --fixed-fps 60 res://tests/measure_reach.tscn
```

It prints every row of the tables below except coyote time and jump buffer,
which are tuning values. One tile = 32 px. The player's collision box is
20 × 40 px.

Last measured 2026-10-23, `jump_height` = 176, `double_jump_height` = 168 and
`corner_correction` = 16 (all tuned in playtest), other values default.

## Base movement (no abilities)

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

## With abilities (M2)

| Metric | Value | Tiles |
|---|---|---|
| Dash distance (0.2 s, cooldown 0.6 s) | 176 px | 5.5 |
| Peak with double jump at the apex | 345.1 px | 10.8 |
| Highest pillar with double jump | 320 px | 10 (press up to ~0.1 s before the apex) |
| Gap: coyote jump + dash at apex | 448 px | 14.0 |
| Gap: coyote jump + double jump at apex | 458 px | 14.3 |
| Gap: coyote jump + double jump + dash | 639 px | 20.0 |
| Wall slide speed | 140 px/s | 4.4 tiles/s |
| Wall jump | 128 px up, 300 px/s kick, input locked 0.12 s | 4 up |

Wall jumping climbs a 4-tile-wide shaft and also a single wall (tested
headless). Grabbing a wall refills the air dash and double jump.

Double jump *replaces* upward speed, so pressing before the apex loses the
rest of the first jump's rise. Playtesters pressed about 0.1 s early (129–168 px
up); at the original 144 px double jump their best reached 311 px, 9 px short
of h10. At 168 px a press from 152 px up clears h10 (guarded by a test).

## Design rules that follow

- **Gaps:** up to 7 tiles is comfortable, 8 is an expert-only coyote jump
  (jump just after running off the edge), 9+ needs an ability. With dash,
  up to 12 is comfortable and 14 is a perfect-timing jump; 15+ needs double
  jump and dash together (up to ~20).
- **Heights:** up to 5 tiles reachable from flat ground; 6+ needs an ability
  or a stepping stone. Double jump reaches 10 with normal timing; 11 is out of reach.
  Wall jump has no height limit while there's a wall.
- **Ceilings:** a 3-tile-high corridor (96 px) lets the player jump without
  always bonking; under 2 tiles makes jumping feel cramped.
- **Gating:** a gap of 9–14 tiles or a ledge of 6–10 tiles gates on dash or
  double jump respectively; a tall shaft gates on wall jump.

## Assists (forgiveness)

| Assist | Limit | Graybox section |
|---|---|---|
| Corner correction | 16 px sideways (default 6) | `corner`: an overhang to jump out from under, and a floating platform to jump onto from close. Headless sweep of 31 overhang timings: 20 bonk without the assist, 16 with it at 6 px, 2 with it at 16 px |
| Ledge forgiveness | 6 px upward | `ledge`: top 3 px above the jump peak (`jump_height` + half the limit), reachable only with the assist |

## Courses

- **Graybox** (main scene): the measuring course. Impossible gaps and heights
  are there on purpose to find limits; missed gaps drop into climb-out pits.
- **Challenge** (F6 from the graybox): the acceptance course, built only from
  the comfortable ranges above. Pits and spikes kill; you respawn at the last
  checkpoint. R restarts the run; 1–6 jump to a checkpoint for practice (that
  run doesn't count). Segments: plain gaps 4/6/7, spikes, a 5-tile step, an
  overhang gap, floating platforms, dash gaps 10/12, wall shaft and a 6-tile
  high gap, a 9-tile tower and 12-tile high gap, and a 16-tile finale.

## Graybox controls

| Key | Action |
|---|---|
| F1 | Overlay: state, timers, air moves, trail; assists (magenta corner, yellow ledge) and bonks (red) marked and counted |
| F2 | Live tuning panel; Save writes `player_tuning.tres` |
| F3 | Assists on/off |
| F4 | Abilities on/off (all start unlocked in the graybox) |
| F6 | Switch to the challenge course (and back) |
| F7 | Preview art on/off (visual only; see CREDITS.md) |
| 1–7 | Jump to gaps, pillars, corner, ledge, dash, walls, double jump |
| R | Return to the last section |

Missed gaps drop into a 2-tile pit you can climb out of.
