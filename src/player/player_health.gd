class_name PlayerHealth
extends Node
## Masks, Soul, damage and invulnerability, and the focus/cast button.
##
## Damage: contact zones (ContactDamage) are polled after each move. A hit
## costs masks, starts invulnerability and hit-stop; the player adds the
## knockback and stun. Soul: nail hits on things that take damage fill it.
## The focus/cast button is a tap to cast the spell, or a hold on the ground
## to heal (FocusState spends the Soul and gets interrupted by hits).

signal masks_changed(masks: int, max_masks: int)
signal soul_changed(soul: int)
signal damaged(amount: int, from: Vector2)
signal died
signal healed
signal focus_interrupted(soul_lost: int)
signal spell_cast

const SOUL_MAX := 99
## Body rect for contact damage, relative to the feet (matches the collider).
const BODY_RECT := Rect2(-10, -40, 20, 40)
const FLICKER_RATE := 15.0

var masks := 5
var soul := 0
var invuln_timer := 0.0
## 0..1 through the current focus, for the HUD's draining Soul.
var focus_progress := 0.0
## Seconds the focus button has been held; -1 when not tracking a press.
var _focus_hold := -1.0
var _shape := RectangleShape2D.new()

@onready var player: Player = get_parent()


func _ready() -> void:
	masks = player.tuning.max_masks


func max_masks() -> int:
	return player.tuning.max_masks


func is_invulnerable() -> bool:
	return invuln_timer > 0.0


func is_dead() -> bool:
	return masks <= 0


## Alpha for the player's sprite: blinks while invulnerable.
func flicker_alpha() -> float:
	if not is_invulnerable():
		return 1.0
	return 0.3 if int(invuln_timer * FLICKER_RATE) % 2 == 0 else 1.0


## Before the player's states run: timers and the focus/cast button.
func pre_update(delta: float) -> void:
	invuln_timer = maxf(invuln_timer - delta, 0.0)
	_track_focus_button(delta)


## After the player moves: contact damage.
func post_update(_delta: float) -> void:
	if is_invulnerable() or is_dead():
		return
	_shape.size = BODY_RECT.size
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = _shape
	query.transform = Transform2D(0.0, player.global_position + BODY_RECT.get_center())
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.collision_mask = ContactDamage.LAYER_ENEMY_HITBOX
	for result: Dictionary in player.get_world_2d().direct_space_state.intersect_shape(query, 8):
		var zone := result.collider as ContactDamage
		if zone and zone.enabled and player.hurt(zone.damage, zone.global_position):
			zone.hit_player.emit()
			return


## Takes masks. Returns false if nothing happened (invulnerable or dead).
## `ignore_invuln` is for hazards, which always cost a mask.
func damage(amount: int, from: Vector2, ignore_invuln := false) -> bool:
	if is_dead() or (is_invulnerable() and not ignore_invuln):
		return false
	masks = maxi(masks - amount, 0)
	invuln_timer = player.tuning.invuln_time
	masks_changed.emit(masks, max_masks())
	HitStop.freeze(player.tuning.hurt_hit_stop)
	Sfx.play(&"hurt")
	damaged.emit(amount, from)
	if is_dead():
		died.emit()
	return true


func gain_soul(amount: int) -> void:
	if amount <= 0 or soul >= SOUL_MAX:
		return
	soul = mini(soul + amount, SOUL_MAX)
	soul_changed.emit(soul)


## Back to full masks; after a death Soul is lost too.
func restore(lose_soul: bool) -> void:
	masks = max_masks()
	invuln_timer = 0.0
	masks_changed.emit(masks, max_masks())
	if lose_soul and soul > 0:
		soul = 0
		soul_changed.emit(soul)


func cancel_input() -> void:
	_focus_hold = -1.0
	focus_progress = 0.0


func can_focus() -> bool:
	return (player.is_on_floor() and (player.state_name == &"idle" or player.state_name == &"run")
			and soul >= player.tuning.focus_cost and masks < max_masks())


## While already focusing: is there Soul and missing health for another mask?
func can_focus_again() -> bool:
	return soul >= player.tuning.focus_cost and masks < max_masks()


## A full focus: spend the Soul, gain a mask.
func complete_focus() -> void:
	soul -= player.tuning.focus_cost
	masks = mini(masks + 1, max_masks())
	soul_changed.emit(soul)
	masks_changed.emit(masks, max_masks())
	Sfx.play(&"heal")
	healed.emit()


## Stopped part-way (released or hit): the Soul drained so far is lost.
func interrupt_focus(fraction: float) -> void:
	var lost := mini(roundi(clampf(fraction, 0.0, 1.0) * player.tuning.focus_cost), soul)
	soul -= lost
	soul_changed.emit(soul)
	focus_interrupted.emit(lost)


func cast_spell() -> bool:
	var t := player.tuning
	if soul < t.spell_cost or player.state_name in [&"dash", &"hurt", &"focus"] or is_dead():
		return false
	soul -= t.spell_cost
	soul_changed.emit(soul)
	var bolt := SoulBolt.new()
	bolt.direction = player.facing
	bolt.speed = t.spell_speed
	bolt.damage = t.spell_damage
	bolt.knockback = t.nail_knockback
	bolt.position = player.global_position + Vector2(player.facing * 16.0, -22.0)
	player.get_parent().add_child(bolt)
	Sfx.play(&"cast")
	spell_cast.emit()
	return true


func _track_focus_button(delta: float) -> void:
	var input := player.input
	if input.focus_pressed:
		_focus_hold = 0.0
	if _focus_hold < 0.0:
		return
	if not input.focus_held:
		if _focus_hold < player.tuning.tap_threshold:
			cast_spell()
		_focus_hold = -1.0
		return
	_focus_hold += delta
	if _focus_hold >= player.tuning.tap_threshold:
		_focus_hold = -1.0
		if can_focus():
			player.change_state(&"focus")
