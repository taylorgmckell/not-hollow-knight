class_name RunState
extends GroundedState


func _ground_transition() -> StringName:
	if is_zero_approx(player.input.move_x):
		return &"idle"
	return &""
