class_name TrainingDummy
extends Node2D
## Practice target until real enemies arrive (M5). Not solid, deals no damage.
##
## - Dummy: has HP, flashes white and wobbles when hit, breaks at 0 HP and
##   comes back after a moment. Pogo-able.
## - Lantern (`lantern = true`): floating, invulnerable, pogo-only. For pogo
##   chains over spikes.

signal damaged(info: DamageInfo)
signal broke

const DUMMY_SIZE := Vector2(28, 44)
const LANTERN_SIZE := Vector2(28, 28)
const FLASH_TIME := 0.1
const RESPAWN_TIME := 1.5
const WOBBLE_DECAY := 60.0
const BODY_COLOR := Color(0.62, 0.52, 0.38)
const LANTERN_COLOR := Color(0.95, 0.82, 0.45)
const OUTLINE := Color(0.1, 0.1, 0.12)
## Preview-art tiles: a critter for dummies, a ring for lanterns.
const DUMMY_TILE := Vector2i(0, 12)
const LANTERN_TILE := Vector2i(2, 0)

@export var lantern := false
@export var max_hp := 5

var hp := 5
var hurtbox: Hurtbox
var _flash := 0.0
var _wobble := Vector2.ZERO
var _broken_for := 0.0


func _ready() -> void:
	hp = max_hp
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_to_group(&"pogo_lanterns" if lantern else &"dummies")
	if lantern:
		hurtbox = Hurtbox.make_rect(LANTERN_SIZE, Vector2.ZERO, true, false)
		hurtbox.collision_layer = Hurtbox.LAYER_HAZARD
	else:
		hurtbox = Hurtbox.make_rect(DUMMY_SIZE, Vector2(0, -DUMMY_SIZE.y / 2.0), true, true)
		hurtbox.hurt.connect(_on_hurt)
	add_child(hurtbox)
	PreviewArt.changed.connect(func(_enabled: bool) -> void: queue_redraw())


func _process(delta: float) -> void:
	if _broken_for > 0.0:
		_broken_for -= delta
		if _broken_for <= 0.0:
			hp = max_hp
			hurtbox.enabled = true
		queue_redraw()
		return
	if _flash > 0.0 or _wobble != Vector2.ZERO:
		_flash = maxf(_flash - delta, 0.0)
		_wobble = _wobble.move_toward(Vector2.ZERO, WOBBLE_DECAY * delta)
		queue_redraw()


func is_broken() -> bool:
	return _broken_for > 0.0


func _on_hurt(info: DamageInfo) -> void:
	if is_broken():
		return
	hp -= info.amount
	_flash = FLASH_TIME
	_wobble = info.direction * 6.0
	damaged.emit(info)
	if hp <= 0:
		_broken_for = RESPAWN_TIME
		hurtbox.enabled = false
		# A kill gets a slightly longer freeze than a normal hit.
		HitStop.freeze(0.08)
		broke.emit()
	queue_redraw()


func _draw() -> void:
	var size := LANTERN_SIZE if lantern else DUMMY_SIZE
	var top_left := (Vector2(-size.x / 2.0, -size.y / 2.0) if lantern else Vector2(-size.x / 2.0, -size.y)) + _wobble
	var rect := Rect2(top_left, size)
	if is_broken():
		# A faint outline while it's away.
		draw_rect(rect, Color(1, 1, 1, 0.15), false, 1.0)
		return
	var flash := _flash > 0.0
	if PreviewArt.enabled:
		var tile := LANTERN_TILE if lantern else DUMMY_TILE
		var tint := Color.WHITE if flash else (LANTERN_COLOR if lantern else PreviewArt.DECOR_TINT.lightened(0.3))
		var art := Rect2(rect.get_center() - Vector2(24, 24), Vector2(48, 48))
		if not lantern:
			art.position.y = rect.end.y - 48
		draw_texture_rect_region(PreviewArt.tilesheet, art, PreviewArt.region(tile), tint)
	else:
		draw_rect(rect, Color.WHITE if flash else (LANTERN_COLOR if lantern else BODY_COLOR))
		draw_rect(rect, OUTLINE, false, 2.0)
	if not lantern:
		# HP pips above the head.
		for i: int in max_hp:
			var pip := Rect2(Vector2(-max_hp * 4 + i * 8, -size.y - 12) + _wobble, Vector2(6, 4))
			draw_rect(pip, Color(0.9, 0.3, 0.3) if i < hp else Color(1, 1, 1, 0.2))
