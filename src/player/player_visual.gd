extends Node2D
## Placeholder visuals: flips to face the movement direction. Hidden while
## preview art (F7) is on.

@onready var _player: Player = get_parent()


func _process(_delta: float) -> void:
	scale.x = _player.facing
	visible = not PreviewArt.enabled
	modulate.a = _player.health.flicker_alpha()
