extends TestCase
## Checks the graybox course stays traversable: failing a test section must
## never block the sections after it.

const GRAYBOX_SCENE := preload("res://src/world/graybox/graybox.tscn")

var graybox: BlockCourse
var player: Player


func before_each() -> void:
	graybox = GRAYBOX_SCENE.instantiate()
	player = graybox.get_node("Player")
	player.external_input = true
	add_child(graybox)
	await tick()


func test_holding_right_and_jumping_reaches_the_pillars() -> void:
	var pillars_x: float = graybox.sections[1].at.x
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
	for section: Dictionary in graybox.sections:
		player.respawn(section.at + Vector2(0, -4))
		await tick(20)
		assert_true(player.is_on_floor(), "standing at %s spawn" % section.name)


func test_preview_art_toggle_is_visual_only() -> void:
	var skin: CourseSkin = graybox.get_node("CourseSkin")
	var colliders_before := graybox.get_children().filter(func(n: Node) -> bool: return n is StaticBody2D).size()
	var was_enabled := PreviewArt.enabled
	for enabled: bool in [true, false, true]:
		PreviewArt.enabled = enabled
		PreviewArt.changed.emit(enabled)
		await tick(2)
		assert_eq(skin.visible, enabled, "course skin follows the toggle")
		assert_eq(player.get_node("Skin").visible, enabled, "player sprite follows the toggle")
		assert_eq(player.get_node("Visual").visible, not enabled, "placeholder is the opposite")
	var colliders_after := graybox.get_children().filter(func(n: Node) -> bool: return n is StaticBody2D).size()
	assert_eq(colliders_after, colliders_before, "collision untouched")
	PreviewArt.enabled = was_enabled
	PreviewArt.changed.emit(was_enabled)


## M3 exit check: a scripted player clears the pogo chain (lanterns and a
## spiked post over a spike floor) without touching the spikes.
func test_pogo_chain_is_clearable() -> void:
	var targets: Array[Vector2] = []
	for node: Node in get_tree().get_nodes_in_group(&"pogo_lanterns"):
		var lantern := node as TrainingDummy
		if graybox.is_ancestor_of(lantern):
			targets.append(lantern.global_position + Vector2(0, -TrainingDummy.LANTERN_SIZE.y / 2.0))
	# The spiked post: the one hazard that sits above the pit floor.
	for rect: Rect2 in graybox.hazards:
		if rect.position.y < BlockCourse.GROUND_ROW:
			targets.append(Vector2(rect.get_center().x, rect.position.y) * BlockCourse.TILE)
	targets.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	assert_eq(targets.size(), 5, "four lanterns and a spiked post")
	var chain_start: float = targets[0].x - 3 * BlockCourse.TILE
	var last_x: float = targets[targets.size() - 1].x
	var landing_x: float = last_x + 3 * BlockCourse.TILE

	var respawns := [0]
	player.respawned.connect(func(_at: Vector2) -> void: respawns[0] += 1)
	var pogos := [0]
	player.nail.hit.connect(func(_b: Hurtbox, _d: StringName, pogo: bool) -> void:
		if pogo:
			pogos[0] += 1)

	player.respawn(Vector2(chain_start - 64, BlockCourse.GROUND_ROW * BlockCourse.TILE - 2))
	respawns[0] = 0
	await tick(5)
	var next := 0
	var jumped := false
	for i: int in 900:
		var pos := player.global_position
		player.input.jump_pressed = false
		player.input.attack_pressed = false
		var goal_x: float = landing_x if next >= targets.size() else targets[next].x
		var dx: float = goal_x - pos.x
		player.input.move_x = 1.0 if dx > 6.0 else (-1.0 if dx < -6.0 else 0.0)
		player.input.move_y = 1.0
		if not jumped and pos.x >= chain_start - 12.0:
			player.input.jump_pressed = true
			player.input.jump_held = true
			jumped = true
		if next < targets.size() and player.velocity.y > 0.0:
			var gap: float = targets[next].y - pos.y
			if absf(dx) < 20.0 and gap > 0.0 and gap < 44.0 and not player.nail.is_active():
				player.input.attack_pressed = true
		var pogos_before: int = pogos[0]
		await tick()
		if pogos[0] > pogos_before:
			next += 1
		if next >= targets.size() and player.is_on_floor() and pos.x > landing_x - 32.0:
			break
	assert_eq(respawns[0], 0, "never touched the spikes")
	assert_eq(pogos[0], targets.size(), "bounced once off each target")
	assert_true(player.is_on_floor() and player.global_position.x > last_x,
			"landed past the chain (x %.0f)" % player.global_position.x)
