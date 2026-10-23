class_name DashState
extends PlayerState
## Fixed-distance horizontal burst that ignores gravity. One per airtime;
## a ground dash can be cancelled into a jump. Ends early against a wall.

var _time_left := 0.0


func enter() -> void:
	_time_left = player.tuning.dash_time
	player.facing = player.dash_direction
	player.horizontal_lock_timer = 0.0
	if not player.is_on_floor():
		player.air_dash_available = false


func exit() -> void:
	player.dash_cooldown_timer = player.tuning.dash_cooldown


func physics_update(delta: float) -> StringName:
	if player.wants_jump():
		return player.start_jump(&"ground")
	# Epsilon so float drift doesn't add a stray extra tick of dash.
	if _time_left <= 0.0001:
		return _finish()
	_time_left -= delta
	player.velocity = Vector2(player.dash_direction * player.tuning.dash_speed(), 0.0)
	return &""


func post_move(_delta: float) -> StringName:
	if player.is_on_wall():
		return _finish()
	return &""


func _finish() -> StringName:
	player.velocity.x = player.dash_direction * player.tuning.run_speed
	return &"idle" if player.is_on_floor() else &"fall"
