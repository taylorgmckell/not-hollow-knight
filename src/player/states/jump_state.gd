class_name JumpState
extends PlayerState
## Rising part of a ground, wall or double jump (see Player.next_jump_kind).
## Releasing jump early cuts upward velocity (variable jump height), but never
## before `min_jump_time`.

var _time := 0.0
var _cut := false


func enter() -> void:
	var t := player.tuning
	var kind := player.next_jump_kind
	player.consume_jump()
	match kind:
		&"wall":
			player.velocity.y = -t.velocity_for_height(t.wall_jump_height)
			player.velocity.x = player.wall_side * t.wall_jump_push
			player.facing = player.wall_side
			player.horizontal_lock_timer = t.wall_jump_lock_time
		&"double":
			player.velocity.y = -t.velocity_for_height(t.double_jump_height)
			player.double_jump_available = false
		_:
			player.velocity.y = -t.jump_velocity()
	player.last_jump_kind = kind
	player.next_jump_kind = &"ground"
	_time = 0.0
	_cut = false


func physics_update(delta: float) -> StringName:
	if player.wants_dash():
		return player.begin_dash()
	# A second press while still rising is a double jump (re-enters this state).
	if player.wants_double_jump():
		return player.start_jump(&"double")
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
