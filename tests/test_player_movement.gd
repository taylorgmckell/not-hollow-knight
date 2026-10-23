extends TestCase
## Drives the real player scene with scripted input and checks the feel
## features from docs/PLAN.md §2.2. Expectations are derived from the tuning
## resource, so retuning values doesn't break the tests.

const PLAYER_SCENE := preload("res://src/player/player.tscn")
const DT := 1.0 / 60.0

var player: Player
var tuning: PlayerTuning
var states_seen: Array[StringName] = []


func before_each() -> void:
	player = PLAYER_SCENE.instantiate()
	player.external_input = true
	player.tuning = player.tuning.duplicate()
	tuning = player.tuning
	add_child(player)
	player.state_changed.connect(func(_from: StringName, to: StringName) -> void: states_seen.append(to))
	await tick()


## Adds a solid block given in pixels.
func add_block(rect: Rect2) -> void:
	var body := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = rect.size
	shape.shape = box
	body.position = rect.get_center()
	body.add_child(shape)
	add_child(body)


func settle_on_floor(at := Vector2.ZERO) -> void:
	player.global_position = at + Vector2(0, -2)
	await tick(10)


## Jumps from standing, holding jump for `hold_ticks`, and returns peak height.
func measure_jump(hold_ticks: int) -> float:
	var start_y := player.global_position.y
	var peak_y := start_y
	player.input.jump_pressed = true
	player.input.jump_held = true
	for i: int in 180:
		await tick()
		player.input.jump_pressed = false
		player.input.jump_held = i + 1 < hold_ticks
		peak_y = minf(peak_y, player.global_position.y)
		if i > 2 and player.is_on_floor():
			break
	return start_y - peak_y


func test_settles_on_floor() -> void:
	add_block(Rect2(-2000, 0, 4000, 64))
	player.global_position = Vector2(0, -100)
	await tick(60)
	assert_true(player.is_on_floor(), "player should be on the floor")
	assert_eq(player.state_name, &"idle", "state")
	assert_near(player.global_position.y, 0.0, 1.0, "feet rest on floor top")


func test_reaches_run_speed_almost_instantly() -> void:
	add_block(Rect2(-2000, 0, 4000, 64))
	await settle_on_floor()
	player.input.move_x = 1.0
	await tick(3)
	assert_near(player.velocity.x, tuning.run_speed, 0.5, "run speed after 3 ticks")
	assert_eq(player.state_name, &"run", "state")


func test_stops_almost_instantly() -> void:
	add_block(Rect2(-2000, 0, 4000, 64))
	await settle_on_floor()
	player.input.move_x = 1.0
	await tick(10)
	player.input.move_x = 0.0
	await tick(3)
	assert_near(player.velocity.x, 0.0, 0.5, "speed after releasing for 3 ticks")
	assert_eq(player.state_name, &"idle", "state")


func test_full_jump_reaches_tuned_height() -> void:
	add_block(Rect2(-2000, 0, 4000, 64))
	await settle_on_floor()
	var height := await measure_jump(999)
	assert_near(height, tuning.jump_height, 2.0, "full jump height")
	assert_true(player.is_on_floor(), "landed again")


func test_tapped_jump_is_a_short_hop() -> void:
	add_block(Rect2(-2000, 0, 4000, 64))
	await settle_on_floor()
	var height := await measure_jump(1)
	assert_true(height > 8.0, "short hop leaves the ground (got %.1f)" % height)
	assert_true(height < tuning.jump_height * 0.4, "short hop below 40%% of full (got %.1f)" % height)


func test_coyote_jump_after_leaving_ledge() -> void:
	add_block(Rect2(-2000, 0, 2000, 64))
	await settle_on_floor(Vector2(-60, 0))
	player.input.move_x = 1.0
	for i: int in 60:
		await tick()
		if player.state_name == &"fall":
			break
	assert_eq(player.state_name, &"fall", "walked off the ledge")
	await tick(2)
	player.input.jump_pressed = true
	player.input.jump_held = true
	await tick()
	assert_eq(player.state_name, &"jump", "jump within coyote time")


