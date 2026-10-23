class_name Player
extends CharacterBody2D
## Player controller.
##
## Velocity is integrated by hand each physics tick by the active state (see
## states/). Shared feel helpers live here; docs/PLAN.md §2 lists the features.

signal state_changed(from: StringName, to: StringName)
## A forgiveness assist moved the player: kind is &"corner" or &"ledge".
signal assisted(kind: StringName, nudge: Vector2)
## The head hit a ceiling while rising, killing the jump.
signal bonked
signal respawned(at: Vector2)

## How many state changes may chain within one tick before we stop.
const MAX_TRANSITIONS_PER_TICK := 4

@export var tuning: PlayerTuning

## When true, something else (tests, replays) fills `input` each tick.
var external_input := false
## Corner correction and ledge forgiveness. Toggle with F3 to compare.
var assists_enabled := true
var input := PlayerInput.new()
var facing := 1
var coyote_timer := 0.0
var jump_buffer_timer := 0.0
var state_name: StringName = &""

var _states: Dictionary[StringName, PlayerState] = {}
var _state: PlayerState


func _ready() -> void:
	add_to_group(&"player")
	floor_snap_length = 4.0
	_states = {
		&"idle": IdleState.new(self),
		&"run": RunState.new(self),
		&"jump": JumpState.new(self),
		&"fall": FallState.new(self),
	}
	change_state(&"fall")


func _physics_process(delta: float) -> void:
	if not external_input:
		input.read_from_devices()
	_tick_timers(delta)

	# Let each newly entered state compute this tick's velocity too.
	for i: int in MAX_TRANSITIONS_PER_TICK:
		var next := _state.physics_update(delta)
		if next.is_empty():
			break
		change_state(next)

	if assists_enabled:
		_apply_corner_correction(delta)
		_apply_ledge_forgiveness(delta)
	var rising := velocity.y < 0.0
	move_and_slide()
	if rising and is_on_ceiling():
		bonked.emit()
	if is_on_floor():
		coyote_timer = tuning.coyote_time

	var after := _state.post_move(delta)
	if not after.is_empty():
		change_state(after)


func change_state(next: StringName) -> void:
	assert(_states.has(next), "Unknown player state: %s" % next)
	var previous := state_name
	if _state:
		_state.exit()
	_state = _states[next]
	state_name = next
	_state.enter()
	state_changed.emit(previous, next)


## Teleport and clear all motion, e.g. after falling out of the level.
func respawn(at: Vector2) -> void:
	global_position = at
	velocity = Vector2.ZERO
	coyote_timer = 0.0
	jump_buffer_timer = 0.0
	change_state(&"fall")
	respawned.emit(at)


func wants_jump() -> bool:
	return jump_buffer_timer > 0.0 and coyote_timer > 0.0


func consume_jump() -> void:
	jump_buffer_timer = 0.0
	coyote_timer = 0.0


func apply_horizontal(delta: float, accel_time: float, decel_time: float) -> void:
	var target := input.move_x * tuning.run_speed
	var has_input := not is_zero_approx(input.move_x)
	var ramp_time := accel_time if has_input else decel_time
	if ramp_time <= 0.0:
		velocity.x = target
	else:
		velocity.x = move_toward(velocity.x, target, tuning.run_speed / ramp_time * delta)
	if has_input:
		facing = int(signf(input.move_x))


func apply_gravity(delta: float) -> void:
	var g := tuning.gravity()
	if absf(velocity.y) < tuning.apex_threshold and input.jump_held:
		g *= tuning.apex_gravity_multiplier
	elif velocity.y > 0.0:
		g *= tuning.fall_gravity_multiplier
	velocity.y = minf(velocity.y + g * delta, tuning.max_fall_speed)


func _tick_timers(delta: float) -> void:
	if input.jump_pressed:
		jump_buffer_timer = tuning.jump_buffer_time
	else:
		jump_buffer_timer = maxf(jump_buffer_timer - delta, 0.0)
	coyote_timer = maxf(coyote_timer - delta, 0.0)


## Rising into a ceiling corner by a few pixels slides the player around it.
## Tests this tick's real (diagonal) motion, so running jumps are covered too.
func _apply_corner_correction(delta: float) -> void:
	if velocity.y >= 0.0:
		return
	var motion := velocity * delta
	if not test_move(global_transform, motion):
		return
	# Only correct ceiling hits: after the sideways part of the move (if it's
	# free), the rise must be what's blocked. Running into a wall isn't a corner.
	var step := Vector2(motion.x, 0.0)
	var after_step := global_transform
	if not test_move(after_step, step):
		after_step = after_step.translated(step)
	if not test_move(after_step, Vector2(0.0, motion.y)):
		return
	for offset: int in range(1, tuning.corner_correction + 1):
		for direction: int in [facing, -facing]:
			var shift := Vector2(direction * offset, 0.0)
			if test_move(global_transform, shift):
				continue
			if not test_move(global_transform.translated(shift), motion):
				global_position += shift
				assisted.emit(&"corner", shift)
				return


## Moving sideways into a ledge the feet barely miss lifts the player onto it.
func _apply_ledge_forgiveness(delta: float) -> void:
	if is_on_floor() or is_zero_approx(velocity.x):
		return
	var motion := Vector2(velocity.x * delta, 0.0)
	if not test_move(global_transform, motion):
		return
	for offset: int in range(1, tuning.ledge_forgiveness + 1):
		var lift := Vector2(0.0, -offset)
		if test_move(global_transform, lift):
			return
		if not test_move(global_transform.translated(lift), motion):
			global_position += lift
			assisted.emit(&"ledge", lift)
			return
