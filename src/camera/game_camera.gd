class_name GameCamera
extends Camera2D
## Minimal follow camera for the graybox. Room clamping, look-ahead and shake
## arrive with the slice world (M7).

@export var target: Node2D
## Frame the player a little above centre so more of what's ahead is visible.
@export var vertical_offset := -80.0


func _ready() -> void:
	position_smoothing_enabled = true
	position_smoothing_speed = 8.0


func _physics_process(_delta: float) -> void:
	if target:
		global_position = target.global_position + Vector2(0.0, vertical_offset)
