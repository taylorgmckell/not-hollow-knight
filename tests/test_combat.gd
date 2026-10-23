extends TestCase
## M3 nail combat: swing directions, cooldown and buffer, hits, recoil,
## hit-stop, pogo, spikes and dummies.

const PLAYER_SCENE := preload("res://src/player/player.tscn")
const DT := 1.0 / 60.0

var player: Player
var tuning: PlayerTuning
var swings: Array[StringName] = []
var hits: Array[Dictionary] = []


func before_each() -> void:
	player = PLAYER_SCENE.instantiate()
	player.external_input = true
	player.tuning = player.tuning.duplicate()
	tuning = player.tuning
	add_child(player)
	player.nail.swung.connect(func(direction: StringName) -> void: swings.append(direction))
	player.nail.hit.connect(func(box: Hurtbox, direction: StringName, pogo: bool) -> void:
		hits.append({box = box, direction = direction, pogo = pogo}))
	await tick()


func after_each() -> void:
	Engine.time_scale = 1.0


func floor_block() -> void:
	add_block(Rect2(-2000, 0, 4000, 64))


func settle_on_floor(at := Vector2.ZERO) -> void:
	player.global_position = at + Vector2(0, -2)
	await tick(10)


func dummy(at: Vector2, lantern := false) -> TrainingDummy:
	var d := TrainingDummy.new()
	d.lantern = lantern
	d.position = at
	add_child(d)
	return d


func attack() -> void:
	player.input.attack_pressed = true
	await tick()
	player.input.attack_pressed = false


## Waits out the current swing's cooldown and any hit-stop.
func wait_cooldown() -> void:
	await tick(ceili(tuning.attack_cooldown / DT) + 1)


# --- Directions ---

func test_side_swing_hits_only_in_front() -> void:
	floor_block()
	var front := dummy(Vector2(40, 0))
	var back := dummy(Vector2(-40, 0))
	await settle_on_floor()
	await attack()
	await tick(3)
	assert_eq(swings, [&"side"] as Array[StringName], "one side swing")
	assert_eq(front.hp, front.max_hp - 1, "front dummy hit")
	assert_eq(back.hp, back.max_hp, "dummy behind untouched")


func test_side_swing_follows_facing() -> void:
	floor_block()
	var left := dummy(Vector2(-40, 0))
	await settle_on_floor()
	player.input.move_x = -1.0
	await tick(2)
	player.input.move_x = 0.0
	await attack()
	await tick(3)
	assert_eq(left.hp, left.max_hp - 1, "hit the dummy on the left after turning")


func test_up_swing_hits_overhead() -> void:
	floor_block()
	var overhead := dummy(Vector2(0, -80))
	await settle_on_floor()
	await attack()
	await tick(3)
	assert_eq(overhead.hp, overhead.max_hp, "a side swing misses the overhead dummy")
	await wait_cooldown()
	player.input.move_y = -1.0
	await attack()
	await tick(3)
	assert_eq(swings.back(), &"up", "up swing")
	assert_eq(overhead.hp, overhead.max_hp - 1, "up swing hits it")


func test_down_on_the_ground_is_a_side_swing() -> void:
	floor_block()
	await settle_on_floor()
	player.input.move_y = 1.0
	await attack()
	assert_eq(swings.back(), &"side", "down only works in the air")


# --- Timing ---

func test_cooldown_blocks_and_buffer_remembers() -> void:
	floor_block()
	await settle_on_floor()
	await attack()
	await tick(5)
	await attack()
	await tick(3)
	assert_eq(swings.size(), 1, "early press during cooldown doesn't swing (buffer too short)")
	# Press just inside the buffer window before the cooldown ends.
	await tick(ceili((tuning.attack_cooldown - tuning.attack_buffer_time) / DT) - 6)
	await attack()
	await tick(ceili(tuning.attack_buffer_time / DT) + 1)
	assert_eq(swings.size(), 2, "buffered press swings when the cooldown ends")


func test_cannot_swing_mid_dash() -> void:
	GameState.has_dash = true
	floor_block()
	await settle_on_floor()
	player.input.dash_pressed = true
	await tick()
	player.input.dash_pressed = false
	await tick(2)
	assert_eq(player.state_name, &"dash", "dashing")
	await attack()
	await tick(2)
	assert_true(swings.is_empty(), "no swing while dashing")


func test_keeps_running_while_swinging() -> void:
	floor_block()
	await settle_on_floor()
	player.input.move_x = 1.0
	await tick(5)
	await attack()
	await tick(2)
	assert_near(player.velocity.x, tuning.run_speed, 1.0, "swinging doesn't stop the run")


