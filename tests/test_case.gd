class_name TestCase
extends Node
## Base for test suites run by tests/test_runner.tscn.
##
## Methods named `test_*` are run in order, each with a fresh `before_each`.
## Tests may await `tick()` to advance real physics frames. After
## `before_each` the suite sits at the start of a tick, so input set before
## `await tick()` is exactly what that tick processes.

var failures: PackedStringArray = []


func before_each() -> void:
	pass


func after_each() -> void:
	pass


func tick(count := 1) -> void:
	for i: int in count:
		await get_tree().physics_frame


## Adds a solid block given in pixels.
func add_block(rect: Rect2) -> void:
	var body := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = rect.size
	shape.shape = box
	body.position = rect.get_center()
	body.add_child(shape)
	add_child(body)


func assert_true(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		failures.append("%s (expected %s, got %s)" % [message, expected, actual])


func assert_near(actual: float, expected: float, tolerance: float, message: String) -> void:
	if absf(actual - expected) > tolerance:
		failures.append("%s (expected %.2f ± %.2f, got %.2f)" % [message, expected, tolerance, actual])
