class_name JumpState
extends PlayerState
## Rising part of a jump. Releasing jump early cuts upward velocity
## (variable jump height), but never before `min_jump_time`.

var _time := 0.0
var _cut := false


func enter() -> void:
	player.consume_jump()
	player.velocity.y = -player.tuning.jump_velocity()
	_time = 0.0
	_cut = false


func physics_update(delta: float) -> StringName:
	var t := player.tuning
	_time += delta
	if not _cut and not player.input.jump_held and _time >= t.min_jump_time:
		player.velocity.y *= t.jump_cut_multiplier
		_cut = true
	player.apply_gravity(delta)
	player.apply_horizontal(delta, t.air_accel_time, t.air_decel_time)
	return &""


func post_move(_delta: float) -> StringName:
	# Also covers bonking a ceiling, since move_and_slide zeroes velocity.y.
	if player.velocity.y >= 0.0:
		return &"fall"
	return &""
