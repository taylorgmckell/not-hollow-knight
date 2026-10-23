class_name FallState
extends PlayerState
## Airborne and not rising under jump power. Coyote time lets a jump still
## fire for a moment after walking off a ledge (or letting go of a wall).


func physics_update(delta: float) -> StringName:
	var jump := player.try_air_jump()
	if not jump.is_empty():
		return jump
	if player.wants_dash():
		return player.begin_dash()
	var t := player.tuning
	player.apply_gravity(delta)
	player.apply_horizontal(delta, t.air_accel_time, t.air_decel_time)
	return &""


func post_move(_delta: float) -> StringName:
	if player.is_on_floor():
		return &"idle" if is_zero_approx(player.input.move_x) else &"run"
	if player.wants_wall_slide():
		return &"wall_slide"
	return &""
