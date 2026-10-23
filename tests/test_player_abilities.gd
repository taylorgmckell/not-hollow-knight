extends TestCase
## M2 abilities: dash, wall slide, wall jump, double jump. Abilities start
## locked (the runner resets GameState); each test unlocks what it needs.

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


func settle_on_floor(at := Vector2.ZERO) -> void:
	player.global_position = at + Vector2(0, -2)
	await tick(10)


func press(action: StringName) -> void:
	match action:
		&"jump":
			player.input.jump_pressed = true
			player.input.jump_held = true
		&"dash":
			player.input.dash_pressed = true
	await tick()
	player.input.jump_pressed = false
	player.input.dash_pressed = false


func floor_and_wall() -> void:
	add_block(Rect2(-2000, 0, 4000, 64))
	# Wall face at x = 100, tall.
	add_block(Rect2(100, -2000, 64, 2000))


## Falls next to the wall holding toward it until wall sliding.
func grab_wall() -> void:
	player.global_position = Vector2(60, -400)
	player.input.move_x = 1.0
	for i: int in 60:
		await tick()
		if player.state_name == &"wall_slide":
			break


# --- Dash ---

func test_no_dash_without_ability() -> void:
	add_block(Rect2(-2000, 0, 4000, 64))
	await settle_on_floor()
	await press(&"dash")
	assert_true(not states_seen.has(&"dash"), "dash locked")


func test_ground_dash_covers_dash_distance() -> void:
	GameState.has_dash = true
	add_block(Rect2(-2000, 0, 4000, 64))
	await settle_on_floor()
	var start_x := player.global_position.x
	await press(&"dash")
	for i: int in 30:
		if player.state_name != &"dash":
			break
		await tick()
	assert_near(player.global_position.x - start_x, tuning.dash_distance, 6.0, "dash distance")


func test_air_dash_holds_height_and_is_once_per_airtime() -> void:
	GameState.has_dash = true
	player.global_position = Vector2(0, -1000)
	player.velocity = Vector2.ZERO
	await tick(2)
	var y_at_dash := player.global_position.y
	await press(&"dash")
	await tick(roundi(tuning.dash_time / DT) - 2)
	assert_eq(player.state_name, &"dash", "still dashing")
	assert_near(player.global_position.y, y_at_dash, 4.0, "no vertical drift while dashing")
	await tick(int(tuning.dash_cooldown / DT) + 4)
	states_seen.clear()
	await press(&"dash")
	assert_true(not states_seen.has(&"dash"), "second air dash refused")


func test_air_dash_refills_on_landing() -> void:
	GameState.has_dash = true
	add_block(Rect2(-2000, 0, 4000, 64))
	player.global_position = Vector2(0, -150)
	await tick(2)
	await press(&"dash")
	assert_true(not player.air_dash_available, "air dash spent")
	await tick(90)
	assert_true(player.is_on_floor() and player.air_dash_available, "refilled on landing")


func test_dash_cooldown() -> void:
	GameState.has_dash = true
	add_block(Rect2(-2000, 0, 4000, 64))
	await settle_on_floor()
	await press(&"dash")
	await tick(roundi(tuning.dash_time / DT) + 2)
	states_seen.clear()
	await press(&"dash")
	assert_true(not states_seen.has(&"dash"), "dash refused during cooldown")
	await tick(ceili(tuning.dash_cooldown / DT))
	await press(&"dash")
	assert_true(states_seen.has(&"dash"), "dash allowed after cooldown")


func test_landing_clears_dash_cooldown() -> void:
	GameState.has_dash = true
	tuning.dash_cooldown = 5.0  # long enough that only landing can clear it
	add_block(Rect2(-2000, 0, 4000, 64))
	player.global_position = Vector2(0, -60)
	await tick(2)
	await press(&"dash")
	for i: int in 120:
		await tick()
		if player.is_on_floor() and player.state_name != &"dash":
			break
	assert_true(player.is_on_floor(), "landed")
	assert_eq(player.dash_cooldown_timer, 0.0, "cooldown cleared on landing")
	states_seen.clear()
	await press(&"dash")
	assert_true(states_seen.has(&"dash"), "can dash right after landing")


