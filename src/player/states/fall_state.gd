class_name FallState
extends PlayerState
## Airborne and not rising under jump power. Coyote time lets a jump still
## fire for a moment after walking off a ledge.


func physics_update(delta: float) -> StringName:
	if player.wants_jump():
		return &"jump"
	var t := player.tuning
	player.apply_gravity(delta)
	player.apply_horizontal(delta, t.air_accel_time, t.air_decel_time)
	return &""


func post_move(_delta: float) -> StringName:
	if player.is_on_floor():
		return &"idle" if is_zero_approx(player.input.move_x) else &"run"
	return &""
