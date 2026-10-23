class_name NailAttack
extends Node2D
## The nail: side, up and down (air only) swings, chosen from the held
## direction when the swing starts. It overlays movement, so the player keeps
## running and jumping while swinging, but can't swing mid-dash.
##
## The player calls `physics_update` after moving. Hits are found by querying
## the physics space each active tick, so a swing connects on the same tick it
## reaches a target. Each target is hit at most once per swing.

signal swung(direction: StringName)
signal hit(target: Hurtbox, direction: StringName, pogo: bool)

const HITBOX_MASK := Hurtbox.LAYER_ENEMY_HURTBOX | Hurtbox.LAYER_HAZARD
## Hitbox rects relative to the player's feet, facing right (px).
const SIDE_RECT := Rect2(10, -40, 62, 34)
const UP_RECT := Rect2(-22, -96, 44, 60)
const DOWN_RECT := Rect2(-22, -4, 44, 56)
const SLASH_FADE := 0.12
const SLASH_COLOR := Color(1, 1, 1, 0.9)

## Current or most recent swing: &"side", &"up" or &"down".
var direction: StringName = &""
var cooldown_timer := 0.0
var active_timer := 0.0
var buffer_timer := 0.0
var _hit_this_swing: Array[Hurtbox] = []
var _slash_age := INF
var _shape := RectangleShape2D.new()

@onready var player: Player = get_parent()


func _ready() -> void:
	z_index = 5


func _process(delta: float) -> void:
	# Scaled delta: the slash holds still during hit-stop, which sells the impact.
	if _slash_age < SLASH_FADE:
		_slash_age += delta
		queue_redraw()


func is_active() -> bool:
	return active_timer > 0.0


## World-space hitbox for a swing direction at the player's current position.
func hitbox_rect(swing: StringName) -> Rect2:
	var local: Rect2 = SIDE_RECT
	match swing:
		&"up":
			local = UP_RECT
		&"down":
			local = DOWN_RECT
		_:
			if player.facing < 0:
				local = Rect2(-local.end.x, local.position.y, local.size.x, local.size.y)
	return Rect2(player.global_position + local.position, local.size)


func physics_update(delta: float) -> void:
	var t := player.tuning
	cooldown_timer = maxf(cooldown_timer - delta, 0.0)
	if player.input.attack_pressed:
		buffer_timer = t.attack_buffer_time
	else:
		buffer_timer = maxf(buffer_timer - delta, 0.0)
	if buffer_timer > 0.0 and cooldown_timer <= 0.0 and player.state_name != &"dash":
		_start_swing()
	if active_timer > 0.0:
		_check_hits()
		active_timer = maxf(active_timer - delta, 0.0)


func _start_swing() -> void:
	var t := player.tuning
	buffer_timer = 0.0
	cooldown_timer = t.attack_cooldown
	active_timer = t.attack_active_time
	_hit_this_swing.clear()
	direction = _choose_direction()
	_slash_age = 0.0
	queue_redraw()
	Sfx.play(&"swing", -10.0)
	swung.emit(direction)


func _choose_direction() -> StringName:
	if player.input.move_y < 0.0:
		return &"up"
	if player.input.move_y > 0.0 and not player.is_on_floor():
		return &"down"
	return &"side"


func _check_hits() -> void:
	var rect := hitbox_rect(direction)
	_shape.size = rect.size
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = _shape
	query.transform = Transform2D(0.0, rect.get_center())
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.collision_mask = HITBOX_MASK
	for result: Dictionary in player.get_world_2d().direct_space_state.intersect_shape(query, 16):
		var box := result.collider as Hurtbox
		if box == null or not box.enabled or _hit_this_swing.has(box):
			continue
		var bounces := direction == &"down" and box.pogo
		# Bounce-only surfaces (spikes, lanterns) only matter to a down-slash.
		if not box.takes_damage and not bounces:
			continue
		_hit_this_swing.append(box)
		_land_hit(box, bounces)
		if bounces:
			# One bounce per swing, even if the slash overlaps several targets.
			active_timer = 0.0
			return


func _land_hit(box: Hurtbox, bounces: bool) -> void:
	var t := player.tuning
	var push := Vector2(player.facing, 0.0)
	match direction:
		&"up":
			push = Vector2.UP
		&"down":
			push = Vector2.DOWN
	if box.takes_damage:
		box.receive(DamageInfo.make(t.nail_damage, player.global_position, push, t.nail_knockback, direction))
	if bounces:
		player.pogo()
	elif direction == &"side":
		player.recoil(-player.facing)
	HitStop.freeze(t.hit_stop_time)
	Sfx.play(&"pogo" if bounces else &"hit")
	hit.emit(box, direction, bounces)


func _draw() -> void:
	if _slash_age >= SLASH_FADE:
		return
	var color := SLASH_COLOR
	color.a *= 1.0 - _slash_age / SLASH_FADE
	# A crescent sweeping across the hitbox, in the player's local space.
	match direction:
		&"up":
			draw_arc(Vector2(0, -40), 44.0, deg_to_rad(-150), deg_to_rad(-30), 12, color, 8.0)
		&"down":
			draw_arc(Vector2(0, -8), 44.0, deg_to_rad(30), deg_to_rad(150), 12, color, 8.0)
		_:
			var start := -60.0 if player.facing > 0 else 120.0
			draw_arc(Vector2(player.facing * 4.0, -23), 52.0, deg_to_rad(start), deg_to_rad(start + 120.0), 12, color, 8.0)
