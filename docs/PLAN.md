# Build Plan — not-hollow-knight

A 2D action Metroidvania in the spirit of Hollow Knight, built in **Godot 4**.
First milestone: a **vertical slice** — polished movement and combat, a few enemies,
one boss, and a small connected area.

The guiding principle: **feel first.** Hollow Knight is remembered for how it
controls. Every system after movement and combat is built on top of them, so they
get the most time, the most tuning and the earliest playtests.

---

## 1. Tech foundation

| Decision | Choice | Why |
|---|---|---|
| Engine | Godot 4.x (pin exact version in `project.godot`) | Strong 2D, text-based scenes diff well in git |
| Language | GDScript, static typing on (`untyped_declaration` warning = error) | Fast iteration, typed for safety |
| Physics | `CharacterBody2D` with hand-written velocity, **not** RigidBody | Platformer feel needs exact control |
| Tick | Physics at 60 Hz, all gameplay logic in `_physics_process` | Deterministic, frame-rate independent tuning |
| Resolution | 1920×1080 target, `canvas_items` stretch, camera zoom for scale | Hand-drawn art scales cleanly |
| Tuning | All feel values live in `Resource` files (`.tres`) | Tweak in the inspector without touching code |
| Tests | Small built-in runner (`tests/test_runner.tscn`, run headless); scripted input drives the real player scene | Catch regressions in feel, no plugin dependency |

### Proposed folder layout

```
project.godot
src/
  player/          player.tscn, player.gd, states/, player_tuning.tres
  combat/          hitbox.gd, hurtbox.gd, damage_info.gd, hitstop.gd
  enemies/         base_enemy.gd, crawler/, flyer/, charger/
  bosses/          boss_01/
  world/           rooms/, room_transition.gd, bench.gd
  camera/          game_camera.gd, camera_zone.gd
  ui/              hud/, pause/
  autoload/        game_state.gd, audio.gd, input_buffer.gd
  debug/           debug_overlay.gd, tuning_panel.gd
assets/            art/, audio/, fonts/
tests/
docs/
```

---

## 2. Movement (Phase 1 — the top priority)

### 2.1 Architecture

- `Player` is a `CharacterBody2D` driven by a **finite state machine**. Each state is
  its own script with `enter()`, `exit()`, `physics_update(delta)` and
  `handle_input()`.
- States: `Idle`, `Run`, `JumpRise`, `Fall`, `WallSlide`, `WallJump`, `Dash`,
  `DoubleJump`, `Attack` (overlays movement), `Hurt`, `Heal`, `Dead`, `Locked`
  (cutscenes, transitions).
- Abilities are **flags** on `GameState` (`has_dash`, `has_wall_jump`,
  `has_double_jump`) so later progression gating is free.
- An `InputBuffer` autoload records the timestamp of each action press so any state
  can ask "was jump pressed in the last N ms?".

### 2.2 Feel features (each one is its own small task)

| Feature | What it does | Starting value (tune by hand) |
|---|---|---|
| Instant acceleration | Reach top run speed in ~1–2 frames, stop almost instantly. HK-style tight control, no ice-skating | run speed ≈ 8.3 tiles/s |
| Variable jump height | Releasing jump early cuts upward velocity | cut to 0 on release |
| Coyote time | Can still jump shortly after walking off a ledge | 0.08–0.10 s |
| Jump buffer | Jump pressed just before landing still fires | 0.10–0.13 s |
| Apex hang | Lower gravity near the top of the jump | gravity × 0.5 when \|vy\| small |
| Fall gravity multiplier | Fall faster than you rise, for snappy arcs | × 1.5–2.0 |
| Terminal velocity | Cap fall speed so landings stay readable | tune |
| Corner correction | Nudge player past ceiling corners that clip the head by a few px | 4–6 px |
| Ledge forgiveness | Nudge up onto ledges you barely miss | 4–6 px |
| Wall slide | Slow slide when holding toward a wall (needs wall-jump ability) | fixed slow fall speed |
| Wall jump | Kick away from wall, short input lock so it can't be cancelled straight back | lock 0.1–0.15 s |
| Dash | Fixed distance, ignores gravity, cooldown, one air dash per airtime | ~0.2 s, cooldown 0.6 s |
| Double jump | Resets on ground, wall touch or pogo | — |

