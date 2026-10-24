class_name PlayerTuning
extends Resource
## Every movement feel value, editable live with the tuning panel (F2).
##
## Units are pixels and seconds. One tile is 32 px.
## Jump is specified as height + time-to-apex; gravity and launch velocity are
## derived from those so designers tune what they can see.

@export_group("Run")
@export_range(50.0, 600.0, 1.0, "suffix:px/s") var run_speed := 266.0
## Time to reach run speed from standing. Near zero = HK-style instant control.
@export_range(0.0, 0.3, 0.005, "suffix:s") var ground_accel_time := 0.03
@export_range(0.0, 0.3, 0.005, "suffix:s") var ground_decel_time := 0.02
@export_range(0.0, 0.5, 0.005, "suffix:s") var air_accel_time := 0.05
@export_range(0.0, 0.5, 0.005, "suffix:s") var air_decel_time := 0.05

@export_group("Jump")
@export_range(16.0, 320.0, 1.0, "suffix:px") var jump_height := 144.0
@export_range(0.15, 0.8, 0.01, "suffix:s") var time_to_apex := 0.42
## Upward velocity is multiplied by this when jump is released early.
@export_range(0.0, 1.0, 0.01) var jump_cut_multiplier := 0.0
## Jump can't be cut before this, which sets the shortest possible hop.
@export_range(0.0, 0.3, 0.005, "suffix:s") var min_jump_time := 0.06
@export_range(0.0, 0.3, 0.005, "suffix:s") var coyote_time := 0.09
@export_range(0.0, 0.3, 0.005, "suffix:s") var jump_buffer_time := 0.12

@export_group("Gravity")
## Below this vertical speed (while jump is held) the player is at the apex.
@export_range(0.0, 300.0, 1.0, "suffix:px/s") var apex_threshold := 60.0
@export_range(0.1, 1.0, 0.01) var apex_gravity_multiplier := 0.5
@export_range(1.0, 4.0, 0.05) var fall_gravity_multiplier := 1.8
@export_range(100.0, 2000.0, 10.0, "suffix:px/s") var max_fall_speed := 640.0

@export_group("Dash")
@export_range(32.0, 400.0, 1.0, "suffix:px") var dash_distance := 176.0
@export_range(0.05, 0.5, 0.01, "suffix:s") var dash_time := 0.2
## Time from the end of one dash until the next can start.
@export_range(0.0, 1.5, 0.01, "suffix:s") var dash_cooldown := 0.6

@export_group("Wall")
## Constant slide speed while clinging to a wall.
@export_range(0.0, 400.0, 1.0, "suffix:px/s") var wall_slide_speed := 140.0
@export_range(32.0, 320.0, 1.0, "suffix:px") var wall_jump_height := 128.0
@export_range(50.0, 600.0, 1.0, "suffix:px/s") var wall_jump_push := 300.0
## Horizontal input is ignored this long after a wall jump, so the kick
## can't be cancelled straight back into the wall.
@export_range(0.0, 0.4, 0.005, "suffix:s") var wall_jump_lock_time := 0.12
## A wall jump still works this long after letting go of the wall.
@export_range(0.0, 0.3, 0.005, "suffix:s") var wall_coyote_time := 0.08

@export_group("Double jump")
@export_range(16.0, 320.0, 1.0, "suffix:px") var double_jump_height := 144.0

@export_group("Nail")
@export_range(1, 10, 1) var nail_damage := 1
## Time from one swing starting until the next can start.
@export_range(0.1, 1.0, 0.01, "suffix:s") var attack_cooldown := 0.38
## How long a swing's hitbox stays live.
@export_range(0.02, 0.3, 0.01, "suffix:s") var attack_active_time := 0.08
## A press this long before the cooldown ends still swings.
@export_range(0.0, 0.3, 0.005, "suffix:s") var attack_buffer_time := 0.1
## Side hits push the player back this fast, with input locked briefly.
@export_range(0.0, 600.0, 1.0, "suffix:px/s") var recoil_speed := 220.0
@export_range(0.0, 0.3, 0.005, "suffix:s") var recoil_time := 0.08
## Height of the bounce from a down-slash (pogo). Fixed: not cut by releasing jump.
@export_range(32.0, 320.0, 1.0, "suffix:px") var pogo_height := 112.0
@export_range(0.0, 1000.0, 10.0, "suffix:px/s") var nail_knockback := 300.0
@export_range(0.0, 0.2, 0.005, "suffix:s") var hit_stop_time := 0.05

@export_group("Health")
@export_range(1, 12, 1) var max_masks := 5
## Invulnerability after taking damage (the player flickers).
@export_range(0.0, 3.0, 0.05, "suffix:s") var invuln_time := 1.3
@export_range(0.0, 600.0, 1.0, "suffix:px/s") var hurt_knockback_x := 250.0
@export_range(0.0, 600.0, 1.0, "suffix:px/s") var hurt_knockback_y := 300.0
## Control is lost for this long after a hit.
@export_range(0.0, 0.6, 0.01, "suffix:s") var hurt_stun_time := 0.2
@export_range(0.0, 0.3, 0.005, "suffix:s") var hurt_hit_stop := 0.12

@export_group("Soul")
@export_range(0, 99, 1) var soul_per_hit := 11
## Focus: hold the button on the ground to spend this much Soul for 1 mask.
@export_range(0, 99, 1) var focus_cost := 33
@export_range(0.2, 3.0, 0.05, "suffix:s") var focus_time := 0.9
## Pressing and releasing faster than this casts the spell instead of focusing.
@export_range(0.05, 0.5, 0.01, "suffix:s") var tap_threshold := 0.2
@export_range(0, 99, 1) var spell_cost := 33
@export_range(1, 20, 1) var spell_damage := 3
@export_range(100.0, 2000.0, 10.0, "suffix:px/s") var spell_speed := 900.0

@export_group("Forgiveness")
## Max sideways nudge around a ceiling corner that clips the head.
@export_range(0, 16, 1, "suffix:px") var corner_correction := 6
## Max upward nudge onto a ledge the feet barely miss.
@export_range(0, 16, 1, "suffix:px") var ledge_forgiveness := 6


func gravity() -> float:
	return 2.0 * jump_height / (time_to_apex * time_to_apex)


func jump_velocity() -> float:
	return velocity_for_height(jump_height)


func dash_speed() -> float:
	return dash_distance / dash_time


## Launch speed that peaks at `height` under our fixed-step integration.
## Continuous physics gives sqrt(2gh); stepping velocity before position loses
## about v·dt/2 of height per jump, so solve v²/2g - v·dt/2 = h instead.
func velocity_for_height(height: float) -> float:
	var g := gravity()
	var half_step := g / Engine.physics_ticks_per_second / 2.0
	return half_step + sqrt(half_step * half_step + 2.0 * g * height)
