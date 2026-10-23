extends TestCase
## Runs the real graybox with logging forced on and checks the file it writes.

const GRAYBOX_SCENE := preload("res://src/world/graybox/graybox.tscn")
const LOG_DIR := "user://test_playtests"

var graybox: Node2D
var player: Player
var log_node: PlaytestLog


func before_each() -> void:
	graybox = GRAYBOX_SCENE.instantiate()
	player = graybox.get_node("Player")
	player.external_input = true
	log_node = graybox.get_node("PlaytestLog")
	log_node.log_dir = LOG_DIR
	log_node.record_headless = true
	add_child(graybox)
	await tick()


func after_each() -> void:
	var dir := DirAccess.open(LOG_DIR)
	if dir:
		for file_name: String in dir.get_files():
			dir.remove(file_name)


func _read_entries(path: String) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for line: String in FileAccess.get_file_as_string(path).split("\n", false):
		var parsed: Variant = JSON.parse_string(line)
		assert_true(parsed is Dictionary, "line is a JSON object: %s" % line)
		if parsed is Dictionary:
			entries.append(parsed)
	return entries


func test_records_a_session() -> void:
	var path := log_node.file_path
	assert_true(not path.is_empty(), "log file opened")
	await tick(10)
	player.input.jump_pressed = true
	player.input.jump_held = true
	await tick()
	player.input.jump_pressed = false
	await tick(90)
	player.assists_enabled = false
	await tick()
	graybox.queue_free()
	await get_tree().process_frame

	var entries := _read_entries(path)
	var events: Array = entries.map(func(e: Dictionary) -> String: return e.event)
	assert_eq(events.front(), "session_start", "first event")
	assert_eq(events.back(), "session_end", "last event")
	for expected: String in ["jump", "land", "assists_toggled"]:
		assert_true(events.has(expected), "logged %s (events: %s)" % [expected, events])
	var jump: Dictionary = entries[events.find("jump")]
	assert_eq(jump.section, "gaps", "jump tagged with its section")
	assert_true(jump.has("pos") and jump.has("assists"), "jump has position and assist state")
	assert_true(entries[0].tuning.has("jump_height"), "session_start snapshots tuning")