func test_standing_still_keeps_ground_dash_cooldown() -> void:
	GameState.has_dash = true
	tuning.dash_cooldown = 5.0
	add_block(Rect2(-2000, 0, 4000, 64))
	await settle_on_floor()
	await press(&"dash")
	await tick(roundi(tuning.dash_time / DT) + 5)
	assert_true(player.dash_cooldown_timer > 0.0, "cooldown still running on the ground")
	states_seen.clear()
	await press(&"dash")
	assert_true(not states_seen.has(&"dash"), "no ground dash spam")


func test_ground_dash_cancels_into_jump() -> void:
	GameState.has_dash = true
	add_block(Rect2(-2000, 0, 4000, 64))
	await settle_on_floor()
	await press(&"dash")
	await tick(3)
	await press(&"jump")
	assert_eq(player.state_name, &"jump", "jumped out of the dash")


# --- Wall slide and wall jump ---

func test_no_wall_slide_without_ability() -> void:
	floor_and_wall()
	await grab_wall()
	assert_true(player.state_name != &"wall_slide", "wall slide locked")


func test_wall_slide_speed() -> void:
	GameState.has_wall_jump = true
	floor_and_wall()
	await grab_wall()
	assert_eq(player.state_name, &"wall_slide", "grabbed the wall")
	await tick(5)
	assert_near(player.velocity.y, tuning.wall_slide_speed, 1.0, "slide speed")
	assert_eq(player.facing, -1, "faces away from the wall")


func test_neutral_input_keeps_sliding_and_away_lets_go() -> void:
	GameState.has_wall_jump = true
	floor_and_wall()
	await grab_wall()
	player.input.move_x = 0.0
	await tick(5)
	assert_eq(player.state_name, &"wall_slide", "still sliding with no input")
	player.input.move_x = -1.0
	await tick(2)
	assert_eq(player.state_name, &"fall", "let go when holding away")


func test_wall_jump_kicks_away_and_locks_input() -> void:
	GameState.has_wall_jump = true
	floor_and_wall()
	await grab_wall()
	var start := player.global_position
	await press(&"jump")
	assert_eq(player.last_jump_kind, &"wall", "wall jump")
	# Still holding toward the wall: the lock must keep the kick going.
	await tick(int(tuning.wall_jump_lock_time / DT) - 2)
	assert_true(player.velocity.x < 0.0, "moving away from the wall during the lock")
	assert_true(player.global_position.x < start.x - 20.0, "kicked away from the wall")
	assert_true(player.global_position.y < start.y - 20.0, "rising")


func test_wall_coyote_jump_after_letting_go() -> void:
	GameState.has_wall_jump = true
	floor_and_wall()
	await grab_wall()
	player.input.move_x = -1.0
	await tick(2)
	assert_eq(player.state_name, &"fall", "let go")
	await press(&"jump")
	assert_eq(player.last_jump_kind, &"wall", "wall jump within wall coyote time")


## Wall jumps side to side up a shaft 4 tiles wide, holding toward each wall.
func test_climbs_a_shaft_with_wall_jumps() -> void:
	GameState.has_wall_jump = true
	add_block(Rect2(-2000, 0, 4000, 64))
	add_block(Rect2(-64, -2000, 64, 2000))
	add_block(Rect2(128, -2000, 64, 2000))
	await settle_on_floor(Vector2(64, 0))
	player.input.move_x = 1.0
	await press(&"jump")
	for i: int in 900:
		if player.state_name == &"wall_slide":
			player.input.move_x = -player.wall_side
			await press(&"jump")
			player.input.move_x = player.facing
		else:
			await tick()
		if player.global_position.y < -380.0:
			break
	assert_true(player.global_position.y < -380.0, "climbed 12 tiles (reached y %.0f)" % player.global_position.y)


