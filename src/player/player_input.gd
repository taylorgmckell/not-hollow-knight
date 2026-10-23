class_name PlayerInput
extends RefCounted
## One physics tick of player intent.
##
## Filled from devices during play, or set directly by tests and replays so
## movement can be driven deterministically.

var move_x := 0.0
var move_y := 0.0
var jump_pressed := false
var jump_held := false
var attack_pressed := false
var dash_pressed := false


func read_from_devices() -> void:
	# Digital directions: analog sticks snap to -1/0/1 so speed never depends on tilt.
	move_x = signf(Input.get_axis(&"move_left", &"move_right"))
	move_y = signf(Input.get_axis(&"move_up", &"move_down"))
	jump_pressed = Input.is_action_just_pressed(&"jump")
	jump_held = Input.is_action_pressed(&"jump")
	attack_pressed = Input.is_action_just_pressed(&"attack")
	dash_pressed = Input.is_action_just_pressed(&"dash")


func clear() -> void:
	move_x = 0.0
	move_y = 0.0
	jump_pressed = false
	jump_held = false
	attack_pressed = false
	dash_pressed = false
