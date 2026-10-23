class_name PlayerState
extends RefCounted
## Base for player state machine states.
##
## Each tick the player calls `physics_update` (set velocity, before the move)
## then `post_move` (react to collisions). Either may return the name of the
## next state, or &"" to stay.

var player: Player


func _init(owner: Player) -> void:
	player = owner


func enter() -> void:
	pass


func exit() -> void:
	pass


func physics_update(_delta: float) -> StringName:
	return &""


func post_move(_delta: float) -> StringName:
	return &""
