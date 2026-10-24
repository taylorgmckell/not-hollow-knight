extends TestCase
## The challenge course: lethal hazards, checkpoints, run timing, practice
## mode and the death log.

const CHALLENGE_SCENE := preload("res://src/world/challenge/challenge.tscn")
const LOG_DIR := "user://test_playtests"

var course: BlockCourse
var player: Player
var log_node: PlaytestLog


func before_each() -> void:
	course = CHALLENGE_SCENE.instantiate()
	player = course.get_node("Player")
	player.external_input = true
	log_node = course.get_node("PlaytestLog")
	log_node.log_dir = LOG_DIR
	log_node.record_headless = true
	add_child(course)
	await tick()


func after_each() -> void:
	var dir := DirAccess.open(LOG_DIR)
	if dir:
		for file_name: String in dir.get_files():
			dir.remove(file_name)


func _section_x(section_name: String) -> float:
	for section: Dictionary in course.sections:
		if section.name == section_name:
			return section.at.x
	return NAN


func test_checkpoints_are_on_solid_ground() -> void:
	for section: Dictionary in course.sections:
		player.respawn(section.at + Vector2(0, -4))
		await tick(20)
		assert_true(player.is_on_floor(), "standing at %s checkpoint" % section.name)


func test_every_named_gap_is_a_lethal_pit() -> void:
	# Drop the player into the middle of each labelled gap: it must kill.
	for label: Dictionary in course.labels:
		if not (label.text as String).contains("gap"):
			continue
		var deaths_before: int = course.deaths
		player.respawn(Vector2(label.center_x, 0))
		for i: int in 120:
			await tick()
			if course.deaths > deaths_before:
				break
		assert_eq(course.deaths, deaths_before + 1, "falling into %s kills" % label.text)


func test_spikes_kill_and_respawn_at_checkpoint() -> void:
	player.input.move_x = 1.0
	for i: int in 600:
		await tick()
		if course.deaths > 0:
			break
	assert_eq(course.deaths, 1, "running into the first hazard kills")
	assert_true(player.global_position.x < 4 * BlockCourse.TILE, "respawned at the start checkpoint")


func test_run_clock_starts_when_leaving_start() -> void:
	assert_eq(course.run_state, 0, "ready before moving")
	player.input.move_x = 1.0
	await tick(30)
	assert_eq(course.run_state, 1, "running after leaving the start")
	assert_true(course.run_time > 0.0, "clock running")


func test_reaching_the_finish_ends_the_run() -> void:
	var finished: Array = []
	course.run_finished.connect(func(time: float, deaths: int, practice: bool) -> void:
		finished.append([time, deaths, practice]))
	# Start the run legitimately, then place the player just before the finish.
	player.input.move_x = 1.0
	await tick(30)
	player.input.move_x = 0.0
	course.checkpoint_index = course.sections.size() - 1
	player.respawn(Vector2(232 * BlockCourse.TILE, BlockCourse.GROUND_ROW * BlockCourse.TILE - 4))
	await tick(20)
	assert_eq(finished.size(), 1, "run_finished emitted once")
	if finished.size() == 1:
		assert_eq(finished[0][2], false, "not a practice run")
		assert_eq(course.run_state, 2, "finished state")


func test_checkpoint_key_marks_practice() -> void:
	course._on_section_key(3)
	await tick(5)
	assert_true(course.practice, "practice run")
	assert_near(player.global_position.x, _section_x("walls"), 1.0, "moved to the walls checkpoint")


func test_restart_clears_the_run() -> void:
	player.input.move_x = 1.0
	await tick(30)
	course.deaths = 3
	course.restart_run()
	assert_eq(course.deaths, 0, "deaths reset")
	assert_eq(course.run_time, 0.0, "clock reset")
	assert_eq(course.run_number, 2, "next run")


func test_death_is_logged_with_context() -> void:
	var path := log_node.file_path
	player.respawn(Vector2(14 * BlockCourse.TILE, 0))
	for i: int in 120:
		await tick()
		if course.deaths > 0:
			break
	course.queue_free()
	await get_tree().process_frame
	var deaths: Array = []
	for line: String in FileAccess.get_file_as_string(path).split("\n", false):
		var entry: Variant = JSON.parse_string(line)
		if entry is Dictionary and entry.event == "death":
			deaths.append(entry)
	assert_eq(deaths.size(), 1, "one death logged")
	if deaths.size() == 1:
		assert_eq(deaths[0].cause, "pit", "cause")
		assert_eq(deaths[0].feature, "gap 4", "tagged with the gap")
		assert_true(deaths[0].has("since_last_bonk_s"), "bonk context included")


## Playtest finding: a down-slash can connect on the same tick the falling body
## sinks into spikes. The pogo must still save the player.
func test_late_pogo_off_spikes_is_not_a_death() -> void:
	var spike_top := (BlockCourse.GROUND_ROW - 0.5) * BlockCourse.TILE
	var feet_at_hit := [NAN]
	player.nail.hit.connect(func(_b: Hurtbox, _d: StringName, pogo: bool) -> void:
		if pogo:
			feet_at_hit[0] = player.global_position.y)
	player.respawn(Vector2(46 * BlockCourse.TILE, 0))
	player.input.move_y = 1.0
	for i: int in 120:
		await tick()
		# As late as possible: the slash only connects after this tick's fall.
		if player.velocity.y > 0.0 and spike_top - player.global_position.y < player.velocity.y / 60.0:
			break
	player.input.attack_pressed = true
	await tick()
	player.input.attack_pressed = false
	await tick(10)
	assert_true(feet_at_hit[0] > spike_top, "the slash connected with the body already in the spikes (feet %.1f, spikes %.1f)" % [feet_at_hit[0], spike_top])
	assert_eq(player.last_jump_kind, &"pogo", "bounced")
	assert_eq(course.deaths, 0, "a pogo that connects isn't a death")


func test_death_restores_health() -> void:
	player.health.masks = 2
	player.respawn(Vector2(14 * BlockCourse.TILE, 0))
	for i: int in 120:
		await tick()
		if course.deaths > 0:
			break
	assert_eq(course.deaths, 1, "fell in a pit")
	assert_eq(player.health.masks, player.health.max_masks(), "full masks at the checkpoint")
