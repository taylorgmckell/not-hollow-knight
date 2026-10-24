class_name HurtState
extends PlayerState
## Knocked back after taking damage: no control for `hurt_stun_time`, gravity
## still applies, then back to falling (which lands into idle/run).

var _time := 0.0


func enter() -> void:
	_time = player.tuning.hurt_stun_time


func physics_update(delta: float) -> StringName:
	_time -= delta
	player.apply_gravity(delta)
	if _time <= 0.0:
		return &"fall"
	return &""