func test_climbs_a_single_wall() -> void:
	GameState.has_wall_jump = true
	floor_and_wall()
	await settle_on_floor(Vector2(60, 0))
	player.input.move_x = 1.0
	await press(&"jump")
	for i: int in 900:
		if player.state_name == &"wall_slide":
			await press(&"jump")
		else:
			await tick()
		if player.global_position.y < -300.0:
			break
	assert_true(player.global_position.y < -300.0, "climbed a single wall (reached y %.0f)" % player.global_position.y)


func test_wall_grab_refills_air_moves() -> void:
	GameState.set_all_abilities(true)
	floor_and_wall()
	player.global_position = Vector2(0, -600)
	await tick(2)
	await press(&"jump")
	assert_true(not player.double_jump_available, "double jump spent")
	await tick(int(tuning.dash_cooldown / DT))
	await grab_wall()
	assert_eq(player.state_name, &"wall_slide", "grabbed the wall")
	assert_true(player.double_jump_available and player.air_dash_available, "air moves refilled")


# --- Double jump ---

func test_no_double_jump_without_ability() -> void:
	player.global_position = Vector2(0, -1000)
	await tick(2)
	await press(&"jump")
	assert_eq(player.state_name, &"fall", "no jump in mid-air")


func test_double_jump_height() -> void:
	GameState.has_double_jump = true
	player.global_position = Vector2(0, -1000)
	await tick(30)
	var start_y := player.global_position.y
	await press(&"jump")
	var peak_y := start_y
	for i: int in 120:
		peak_y = minf(peak_y, player.global_position.y)
		await tick()
		if player.velocity.y > 0.0:
			break
	assert_eq(player.last_jump_kind, &"double", "double jump")
	assert_near(start_y - peak_y, tuning.double_jump_height, 3.0, "double jump height")


## Playtest finding: double jump replaces upward speed, so pressing early loses
## the rest of the first jump. Players pressed ~0.1 s before the apex; that
## must still clear the graybox h10 pillar (320 px).
func test_double_jump_pressed_early_clears_h10() -> void:
	GameState.has_double_jump = true
	add_block(Rect2(-2000, 0, 4000, 64))
	await settle_on_floor()
	player.input.jump_pressed = true
	player.input.jump_held = true
	await tick()
	player.input.jump_pressed = false
	var press_speed := -tuning.gravity() * 0.1
	for i: int in 60:
		await tick()
		if player.velocity.y >= press_speed:
			break
	await press(&"jump")
	var peak_y := player.global_position.y
	for i: int in 90:
		await tick()
		peak_y = minf(peak_y, player.global_position.y)
	assert_true(-peak_y >= 320.0, "peak %.1f px clears h10 (320)" % -peak_y)


## Regression: the jump state runs in the same tick it's entered, and used to
## see the same press again and spend the double jump immediately.
func test_one_press_from_ground_is_one_jump() -> void:
	GameState.has_double_jump = true
	add_block(Rect2(-2000, 0, 4000, 64))
	await settle_on_floor()
	await press(&"jump")
	await tick(2)
	assert_eq(player.last_jump_kind, &"ground", "ground jump only")
	assert_true(player.double_jump_available, "double jump still available")


func test_double_jump_once_per_airtime() -> void:
	GameState.has_double_jump = true
	add_block(Rect2(-2000, 0, 4000, 64))
	await settle_on_floor()
	await press(&"jump")
	await tick(10)
	await press(&"jump")
	assert_eq(player.last_jump_kind, &"double", "first air press double jumps")
	await tick(10)
	states_seen.clear()
	await press(&"jump")
	assert_true(not states_seen.has(&"jump"), "no third jump")
	await tick(120)
	assert_true(player.is_on_floor() and player.double_jump_available, "refilled on landing")


func test_buffered_press_near_ground_is_ground_jump() -> void:
	GameState.has_double_jump = true
	add_block(Rect2(-2000, 0, 4000, 64))
	await settle_on_floor()
	await press(&"jump")
	await press(&"jump")
	# Fall back down with the double jump already spent, then buffer a jump.
	for i: int in 200:
		await tick()
		if player.velocity.y > 0.0 and player.global_position.y > -15.0:
			break
	await press(&"jump")
	await tick(6)
	assert_eq(player.last_jump_kind, &"ground", "buffered press became a ground jump")