# --- Hits ---

func test_one_hit_per_swing() -> void:
	floor_block()
	var d := dummy(Vector2(40, 0))
	await settle_on_floor()
	await attack()
	await tick(ceili(tuning.attack_active_time / DT) + 4)
	assert_eq(d.hp, d.max_hp - 1, "only one hit over the whole active window")


func test_side_hit_recoils_player() -> void:
	floor_block()
	dummy(Vector2(40, 0))
	await settle_on_floor()
	await attack()
	await tick(2)
	assert_true(player.velocity.x < 0.0, "pushed back away from the target (vx %.0f)" % player.velocity.x)


func test_hit_stop_freezes_then_resumes() -> void:
	floor_block()
	dummy(Vector2(40, 0))
	await settle_on_floor()
	player.input.attack_pressed = true
	await tick()
	player.input.attack_pressed = false
	await get_tree().process_frame
	assert_true(HitStop.is_frozen(), "frozen right after the hit")
	for i: int in 20:
		await get_tree().process_frame
	assert_true(not HitStop.is_frozen(), "running again after the hit-stop")


func test_dummy_breaks_and_comes_back() -> void:
	floor_block()
	var d := dummy(Vector2(40, 0))
	await settle_on_floor()
	for i: int in d.max_hp:
		# Each hit's recoil pushes the player back; step in again like a player would.
		await settle_on_floor()
		await attack()
		await wait_cooldown()
	assert_true(d.is_broken(), "broken after max_hp hits")
	await settle_on_floor()
	await attack()
	await tick(3)
	assert_eq(hits.size(), d.max_hp, "a broken dummy can't be hit")
	await tick(ceili(TrainingDummy.RESPAWN_TIME / DT) + 2)
	assert_true(not d.is_broken() and d.hp == d.max_hp, "back with full HP")


# --- Pogo ---

## Drops the player onto a target, swinging down when it's in reach.
func drop_and_pogo(target_top: float) -> void:
	player.input.move_y = 1.0
	for i: int in 120:
		await tick()
		if player.velocity.y > 0.0 and target_top - player.global_position.y < 40.0:
			break
	await attack()
	await tick(2)


func test_pogo_bounces_and_refills_air_moves() -> void:
	GameState.set_all_abilities(true)
	var lantern := dummy(Vector2(0, 0), true)
	player.global_position = Vector2(0, -200)
	player.air_dash_available = false
	player.double_jump_available = false
	await drop_and_pogo(lantern.position.y - TrainingDummy.LANTERN_SIZE.y / 2.0)
	assert_eq(player.last_jump_kind, &"pogo", "pogo bounce")
	assert_true(player.velocity.y < 0.0, "moving up")
	assert_true(player.air_dash_available and player.double_jump_available, "air moves refilled")
	assert_true(hits.size() == 1 and hits[0].pogo, "hit reported as a pogo")


func test_pogo_height() -> void:
	var lantern := dummy(Vector2(0, 0), true)
	player.global_position = Vector2(0, -200)
	await drop_and_pogo(lantern.position.y - TrainingDummy.LANTERN_SIZE.y / 2.0)
	var start_y := player.global_position.y
	var peak_y := start_y
	for i: int in 60:
		await tick()
		peak_y = minf(peak_y, player.global_position.y)
	# Release jump doesn't cut a pogo, and the bounce started a tick or two ago.
	assert_near(start_y - peak_y, tuning.pogo_height, 16.0, "bounce height")


func test_pogo_off_spikes() -> void:
	var spikes := Hurtbox.make_rect(Vector2(128, 16), Vector2(0, -8), true, false)
	spikes.collision_layer = Hurtbox.LAYER_HAZARD
	add_child(spikes)
	player.global_position = Vector2(0, -200)
	await drop_and_pogo(-16.0)
	assert_eq(player.last_jump_kind, &"pogo", "bounced off the spikes")


func test_side_swing_ignores_spikes() -> void:
	floor_block()
	var spikes := Hurtbox.make_rect(Vector2(64, 16), Vector2(48, -8), true, false)
	spikes.collision_layer = Hurtbox.LAYER_HAZARD
	add_child(spikes)
	await settle_on_floor()
	await attack()
	await tick(3)
	assert_true(hits.is_empty(), "spikes only react to a down-slash")
	assert_near(player.velocity.x, 0.0, 1.0, "no recoil off spikes")
