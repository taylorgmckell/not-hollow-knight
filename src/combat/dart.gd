class_name Dart
extends ContactDamage
## A projectile that hurts the player on touch. Flies straight, gone on a
## wall, on a hit, or when its lifetime runs out.

const SIZE := Vector2(22, 6)
const WORLD_LAYER := 1
const COLOR := Color(0.92, 0.42, 0.42)

var velocity := Vector2.ZERO
var lifetime := 4.0
var _wall_shape := RectangleShape2D.new()


func _ready() -> void:
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = SIZE
	shape.shape = rect
	add_child(shape)
	_wall_shape.size = SIZE
	hit_player.connect(queue_free)
	z_index = 4


func _physics_process(delta: float) -> void:
	position += velocity * delta
	lifetime -= delta
	if lifetime <= 0.0 or _in_wall():
		queue_free()


func _in_wall() -> bool:
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = _wall_shape
	query.transform = Transform2D(0.0, global_position)
	query.collision_mask = WORLD_LAYER
	return not get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()


func _draw() -> void:
	var dir := signf(velocity.x) if velocity.x != 0.0 else 1.0
	draw_line(Vector2(-dir * SIZE.x / 2.0, 0), Vector2(dir * SIZE.x / 2.0, 0), COLOR, 3.0)
	draw_colored_polygon(PackedVector2Array([
		Vector2(dir * SIZE.x / 2.0 + dir * 6.0, 0), Vector2(dir * SIZE.x / 2.0, -4), Vector2(dir * SIZE.x / 2.0, 4)]), COLOR)
