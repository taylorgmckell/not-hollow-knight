class_name FocusState
extends PlayerState
## Healing: hold the focus button on the ground. The player can't move, and
## Soul drains over `focus_time` for one mask. Holding on keeps healing while
## there's Soul and missing health. Letting go early, leaving the ground or
## getting hit loses the Soul drained so far (the risk in the risk/reward).

var _time := 0.0


func enter() -> void:
	_time = 0.0
	player.health.focus_progress = 0.0
	player.velocity.x = 0.0


func exit() -> void:
	if _time > 0.0:
		player.health.interrupt_focus(_time / player.tuning.focus_time)
	_time = 0.0
	player.health.focus_progress = 0.0


func physics_update(delta: float) -> StringName:
	var t := player.tuning
	if not player.input.focus_held:
		return &"idle"
	player.velocity.x = 0.0
	player.apply_gravity(delta)
	_time += delta
	player.health.focus_progress = _time / t.focus_time
	if _time >= t.focus_time:
		_time = 0.0
		player.health.focus_progress = 0.0
		player.health.complete_focus()
		if not player.health.can_focus_again():
			return &"idle"
	return &""


func post_move(_delta: float) -> StringName:
	if not player.is_on_floor():
		return &"fall"
	return &""
