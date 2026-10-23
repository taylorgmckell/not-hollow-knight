class_name WallSlideState
extends PlayerState
## Clinging to a wall: slide down at a constant speed, facing away from it.
## Grabbing a wall refills the air dash and double jump. Holding away lets
## go; a wall jump still works for `wall_coyote_time` after that.

## Small push into the wall so contact is detected every tick.
const STICK_SPEED := 60.0


func enter() -> void:
	player.wall_side = int(signf(player.get_wall_normal().x))
	player.refill_air_moves()


func physics_update(_delta: float) -> StringName:
	player.facing = player.wall_side
	player.wall_coyote_timer = player.tuning.wall_coyote_time
	if player.wants_wall_jump():
		return player.start_jump(&"wall")
	if player.wants_dash():
		return player.begin_dash(player.wall_side)
	if int(signf(player.input.move_x)) == player.wall_side:
		return &"fall"
	player.velocity = Vector2(-player.wall_side * STICK_SPEED, player.tuning.wall_slide_speed)
	return &""


func post_move(_delta: float) -> StringName:
	if player.is_on_floor():
		return &"idle"
	if not player.is_on_wall():
		return &"fall"
	return &""
