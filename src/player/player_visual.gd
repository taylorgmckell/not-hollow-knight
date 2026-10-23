extends Node2D
## Placeholder visuals: flips to face the movement direction.

@onready var _player: Player = get_parent()


func _process(_delta: float) -> void:
	scale.x = _player.facing
