class_name DartTurret
extends Node2D
## Fires a slow dart horizontally every `interval` seconds. A practice hazard
## for M4: it gives a steady rhythm of hits to dodge, and to heal between.
## Darts vanish on walls, on hitting the player, or after DART_LIFETIME.

const BODY_SIZE := Vector2(24, 24)
const DART_SPEED := 260.0
const DART_LIFETIME := 4.0
const BODY_COLOR := Color(0.45, 0.47, 0.55)

## -1 fires left, +1 fires right.
@export var direction := -1
@export var interval := 2.0

var _timer := 0.0


func _ready() -> void:
	_timer = interval


func _physics_process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_timer += interval
		fire()


func fire() -> Dart:
	var dart := Dart.new()
	dart.velocity = Vector2(direction * DART_SPEED, 0)
	dart.lifetime = DART_LIFETIME
	dart.position = position + Vector2(direction * BODY_SIZE.x / 2.0, 0)
	get_parent().add_child(dart)
	return dart


func _draw() -> void:
	var rect := Rect2(-BODY_SIZE / 2.0, BODY_SIZE)
	draw_rect(rect, BODY_COLOR)
	draw_rect(rect, Color(0.1, 0.1, 0.12), false, 2.0)
	draw_rect(Rect2(Vector2(direction * BODY_SIZE.x / 2.0 - (6 if direction > 0 else 0), -4), Vector2(6, 8)), BODY_COLOR.darkened(0.4))
