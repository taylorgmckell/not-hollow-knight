class_name SoulBolt
extends Node2D
## The spell: a fast bolt of Soul that flies straight, pierces through every
## target in its path (each hit once) and stops at walls.

const SIZE := Vector2(40, 24)
const LIFETIME := 1.0
const WORLD_LAYER := 1
const COLOR := Color(0.85, 0.95, 1.0)

var direction := 1
var speed := 900.0
var damage := 3
var knockback := 300.0
var _life := LIFETIME
var _hit: Array[Hurtbox] = []
var _shape := RectangleShape2D.new()


func _ready() -> void:
	_shape.size = SIZE
	z_index = 6


func _physics_process(delta: float) -> void:
	position.x += direction * speed * delta
	_life -= delta
	if _life <= 0.0 or _overlaps(WORLD_LAYER, false).size() > 0:
		queue_free()
		return
	for result: Dictionary in _overlaps(Hurtbox.LAYER_ENEMY_HURTBOX, true):
		var box := result.collider as Hurtbox
		if box == null or not box.enabled or not box.takes_damage or _hit.has(box):
			continue
		_hit.append(box)
		box.receive(DamageInfo.make(damage, global_position, Vector2(direction, 0), knockback, &"spell"))
		HitStop.freeze(0.03)
		Sfx.play(&"hit")
	queue_redraw()


func _overlaps(mask: int, areas: bool) -> Array[Dictionary]:
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = _shape
	query.transform = Transform2D(0.0, global_position)
	query.collide_with_areas = areas
	query.collide_with_bodies = not areas
	query.collision_mask = mask
	return get_world_2d().direct_space_state.intersect_shape(query, 16)


func _draw() -> void:
	var fade := clampf(_life / 0.2, 0.0, 1.0)
	for i: int in 4:
		var color := COLOR
		color.a = (0.9 - i * 0.2) * fade
		draw_circle(Vector2(-direction * i * 9.0, 0), SIZE.y / 2.0 - i * 2.0, color)
