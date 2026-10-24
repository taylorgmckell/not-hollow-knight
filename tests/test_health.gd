extends TestCase
## M4 health and Soul: masks, contact damage, knockback, invulnerability,
## Soul gain, focus (heal) and its interruption, and the spell.

const PLAYER_SCENE := preload("res://src/player/player.tscn")
const DT := 1.0 / 60.0

var player: Player
var tuning: PlayerTuning
var health: PlayerHealth
var events: Array[String] = []


func before_each() -> void:
	player = PLAYER_SCENE.instantiate()
	player.external_input = true
	player.tuning = player.tuning.duplicate()
	tuning = player.tuning
	add_child(player)
	health = player.health
	health.healed.connect(func() -> void: events.append("healed"))
	health.died.connect(func() -> void: events.append("died"))
	health.focus_interrupted.connect(func(lost: int) -> void: events.append("interrupted %d" % lost))
	health.spell_cast.connect(func() -> void: events.append("cast"))
	await tick()


func after_each() -> void:
	Engine.time_scale = 1.0


func settle_on_floor(at := Vector2.ZERO) -> void:
	add_block(Rect2(-2000, 0, 4000, 64))
	player.global_position = at + Vector2(0, -2)
	await tick(10)


func ticks(seconds: float) -> int:
	return ceili(seconds / DT)


func dummy(at: Vector2, harmful := false) -> TrainingDummy:
	var d := TrainingDummy.new()
	d.harmful = harmful
	d.position = at
	add_child(d)
	return d


## Holds the focus button for `seconds`, then releases it.
func hold_focus(seconds: float) -> void:
	player.input.focus_pressed = true
	player.input.focus_held = true
	await tick()
	player.input.focus_pressed = false
	await tick(maxi(ticks(seconds) - 1, 0))
	player.input.focus_held = false
	await tick()


func tap_focus() -> void:
	player.input.focus_pressed = true
	player.input.focus_held = true
	await tick()
	player.input.focus_pressed = false
	player.input.focus_held = false
	await tick()


# --- Damage ---

func test_contact_damage_costs_a_mask_and_knocks_back() -> void:
	await settle_on_floor()
	dummy(Vector2(60, 0), true)
	var at_hit := [Vector2.ZERO]
	health.damaged.connect(func(_a: int, _f: Vector2) -> void: at_hit[0] = player.velocity)
	player.input.move_x = 1.0
	for i: int in 60:
		await tick()
		if health.masks < health.max_masks():
			break
	player.input.move_x = 0.0
	await tick()
	assert_eq(health.masks, health.max_masks() - 1, "lost one mask")
	assert_eq(player.state_name, &"hurt", "stunned")
	assert_true(player.velocity.x < 0.0 and player.velocity.y < 0.0, "knocked up and away (%s)" % player.velocity)


func test_invulnerability_blocks_repeat_hits() -> void:
	await settle_on_floor()
	add_child(ContactDamage.make_rect(Vector2(200, 100), Vector2(0, -50)))
	await tick(2)
	assert_eq(health.masks, health.max_masks() - 1, "first hit")
	await tick(ticks(tuning.invuln_time) - 10)
	assert_eq(health.masks, health.max_masks() - 1, "invulnerable while standing in it")
	await tick(20)
	assert_eq(health.masks, health.max_masks() - 2, "hit again once invulnerability ends")


func test_out_of_masks_dies_once() -> void:
	await settle_on_floor()
	health.masks = 1
	add_child(ContactDamage.make_rect(Vector2(200, 100), Vector2(0, -50)))
	await tick(ticks(tuning.invuln_time) + 30)
	assert_eq(health.masks, 0, "no masks left")
	assert_eq(events.count("died"), 1, "died signalled once")


## Playtest finding: a broken thorny dummy kept hurting while invisible.
func test_broken_thorny_dummy_does_not_hurt() -> void:
	await settle_on_floor()
	var thorny := dummy(Vector2(0, 0), true)
	await tick(2)
	thorny.hurtbox.receive(DamageInfo.make(thorny.max_hp, Vector2(-50, 0), Vector2.RIGHT, 0.0, &"side"))
	assert_true(thorny.is_broken(), "broken")
	# Spawning on it knocked the player away: stand back on its spot.
	health.restore(false)
	player.respawn(Vector2(0, -2))
	await tick(20)
	assert_eq(health.masks, health.max_masks(), "standing where it was doesn't hurt")
	await tick(ticks(TrainingDummy.RESPAWN_TIME))
	assert_true(not thorny.is_broken(), "back")
	player.respawn(Vector2(0, -2))
	await tick(2)
	assert_eq(health.masks, health.max_masks() - 1, "its thorns work again once it's back")


# --- Soul ---

func test_nail_hits_on_targets_give_soul() -> void:
	await settle_on_floor()
	dummy(Vector2(40, 0))
	player.input.attack_pressed = true
	await tick()
	player.input.attack_pressed = false
	await tick(5)
	assert_eq(health.soul, tuning.soul_per_hit, "one hit's worth of Soul")


func test_soul_caps_at_99() -> void:
	await settle_on_floor()
	dummy(Vector2(40, 0))
	health.soul = 95
	player.input.attack_pressed = true
	await tick()
	player.input.attack_pressed = false
	await tick(5)
	assert_eq(health.soul, PlayerHealth.SOUL_MAX, "capped")


