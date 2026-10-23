class_name Hurtbox
extends Area2D
## Something a hitbox can hit. Owners listen to `hurt` (the single damage path
## for enemies, dummies, breakables and later the player).
##
## `pogo` makes a down-slash bounce off it; `takes_damage = false` makes it a
## pure bounce surface (spikes, lanterns).

signal hurt(info: DamageInfo)

## Collision layers from project.godot.
const LAYER_ENEMY_HURTBOX := 1 << 5
const LAYER_HAZARD := 1 << 6

@export var pogo := true
@export var takes_damage := true
## Off while the owner can't be hit (e.g. a broken dummy); hitboxes skip it.
var enabled := true


func _init() -> void:
	monitoring = false
	monitorable = true
	collision_layer = LAYER_ENEMY_HURTBOX
	collision_mask = 0


## Builds a hurtbox with a rectangle shape centred at `center` (local px).
static func make_rect(size: Vector2, center: Vector2, pogo_: bool, takes_damage_: bool) -> Hurtbox:
	var box := Hurtbox.new()
	box.pogo = pogo_
	box.takes_damage = takes_damage_
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	shape.position = center
	box.add_child(shape)
	return box


func receive(info: DamageInfo) -> void:
	hurt.emit(info)
