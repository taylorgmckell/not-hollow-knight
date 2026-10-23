class_name GroundedState
extends PlayerState
## Shared behaviour for states standing on the floor.


func physics_update(delta: float) -> StringName:
	if player.wants_jump():
		return &"jump"
	var t := player.tuning
	player.apply_horizontal(delta, t.ground_accel_time, t.ground_decel_time)
	player.apply_gravity(delta)
	return &""


func post_move(_delta: float) -> StringName:
	if not player.is_on_floor():
		return &"fall"
	return _ground_transition()


func _ground_transition() -> StringName:
	return &""