func test_pogo_off_spikes_gives_no_soul() -> void:
	var spikes := Hurtbox.make_rect(Vector2(128, 16), Vector2(0, -8), true, false)
	spikes.collision_layer = Hurtbox.LAYER_HAZARD
	add_child(spikes)
	player.global_position = Vector2(0, -200)
	player.input.move_y = 1.0
	for i: int in 120:
		await tick()
		if player.velocity.y > 0.0 and player.global_position.y > -50.0:
			break
	player.input.attack_pressed = true
	await tick()
	player.input.attack_pressed = false
	await tick(2)
	assert_eq(player.last_jump_kind, &"pogo", "bounced")
	assert_eq(health.soul, 0, "spikes give no Soul")


# --- Focus (heal) ---

func test_focus_heals_one_mask() -> void:
	await settle_on_floor()
	health.masks = health.max_masks() - 1
	health.soul = tuning.focus_cost
	player.input.move_x = 1.0
	player.input.focus_pressed = true
	player.input.focus_held = true
	await tick()
	player.input.focus_pressed = false
	await tick(ticks(tuning.tap_threshold) + 5)
	assert_eq(player.state_name, &"focus", "focusing")
	assert_near(player.velocity.x, 0.0, 0.01, "can't move while focusing, even holding right")
	await tick(ticks(tuning.focus_time))
	player.input.focus_held = false
	await tick()
	assert_eq(health.masks, health.max_masks(), "healed")
	assert_eq(health.soul, 0, "Soul spent")
	assert_true(events.has("healed"), "healed signalled")
	assert_true((player.get_node("HealFx") as HealFx).is_bursting(), "heal burst playing on the player")


func test_holding_keeps_healing() -> void:
	await settle_on_floor()
	health.masks = health.max_masks() - 2
	health.soul = tuning.focus_cost * 2
	await hold_focus(tuning.tap_threshold + tuning.focus_time * 2 + 0.2)
	assert_eq(health.masks, health.max_masks(), "two masks back")
	assert_eq(events.count("healed"), 2, "two heals")


func test_focus_needs_soul_ground_and_missing_health() -> void:
	await settle_on_floor()
	health.soul = tuning.focus_cost
	await hold_focus(tuning.tap_threshold + 0.2)
	assert_true(not events.has("healed") and health.soul == tuning.focus_cost, "no focus at full health")
	health.masks -= 1
	health.soul = tuning.focus_cost - 1
	await hold_focus(tuning.tap_threshold + 0.2)
	assert_eq(health.masks, health.max_masks() - 1, "no focus without enough Soul")
	health.soul = tuning.focus_cost
	player.global_position = Vector2(0, -400)
	await hold_focus(tuning.tap_threshold + 0.1)
	assert_true(player.state_name != &"focus", "no focus in the air")


func test_releasing_early_wastes_the_soul_drained() -> void:
	await settle_on_floor()
	health.masks = health.max_masks() - 1
	health.soul = tuning.focus_cost
	await hold_focus(tuning.tap_threshold + tuning.focus_time / 2.0)
	assert_eq(health.masks, health.max_masks() - 1, "no heal")
	assert_true(health.soul > 0 and health.soul < tuning.focus_cost,
			"about half the Soul gone (soul %d)" % health.soul)


## M4 exit check: a hit mid-focus stops the heal, costs a mask and wastes
## the Soul drained so far.
func test_hit_interrupts_focus() -> void:
	# No upward knockback, so the hit itself must end the focus (not leaving
	# the ground, which would also end it).
	tuning.hurt_knockback_y = 0.0
	await settle_on_floor()
	health.masks = health.max_masks() - 1
	health.soul = tuning.focus_cost
	player.input.focus_pressed = true
	player.input.focus_held = true
	await tick()
	player.input.focus_pressed = false
	await tick(ticks(tuning.tap_threshold + tuning.focus_time / 2.0))
	assert_eq(player.state_name, &"focus", "focusing when the dart arrives")
	var dart := Dart.new()
	dart.velocity = Vector2(-260, 0)
	dart.position = Vector2(60, -20)
	add_child(dart)
	for i: int in 30:
		await tick()
		if player.state_name == &"hurt":
			break
	await tick(ticks(tuning.focus_time))
	player.input.focus_held = false
	await tick()
	assert_eq(health.masks, health.max_masks() - 2, "the hit landed; no mask healed")
	assert_true(not events.has("healed"), "heal never completed")
	assert_true(events.any(func(e: String) -> bool: return e.begins_with("interrupted")), "focus interrupted")
	assert_true(health.soul < tuning.focus_cost, "the drained Soul is lost (soul %d)" % health.soul)


# --- Spell ---

func test_tap_casts_a_bolt_that_pierces_and_stops_at_walls() -> void:
	await settle_on_floor()
	add_block(Rect2(400, -200, 64, 200))
	var first := dummy(Vector2(120, 0))
	var second := dummy(Vector2(220, 0))
	var past_wall := dummy(Vector2(520, 0))
	health.soul = tuning.spell_cost
	await tap_focus()
	assert_true(events.has("cast"), "cast")
	assert_eq(health.soul, 0, "Soul spent")
	await tick(40)
	assert_eq(first.hp, first.max_hp - tuning.spell_damage, "first dummy hit")
	assert_eq(second.hp, second.max_hp - tuning.spell_damage, "pierced into the second")
	assert_eq(past_wall.hp, past_wall.max_hp, "stopped by the wall")


func test_no_cast_without_soul() -> void:
	await settle_on_floor()
	health.soul = tuning.spell_cost - 1
	await tap_focus()
	assert_true(not events.has("cast"), "not enough Soul")
	assert_eq(health.soul, tuning.spell_cost - 1, "Soul untouched")
