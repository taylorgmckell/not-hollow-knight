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

@export_group("Forgiveness")
## Max sideways nudge around a ceiling corner that clips the head.
@export_range(0, 16, 1, "suffix:px") var corner_correction := 6
## Max upward nudge onto a ledge the feet barely miss.
@export_range(0, 16, 1, "suffix:px") var ledge_forgiveness := 6


func gravity() -> float:
	return 2.0 * jump_height / (time_to_apex * time_to_apex)


## Launch speed that peaks at `jump_height` under our fixed-step integration.
## Continuous physics gives sqrt(2gh); stepping velocity before position loses
## about v·dt/2 of height per jump, so solve v²/2g - v·dt/2 = h instead.
func jump_velocity() -> float:
	var g := gravity()
	var half_step := g / Engine.physics_ticks_per_second / 2.0
	return half_step + sqrt(half_step * half_step + 2.0 * g * jump_height)