func test_no_jump_once_coyote_expires() -> void:
	add_block(Rect2(-2000, 0, 2000, 64))
	await settle_on_floor(Vector2(-60, 0))
	player.input.move_x = 1.0
	for i: int in 60:
		await tick()
		if player.state_name == &"fall":
			break
	await tick(ceili(tuning.coyote_time / DT) + 2)
	player.input.jump_pressed = true
	player.input.jump_held = true
	await tick()
	assert_eq(player.state_name, &"fall", "no jump after coyote time")


func test_buffered_jump_fires_on_landing() -> void:
	add_block(Rect2(-2000, 0, 4000, 64))
	player.global_position = Vector2(0, -200)
	var pressed_in_air := false
	for i: int in 120:
		await tick()
		var ticks_to_land := -player.global_position.y / maxf(player.velocity.y * DT, 0.01)
		if player.velocity.y > 0.0 and ticks_to_land < 4.0:
			pressed_in_air = not player.is_on_floor()
			break
	assert_true(pressed_in_air, "jump pressed while still airborne")
	states_seen.clear()
	player.input.jump_pressed = true
	player.input.jump_held = true
	await tick()
	player.input.jump_pressed = false
	await tick(8)
	assert_true(states_seen.has(&"jump"), "buffered jump fired (states: %s)" % [states_seen])


func test_fall_speed_is_capped() -> void:
	await tick(120)
	assert_near(player.velocity.y, tuning.max_fall_speed, 0.01, "terminal velocity")


func test_corner_correction_slides_past_ceiling_edge() -> void:
	add_block(Rect2(-2000, 0, 4000, 64))
	# Ceiling ends 3 px inside the player's left edge (player spans x -10..10).
	add_block(Rect2(-400, -120, 393, 16))
	await settle_on_floor()
	var height := await measure_jump(999)
	assert_true(height > 100.0, "jumped past the ceiling corner (height %.1f)" % height)
	# Collision safe margin means clearing a 3 px overlap takes 3-4 px.
	assert_true(player.global_position.x >= 3.0 and player.global_position.x <= 4.0,
			"nudged right by the overlap (x %.1f)" % player.global_position.x)


func test_ledge_forgiveness_lifts_onto_near_miss() -> void:
	add_block(Rect2(20, -100, 200, 100))
	player.global_position = Vector2(9, -96)
	player.velocity = Vector2(tuning.run_speed, 0)
	player.input.move_x = 1.0
	await tick(6)
	assert_true(player.is_on_floor(), "standing on the ledge")
	assert_near(player.global_position.y, -100.0, 1.0, "feet at ledge top")
	assert_true(player.global_position.x > 20.0, "moved onto the ledge")


## Mirrors the graybox "ledge" section: a wall just above the jump peak.
func _jump_at_tuned_height_ledge(assists: bool) -> bool:
	player.assists_enabled = assists
	var ledge_height := tuning.jump_height + tuning.ledge_forgiveness / 2.0
	add_block(Rect2(-2000, 0, 4000, 64))
	add_block(Rect2(40, -ledge_height, 200, ledge_height))
	await settle_on_floor()
	player.input.move_x = 1.0
	await measure_jump(999)
	return player.is_on_floor() and player.global_position.y < -ledge_height + 1.0


func test_tuned_height_ledge_needs_the_assist() -> void:
	var assists_fired: Array[StringName] = []
	player.assisted.connect(func(kind: StringName, _nudge: Vector2) -> void: assists_fired.append(kind))
	assert_true(await _jump_at_tuned_height_ledge(true), "reached the ledge with assists on")
	assert_true(assists_fired.has(&"ledge"), "ledge assist signalled")


func test_tuned_height_ledge_unreachable_without_assist() -> void:
	assert_true(not await _jump_at_tuned_height_ledge(false), "ledge out of reach with assists off")


