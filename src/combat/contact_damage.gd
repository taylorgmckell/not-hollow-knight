class_name ContactDamage
extends Area2D
## Hurts the player on touch (thorny dummies, darts, later enemy bodies and
## attacks). The player polls for overlaps each tick, so touching one while
## invulnerable does nothing and touching it again later still counts.

signal hit_player

const LAYER_ENEMY_HITBOX := 1 << 4

@export var damage := 1
## Off while the owner can't hurt (e.g. a broken dummy); the player skips it.
var enabled := true


func _init() -> void:
	monitoring = false
	monitorable = true
	collision_layer = LAYER_ENEMY_HITBOX
	collision_mask = 0


static func make_rect(size: Vector2, center: Vector2, damage_ := 1) -> ContactDamage:
	var zone := ContactDamage.new()
	zone.damage = damage_
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	shape.position = center
	zone.add_child(shape)
	return zone
