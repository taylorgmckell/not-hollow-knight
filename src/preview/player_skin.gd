extends Node2D
## Preview-art player: picks a frame of the horned creature from the player's
## state and adds squash and stretch on jumps, landings, dashes and wall grabs.
## Drawn at 3x so it roughly matches the 20x40 px collision box.

const PIXEL_SCALE := 3.0
const IDLE_FPS := 3.0
const RUN_FPS := 10.0
## How fast squash and stretch eases back to normal, per second.
const SQUASH_RECOVER := 12.0
const LAND_FRAME_TIME := 0.1

var _sprite := Sprite2D.new()
var _time := 0.0
var _squash := Vector2.ONE
var _land_timer := 0.0

@onready var _player: Player = get_parent()


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.texture = PreviewArt.tilesheet
	_sprite.region_enabled = true
	_sprite.centered = false
	# Feet at the player's origin: the frame's bottom-centre sits at (0, 0).
	_sprite.position = Vector2(-8, -16)
	_sprite.modulate = PreviewArt.PLAYER_TINT
	add_child(_sprite)
	_player.state_changed.connect(_on_player_state_changed)
	PreviewArt.changed.connect(func(enabled: bool) -> void: visible = enabled)
	visible = PreviewArt.enabled


func _process(delta: float) -> void:
	_time += delta
	_land_timer = maxf(_land_timer - delta, 0.0)
	_squash = _squash.lerp(Vector2.ONE, minf(1.0, SQUASH_RECOVER * delta))
	_sprite.region_rect = PreviewArt.region(Vector2i(_frame(), PreviewArt.PLAYER_ROW))
	scale = Vector2(PIXEL_SCALE * _squash.x * _player.facing, PIXEL_SCALE * _squash.y)
	modulate.a = _player.health.flicker_alpha()


func _frame() -> int:
	if _land_timer > 0.0:
		return 4
	match _player.state_name:
		&"run":
			return int(_time * RUN_FPS) % 4
		&"jump":
			return 1
		&"fall":
			return 3
		&"wall_slide":
			return 2
		&"dash":
			return 0
	return int(_time * IDLE_FPS) % 2


func _on_player_state_changed(from: StringName, to: StringName) -> void:
	match to:
		&"jump":
			_squash = Vector2(0.75, 1.25)
		&"dash":
			_squash = Vector2(1.35, 0.7)
		&"wall_slide":
			_squash = Vector2(0.85, 1.1)
		&"idle", &"run":
			if from in [&"fall", &"jump", &"dash", &"wall_slide"]:
				_squash = Vector2(1.3, 0.75)
				_land_timer = LAND_FRAME_TIME