## Runs right along the floor from `start_x` and jumps once the player's
## leading (or trailing) edge passes `trigger_x`. Returns whether it bonked.
func _running_jump_bonks(start_x: float, trigger_x: float, use_left_edge: bool, assists: bool) -> bool:
	player.assists_enabled = assists
	player.respawn(Vector2(start_x, -2))
	player.input.clear()
	await tick(8)
	var bonked := [false]
	var on_bonk := func() -> void: bonked[0] = true
	player.bonked.connect(on_bonk)
	player.input.move_x = 1.0
	for i: int in 200:
		var edge := player.global_position.x + (-10.0 if use_left_edge else 10.0)
		if edge >= trigger_x:
			break
		await tick()
	player.input.jump_pressed = true
	player.input.jump_held = true
	await tick()
	player.input.jump_pressed = false
	await tick(25)
	player.bonked.disconnect(on_bonk)
	return bonked[0]


## Sweeps jump timing near a corner and returns [bonks with assists, bonks without].
func _sweep_bonks(start_x: float, triggers: Array, use_left_edge: bool) -> Array[int]:
	var counts: Array[int] = [0, 0]
	for trigger_x: float in triggers:
		if await _running_jump_bonks(start_x, trigger_x, use_left_edge, true):
			counts[0] += 1
		if await _running_jump_bonks(start_x, trigger_x, use_left_edge, false):
			counts[1] += 1
	return counts


## Mirrors the graybox "overhang": run out from under a 2-tile-clear ceiling
## ending at x = 0 and jump at various points just before leaving it.
func test_overhang_assist_forgives_early_jumps() -> void:
	add_block(Rect2(-2000, 0, 4000, 64))
	add_block(Rect2(-600, -96, 600, 32))
	var triggers := range(-30, 1).map(func(d: int) -> float: return float(d))
	var counts := await _sweep_bonks(-300.0, triggers, true)
	print("          overhang: %d/%d jumps bonk with assists, %d/%d without" % [
		counts[0], triggers.size(), counts[1], triggers.size()])
	assert_true(counts[1] - counts[0] >= 2, "assists forgive several early jumps")


## Mirrors the graybox "platform": run at a floating platform starting at
## x = 0 (underside 3 tiles up) and jump at various distances from it.
func test_platform_edge_assist_forgives_late_jumps() -> void:
	add_block(Rect2(-2000, 0, 4000, 64))
	add_block(Rect2(0, -128, 128, 32))
	var triggers := range(-60, 1).map(func(d: int) -> float: return float(d))
	var counts := await _sweep_bonks(-300.0, triggers, false)
	print("          platform: %d/%d jumps bonk with assists, %d/%d without" % [
		counts[0], triggers.size(), counts[1], triggers.size()])
	assert_true(counts[1] - counts[0] >= 2, "assists forgive several late jumps")


func test_jumping_into_a_wall_is_not_corner_corrected() -> void:
	add_block(Rect2(-2000, 0, 4000, 64))
	add_block(Rect2(30, -600, 64, 600))
	await settle_on_floor()
	var assists_fired: Array[StringName] = []
	player.assisted.connect(func(kind: StringName, _nudge: Vector2) -> void: assists_fired.append(kind))
	player.input.move_x = 1.0
	await tick(10)
	await measure_jump(999)
	assert_true(not assists_fired.has(&"corner"), "no corner assist against a wall")
	assert_near(player.global_position.x, 20.0, 1.0, "still pressed against the wall")


func test_no_ledge_forgiveness_beyond_limit() -> void:
	add_block(Rect2(20, -100, 200, 100))
	player.global_position = Vector2(9, -100 + tuning.ledge_forgiveness + 4)
	player.velocity = Vector2(tuning.run_speed, 0)
	player.input.move_x = 1.0
	await tick(6)
	assert_true(player.global_position.x < 11.0, "blocked by the wall")
