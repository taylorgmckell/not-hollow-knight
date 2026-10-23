extends Node
## Hit-stop: freezes the game for a few frames on impactful hits by setting
## Engine.time_scale to 0, then restores it on an unscaled timer. A request
## shorter than the freeze already running is ignored; a longer one replaces it.

signal started(duration: float)

var enabled := true
var _timer: SceneTreeTimer


func freeze(duration: float) -> void:
	if not enabled or duration <= 0.0:
		return
	if _timer and _timer.time_left >= duration:
		return
	started.emit(duration)
	Engine.time_scale = 0.0
	# process_always, ignore_time_scale: this timer keeps running while frozen.
	var timer := get_tree().create_timer(duration, true, false, true)
	_timer = timer
	await timer.timeout
	if _timer == timer:
		_timer = null
		Engine.time_scale = 1.0


func is_frozen() -> bool:
	return Engine.time_scale == 0.0
