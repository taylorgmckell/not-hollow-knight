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
	# The spiked post: the one hazard between the lanterns raised above the pit floor.
	var lantern_xs := targets.map(func(v: Vector2) -> float: return v.x)
	var chain_left: float = lantern_xs.min()
	var chain_right: float = lantern_xs.max()
	for rect: Rect2 in graybox.hazards:
		var top := Vector2(rect.get_center().x, rect.position.y) * BlockCourse.TILE
		if rect.position.y < BlockCourse.GROUND_ROW and top.x > chain_left and top.x < chain_right:
			targets.append(top)
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


func _health_spikes() -> Rect2:
	var health_x: float = graybox.sections[8].at.x / BlockCourse.TILE
	for rect: Rect2 in graybox.hazards:
		if rect.position.x > health_x and rect.position.y < BlockCourse.GROUND_ROW:
			return rect
	return Rect2()


func test_spikes_cost_a_mask_and_return_to_safe_ground() -> void:
	var spikes := _health_spikes()
	assert_true(spikes.size.x > 0.0, "found the health section's spikes")
	var ground_y := BlockCourse.GROUND_ROW * BlockCourse.TILE - 2.0
	player.respawn(Vector2((spikes.position.x - 3) * BlockCourse.TILE, ground_y))
	await tick(10)
	var safe: Vector2 = graybox.safe_point
	assert_true(safe.x < spikes.position.x * BlockCourse.TILE, "safe point recorded before the spikes")
	var masks_before := player.health.masks
	player.input.move_x = 1.0
	for i: int in 60:
		await tick()
		if player.health.masks < masks_before:
			break
	player.input.move_x = 0.0
	await tick()
	assert_eq(player.health.masks, masks_before - 1, "lost a mask")
	# The safe point follows the player up to a tile short of the spikes.
	var spikes_left := spikes.position.x * BlockCourse.TILE
	assert_true(player.global_position.x >= safe.x and player.global_position.x <= spikes_left - BlockCourse.TILE,
			"back on safe ground at least a tile before the spikes (x %.0f, spikes at %.0f)" % [player.global_position.x, spikes_left])
	assert_true(player.is_on_floor() or player.velocity.y >= 0.0, "standing, not falling into them")


func test_out_of_masks_restarts_the_section() -> void:
	var spikes := _health_spikes()
	graybox._on_section_key(8)
	await tick(5)
	var spawn: Vector2 = graybox.sections[8].at
	player.health.masks = 1
	player.health.soul = 50
	player.respawn(Vector2(spikes.get_center().x * BlockCourse.TILE, 0))
	for i: int in 120:
		await tick()
		if player.health.masks == player.health.max_masks():
			break
	assert_eq(player.health.masks, player.health.max_masks(), "full masks again")
	assert_eq(player.health.soul, 0, "Soul lost on death")
	assert_near(player.global_position.x, spawn.x, 40.0, "back at the section start")
