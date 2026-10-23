class_name IdleState
extends GroundedState


func _ground_transition() -> StringName:
	if not is_zero_approx(player.input.move_x):
		return &"run"
	return &""
