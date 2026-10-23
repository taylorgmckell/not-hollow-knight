class_name GameCamera
extends Camera2D
## Minimal follow camera for the test courses, with impact shake on nail
## hits. Room clamping and look-ahead arrive with the slice world (M7).

const SHAKE_DECAY := 30.0
const HIT_SHAKE := 4.0
const POGO_SHAKE := 3.0

@export var target: Node2D
## Frame the player a little above centre so more of what's ahead is visible.
@export var vertical_offset := -80.0

var _shake := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	position_smoothing_enabled = true
	position_smoothing_speed = 8.0
	if target is Player:
		(target as Player).nail.hit.connect(func(_box: Hurtbox, _dir: StringName, pogo: bool) -> void:
			shake(POGO_SHAKE if pogo else HIT_SHAKE))


func _physics_process(_delta: float) -> void:
	if target:
		global_position = target.global_position + Vector2(0.0, vertical_offset)


func _process(delta: float) -> void:
	# Scaled time: the shake keeps jittering at full strength through hit-stop,
	# then decays once the game resumes.
	_shake = move_toward(_shake, 0.0, SHAKE_DECAY * delta)
	offset = Vector2(_rng.randf_range(-_shake, _shake), _rng.randf_range(-_shake, _shake))


func shake(strength: float) -> void:
	_shake = maxf(_shake, strength)
