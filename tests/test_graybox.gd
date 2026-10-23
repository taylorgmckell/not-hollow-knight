extends TestCase
## Checks the graybox course stays traversable: failing a test section must
## never block the sections after it.

const GRAYBOX_SCENE := preload("res://src/world/graybox/graybox.tscn")

var graybox: Node2D
var player: Player


func before_each() -> void:
	graybox = GRAYBOX_SCENE.instantiate()
	player = graybox.get_node("Player")
	player.external_input = true
	add_child(graybox)
	await tick()


func test_holding_right_and_jumping_reaches_the_pillars() -> void:
	var pillars_x: float = graybox._sections[1].at.x
	var resets := 0
	player.input.move_x = 1.0
	player.input.jump_held = true
	for i: int in 1800:
		player.input.jump_pressed = i % 20 == 0
		var before_x := player.global_position.x
		await tick()
		if player.global_position.x < before_x - 64.0:
			resets += 1
		if player.global_position.x >= pillars_x:
			break
	assert_eq(resets, 0, "never sent back to the start")
	assert_true(player.global_position.x >= pillars_x,
			"reached the pillars (x %.0f of %.0f)" % [player.global_position.x, pillars_x])


func test_section_spawns_are_on_solid_ground() -> void:
	for section: Dictionary in graybox._sections:
		player.respawn(section.at + Vector2(0, -4))
		await tick(20)
		assert_true(player.is_on_floor(), "standing at %s spawn" % section.name)
