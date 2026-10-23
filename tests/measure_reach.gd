extends Node
## Measures movement reach with the current tuning and prints it as Markdown
## rows for docs/metrics.md. Re-run whenever player_tuning.tres changes:
##   godot --headless --fixed-fps 60 res://tests/measure_reach.tscn

const PLAYER_SCENE := preload("res://src/player/player.tscn")
const TILE := 32.0
const HALF_WIDTH := 10.0

var _world: Node2D
var _player: Player


func _ready() -> void:
	var peak := await _measure_peak()
	var running := await _measure_running_jump(false)
	var coyote := await _measure_running_jump(true)
	var tuning := _player.tuning
	print("| Run speed | %.0f px/s | %.1f tiles/s |" % [tuning.run_speed, tuning.run_speed / TILE])
	print("| Full jump peak (feet) | %.1f px | %.1f |" % [peak, peak / TILE])
	print("| Highest pillar reachable | %d px | %d |" % [floori(peak / TILE) * TILE, floori(peak / TILE)])
	print("| Running jump, edge to edge | %.0f px | %.1f |" % [running.x, running.x / TILE])
	print("| Running jump with late coyote jump | %.0f px | %.1f |" % [coyote.x, coyote.x / TILE])
	print("| Airtime, full running jump | %d ticks | %.2f s |" % [running.y, running.y / 60.0])
	get_tree().quit()


func _reset(floor_rect: Rect2, at: Vector2) -> void:
	if _world:
		_world.queue_free()
	_world = Node2D.new()
	add_child(_world)
	var body := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = floor_rect.size
	shape.shape = box
	body.position = floor_rect.get_center()
	body.add_child(shape)
	_world.add_child(body)
	_player = PLAYER_SCENE.instantiate()
	_player.external_input = true
	_world.add_child(_player)
	_player.global_position = at
	for i: int in 12:
		await get_tree().physics_frame


func _measure_peak() -> float:
	await _reset(Rect2(-2000, 0, 4000, 64), Vector2(0, -2))
	var start_y := _player.global_position.y
	var peak_y := start_y
	_player.input.jump_pressed = true
	_player.input.jump_held = true
	for i: int in 240:
		await get_tree().physics_frame
		_player.input.jump_pressed = false
		peak_y = minf(peak_y, _player.global_position.y)
		if i > 2 and _player.is_on_floor():
			break
	return start_y - peak_y


## Floor ends at x = 0. Returns (widest gap cleared in px, airtime in ticks).
## Without coyote, jumps on the last tick still over the floor; with coyote,
## on the last tick coyote time allows.
func _measure_running_jump(use_coyote: bool) -> Vector2:
	await _reset(Rect2(-3000, 0, 3000, 64), Vector2(-800, -2))
	_player.input.move_x = 1.0
	var start_y := _player.global_position.y
	var dt := 1.0 / 60.0
	var jumped := false
	var airtime := 0
	for i: int in 600:
		if not jumped:
			var next_left_edge := _player.global_position.x - HALF_WIDTH + _player.velocity.x * dt
			var leaving := next_left_edge > 0.0
			if use_coyote:
				# Coyote ticks down before the jump check, so it must survive one more decrement.
				var left_after_tick := _player.coyote_timer - dt
				leaving = _player.state_name == &"fall" and left_after_tick > 0.0 and left_after_tick <= dt
			if leaving:
				_player.input.jump_pressed = true
				_player.input.jump_held = true
				jumped = true
		await get_tree().physics_frame
		_player.input.jump_pressed = false
		if jumped:
			airtime += 1
			if airtime > 2 and _player.global_position.y >= start_y:
				break
	# A platform starting anywhere under the right edge would have caught us.
	return Vector2(_player.global_position.x + HALF_WIDTH, airtime)