### 2.3 Tooling built alongside movement

- **Debug overlay** (toggle F1): current state, velocity, grounded, coyote and buffer
  timers, plus a trail of recent positions to visualise jump arcs.
- **Live tuning panel** (F2): sliders bound to `player_tuning.tres`, with a save
  button so good values are kept.
- **Graybox (measuring course)** with measured gaps and heights so reach is known
  and level design can rely on it. It deliberately includes impossible gaps and
  heights to find the limits, so failing is cheap (climb-out pits, number keys
  to jump between sections). Numbers go in `docs/metrics.md`.
- **Challenge course (acceptance course)**, switched to with F6. Built only from
  moves inside the *comfortable* range in `docs/metrics.md`. Pits and spikes are
  lethal and return you to the last checkpoint; the HUD shows run time and
  deaths, and the playtest log records each death with its cause, feature and
  what happened just before (last jump, time since a bonk).

### 2.4 Done when

- A playtester finishes the challenge course with **zero deaths** in at least one
  of their first three non-practice runs, and every death in the playtest log
  has been reviewed with none attributed to the controls (e.g. a bonk the corner
  assist should have covered, or a jump press that didn't fire). Deaths caused
  by a "comfortable" number being wrong mean `docs/metrics.md` (or the course)
  gets fixed.
- Jump, dash and wall-jump distances are recorded in `docs/metrics.md`.
- Movement replay tests pass: scripted inputs produce the expected landing positions
  within a tolerance.

---

## 3. Combat (Phase 2)

### 3.1 Core pieces

- **Hitbox / Hurtbox** components (`Area2D` subclasses) on separate collision layers:
  `player_hitbox`, `player_hurtbox`, `enemy_hitbox`, `enemy_hurtbox`, `hazard`.
- **`DamageInfo`** resource passed on every hit: amount, source position, knockback
  force, flags (`is_spike`, `can_pogo`, `ignores_iframes`).
- A single `apply_hit(info)` path on anything damageable, so the player, enemies,
  breakable walls and levers all react the same way.

### 3.2 Player attack (the nail)

| Element | Design |
|---|---|
| Directions | Side, up, and down (air only). Chosen from held direction at press time |
| Timing | Short startup, active window, recovery. Attack can be buffered during recovery |
| Cooldown | ~0.35–0.4 s between swings; a later charm/upgrade can shorten it |
| Hit recoil | Player pushed back slightly on a side hit, enemy knocked back further |
| **Pogo** | Down-slash hitting an enemy, spike or `can_pogo` object bounces the player up and resets dash and double jump. This is central to the feel, so it gets its own tests |
| Hit-stop | Freeze the game for 2–4 frames on a hit (longer on kills and when the player takes damage) |
| Juice | Slash VFX, enemy white flash, small camera shake, hit sound with pitch variation |

### 3.3 Player health and the Soul loop

- **Masks:** whole-number health (start at 5). Contact damage is 1 mask, with heavier
  hits possible.
- **Taking damage:** knockback, about 1.3 s of invulnerability frames with flicker, a
  short input lock, and hit-stop. Hazards (spikes, acid) respawn the player at the last
  safe ground position instead of killing them outright.
- **Soul:** each nail hit on an enemy grants Soul (about 11 per hit, out of 99 max).
- **Focus/heal:** hold a button to spend 33 Soul and restore 1 mask. You can't move
  while healing and taking a hit interrupts it, which creates the core risk/reward
  decision of the combat.
- **One spell** (a projectile, also costs 33 Soul) for the slice, so Soul has a second
  use.

### 3.4 Enemies (3 for the slice)

All share a `BaseEnemy` with health, a hurtbox, knockback response, a
death/drop routine and a simple state machine.

| Enemy | Behaviour | What it teaches |
|---|---|---|
| Crawler | Walks, turns at walls and ledges | Basic hitting and pogo |
| Flyer | Drifts toward player, recoils on hit | Up-slashes and air control |
| Charger | Spots player, telegraphs, lunges | Reading tells and dodging with dash |

### 3.5 Boss (1 for the slice)

- An arena that locks behind the player, with a health bar or no bar (decide
  per style), and **2 phases**.
- Built from 3–4 readable attacks, each with a clear audio and animation tell:
  a ground charge, a leap with a slam, an aerial dive, and in phase 2 a projectile
  barrage.
- An attack-pattern picker with weights and "don't repeat the same attack 3×" rules.
- Keep the **runback** from the nearest bench short. This was the most common
  complaint about Silksong.

### 3.6 Done when

- Hits feel impactful in a blind playtest (hit-stop, recoil and sound all firing).
- Pogo chains work across enemies and spikes.
- The boss is beatable without taking damage by a skilled player, and beatable with
  healing by a new player in under 10 attempts.

---

## 4. Supporting systems for the slice (Phase 3)

Kept deliberately thin so time stays on feel:

- **Camera:** smooth follow with look-ahead in the facing direction, vertical
  dead-zone, `CameraZone` areas that clamp to room bounds, and shake on impacts.
- **Rooms:** 6–10 hand-built rooms joined by edge transitions (fade, then place the
  player at the matching entrance). Use `TileMapLayer` for terrain.
- **Bench:** heals, sets respawn, saves.
- **Death:** respawn at bench, drop currency, and leave a Shade at the death spot that
  must be beaten to recover it.
- **One ability pickup** (dash or wall-jump) placed so it opens a shortcut, to
  prove the gating loop.
- **Save/load:** JSON in `user://`, holding ability flags, bench, currency, defeated
  boss and opened shortcuts.
- **HUD:** masks, Soul vessel, currency.
- **Map, charms, NPCs, shops:** out of scope for the slice. Leave hooks
  (`GameState` flags) only.

---

## 5. Art and audio approach

- Gray boxes and placeholder shapes until movement and combat are signed off.
  Animation timing is gameplay, so lock attack frame data first, then draw to it.
- Then hand-drawn sprites with a limited palette per area, and layered parallax
  backgrounds for depth.
- `AnimationPlayer` drives hitbox enable/disable on exact frames, so art and gameplay
  timing can't drift apart.
- Audio: footsteps, jump, land, dash, swing, hit, damage, heal and boss tells first;
  music later.

---

## 6. Milestones

| # | Milestone | Contents | Exit check | Status |
|---|---|---|---|---|
| M0 | Project setup | Godot project, folders, input map (keyboard + gamepad), debug overlay, CI running tests headless | Empty scene runs; tests run in CI | Done 2026-10-22 |
| M1 | Core movement | Run, jump, coyote, buffer, variable height, apex hang, fall gravity, corner correction | Graybox course feels tight in playtest | Done 2026-10-22 |
| M2 | Advanced movement | Dash, wall slide, wall jump, double jump, ability flags, challenge course | Metrics documented; clean challenge run (§2.4) | Done 2026-10-23 |
| M3 | Nail combat | Hitbox/hurtbox, 3-direction attacks, recoil, pogo, hit-stop, juice | Pogo chain test passes | Done 2026-10-23 |
| M4 | Health and Soul | Masks, i-frames, hazard respawn, Soul gain, heal, one spell | Heal interrupt works | Done 2026-10-24 |
| M5 | Enemies | Crawler, flyer, charger | Each one playtested in isolation | Next |
| M6 | Boss | 2-phase boss with arena | Difficulty targets met |  |
| M7 | Slice world | Rooms, camera, bench, save, Shade, ability gate, HUD | Full slice playable start to finish |  |
| M8 | Polish pass | Art, sound, VFX, tuning from playtests | External playtest of 5+ people |  |

M1–M4 is where most of the effort should go. Don't move past M4 until the
controls are fun to use in an empty room.

### Completed milestones

- **M0 (2026-10-22):** Godot 4.7 project, code-defined input map (keyboard +
  gamepad), debug overlay and tuning panel, headless test runner, CI on
  GitHub Actions.
- **M1 (2026-10-22):** all §2.2 feel features, graybox measuring course,
  playtest log. Playtests tuned `jump_height` to 176 and `corner_correction`
  to 16; an assists on/off playtest showed bonks at the overhang edge drop
  from 56% to 11% (at the original 6 px).
- **M2 (2026-10-23):** dash, wall slide, wall jump, double jump, ability
  flags; challenge course; `double_jump_height` tuned to 168 after the h10
  playtest. §2.4 done-check met: first non-practice challenge run finished
  with 1 death, the second was clean (43.0 s), then three more clean runs
  (25.2 s, 26.6 s, 24.0 s). The one death (spikes, 0.72 s after a normal
  ground jump, no bonk) was reviewed as a mistimed jump, not the controls.
  55 tests pass locally and in CI. Extras: CC0 preview art (F7), PS5
  controller layout (dash on R2, Options restarts, touchpad toggles art).
- **M3 (2026-10-23):** nail with side, up and
  down (air) swings, buffered cooldown, one hit per target per swing,
  side-hit recoil, pogo off dummies, lanterns and spikes (refills air moves),
  hit-stop, camera shake, white flash, slash VFX and synthesized swing/hit/pogo
  sounds. Graybox section 8 has dummies and a pogo chain over spikes. The exit
  check (an automated pogo chain across four lanterns and a spiked post with no
  spike contact) passes. Playtest: "feels good"; 151 swings and 79 hits in the
  main session, pogo chain cleared three times, long chains pogoing straight
  off floor spikes. The log showed three deaths on the same tick as a
  successful spike pogo (the slash connected as the body sank into the
  spikes); fixed with a 0.05 s spike grace after any pogo, with a regression
  test. 74 tests.
- **M4 (2026-10-24):** 5 masks; contact damage
  with knockback, stun, hit-stop and 1.3 s flickering invulnerability;
  graybox spikes cost a mask and return you to the last safe ground, and
  running out restarts the section (Soul lost); Soul from nail hits (11,
  max 99); focus/cast on one button (tap = piercing spell, hold = heal) with
  a HUD Soul vessel that drains while focusing; heals stop on release, a hit
  or leaving the ground, losing the drained Soul. Thorny dummy and dart
  turret in graybox section 9. Exit check passes: a dart hitting mid-focus
  stops the heal (mutation-checked so it can't pass by the knockback lifting
  the player). Playtest: masks, hazard respawn, Soul, heal and the spell all
  confirmed working. Fixes from playtesting: heal feedback added (gathering
  glow, burst, popping HUD mask); a broken thorny dummy no longer hurts; the
  focus glow no longer stays frozen on screen after a released or hit
  focus. 93 tests.

---

## 7. Risks

| Risk | Mitigation |
|---|---|
| Controls feel "floaty" or "slippery" | Tuning panel plus frequent playtests; compare side by side with reference games |
| Physics edge cases (stuck on corners, clipping through thin floors at dash speed) | Corner correction, `CharacterBody2D` safe margin, minimum floor thickness rule, replay tests |
| Scope creep into map, charms and NPCs | Section 4 lists what's out; add hooks only |
| Art bottleneck | Gray boxes until M7; lock frame data before drawing |
| Too close to Hollow Knight (legal or identity) | Original setting, characters, names and art; borrow *mechanics*, not content |
