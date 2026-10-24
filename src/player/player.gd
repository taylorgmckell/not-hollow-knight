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
## After a pogo, spikes can't hurt for this long. A down-slash can connect on
## the same tick the falling body sinks a few px into spikes; the bounce needs
## a couple of ticks to carry the player clear (playtest finding).
const POGO_HAZARD_GRACE := 0.05

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

## Air moves refill on landing and when grabbing a wall.
var air_dash_available := true
var double_jump_available := true
var dash_cooldown_timer := 0.0
## Direction for the dash about to start (set by `begin_dash`).
var dash_direction := 1
## Which jump JumpState performs next, and which it performed last:
## &"ground", &"wall" or &"double".
var next_jump_kind: StringName = &"ground"
var last_jump_kind: StringName = &"ground"
## +1 when the last wall touched is on the left (pushes right), -1 for right.
var wall_side := 0
var wall_coyote_timer := 0.0
## While positive, apply_horizontal leaves velocity.x alone (wall-jump kick).
var horizontal_lock_timer := 0.0
## While positive, courses ignore spike contact (see POGO_HAZARD_GRACE).
var hazard_grace_timer := 0.0

var _states: Dictionary[StringName, PlayerState] = {}
var _state: PlayerState

@onready var nail: NailAttack = $Nail
@onready var health: PlayerHealth = $Health


func _ready() -> void:
	add_to_group(&"player")
	floor_snap_length = 4.0
	_states = {
		&"idle": IdleState.new(self),
		&"run": RunState.new(self),
		&"jump": JumpState.new(self),
		&"fall": FallState.new(self),
		&"dash": DashState.new(self),
		&"wall_slide": WallSlideState.new(self),
		&"hurt": HurtState.new(self),
		&"focus": FocusState.new(self),
	}
	change_state(&"fall")


func _physics_process(delta: float) -> void:
	if not external_input:
		input.read_from_devices()
	_tick_timers(delta)
	health.pre_update(delta)

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
	var was_on_floor := is_on_floor()
	move_and_slide()
	if rising and is_on_ceiling():
		bonked.emit()
	if is_on_floor():
		coyote_timer = tuning.coyote_time
		refill_air_moves()
		# Landing (air -> ground) clears the dash cooldown. Only the transition:
		# standing still must keep the cooldown between ground dashes.
		if not was_on_floor:
			dash_cooldown_timer = 0.0

	var after := _state.post_move(delta)
	if not after.is_empty():
		change_state(after)

	nail.physics_update(delta)
	health.post_update(delta)


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
	wall_coyote_timer = 0.0
	horizontal_lock_timer = 0.0
	hazard_grace_timer = 0.0
	dash_cooldown_timer = 0.0
	refill_air_moves()
	nail.cooldown_timer = 0.0
	nail.active_timer = 0.0
	nail.buffer_timer = 0.0
	health.cancel_input()
	change_state(&"fall")
	respawned.emit(at)


## Takes damage from something at `from`: knocked away from it and stunned
## briefly. Returns false if the hit didn't land (invulnerable or dead).
func hurt(amount: int, from: Vector2) -> bool:
	if not health.damage(amount, from):
		return false
	var away := signf(global_position.x - from.x)
	if is_zero_approx(away):
		away = -facing
	velocity = Vector2(away * tuning.hurt_knockback_x, -tuning.hurt_knockback_y)
	if not health.is_dead():
		change_state(&"hurt")
	return true


func can_attack() -> bool:
	return not (state_name in [&"dash", &"hurt", &"focus"]) and not health.is_dead()


## Down-slash bounce: a fixed-height jump that also refreshes air moves and
## the dash cooldown, so pogo chains can mix in dashes and double jumps.
func pogo() -> void:
	hazard_grace_timer = POGO_HAZARD_GRACE
	refill_air_moves()
	dash_cooldown_timer = 0.0
	next_jump_kind = &"pogo"
	change_state(&"jump")


## Side-hit recoil: pushed away from the target with input briefly locked.
func recoil(direction_x: int) -> void:
	velocity.x = direction_x * tuning.recoil_speed
	horizontal_lock_timer = tuning.recoil_time


func refill_air_moves() -> void:
	air_dash_available = true
	double_jump_available = true


## Ground jump: buffered press while on the floor or within coyote time.
func wants_jump() -> bool:
	return jump_buffer_timer > 0.0 and coyote_timer > 0.0


func wants_wall_jump() -> bool:
	return GameState.has_wall_jump and jump_buffer_timer > 0.0 and wall_coyote_timer > 0.0


## Double jump fires on the press itself, never from the buffer, so a press
## just before landing becomes a ground jump instead of wasting it.
func wants_double_jump() -> bool:
	return GameState.has_double_jump and input.jump_pressed and double_jump_available


func wants_dash() -> bool:
	return (GameState.has_dash and input.dash_pressed and dash_cooldown_timer <= 0.0
			and (is_on_floor() or air_dash_available))


## Air-state jump priority: coyote ground jump, then wall jump, then double jump.
## Returns the next state, or &"" for none.
func try_air_jump() -> StringName:
	if wants_jump():
		return start_jump(&"ground")
	if wants_wall_jump():
		return start_jump(&"wall")
	if wants_double_jump():
		return start_jump(&"double")
	return &""


func start_jump(kind: StringName) -> StringName:
	next_jump_kind = kind
	return &"jump"


## Dash toward held input, else the way the player faces.
func begin_dash(direction := 0) -> StringName:
	if direction == 0:
		direction = int(signf(input.move_x)) if not is_zero_approx(input.move_x) else facing
	dash_direction = direction
	input.dash_pressed = false
	return &"dash"


## Touching a wall while falling and holding toward it.
func wants_wall_slide() -> bool:
	if not GameState.has_wall_jump or not is_on_wall_only() or velocity.y < 0.0:
		return false
	var side := int(signf(get_wall_normal().x))
	return side != 0 and int(signf(input.move_x)) == -side


## Also eats this tick's press, so one press can't fire a second jump when
## the new state runs later in the same tick (e.g. ground jump + double jump).
func consume_jump() -> void:
	jump_buffer_timer = 0.0
	coyote_timer = 0.0
	wall_coyote_timer = 0.0
	input.jump_pressed = false


func apply_horizontal(delta: float, accel_time: float, decel_time: float) -> void:
	if horizontal_lock_timer > 0.0:
		return
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
	wall_coyote_timer = maxf(wall_coyote_timer - delta, 0.0)
	horizontal_lock_timer = maxf(horizontal_lock_timer - delta, 0.0)
	dash_cooldown_timer = maxf(dash_cooldown_timer - delta, 0.0)
	hazard_grace_timer = maxf(hazard_grace_timer - delta, 0.0)


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
