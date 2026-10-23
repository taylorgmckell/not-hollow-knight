class_name PlaytestLog
extends Node
## Records a playtest session as JSON Lines, one file per run, so it can be
## reviewed afterwards. Files land in user://playtests/ (on Windows:
## %APPDATA%\Godot\app_userdata\not-hollow-knight\playtests\).
##
## Every line has: t (seconds), event, assists (on/off), pos, plus section and
## feature when a course provides `describe(position) -> Dictionary`.
## Events: session_start, jump, land, bonk, assist, respawn, assists_toggled,
## tuning, session_end. Each line is flushed so a killed run keeps its data.

## Live tuning changes are logged once they settle for this long.
const TUNING_SETTLE_TIME := 1.0

@export var player: Player
## Optional course that tags positions, e.g. the graybox.
@export var course: Node
@export var log_dir := "user://playtests"
## Off by default so headless test runs don't litter the log folder.
@export var record_headless := false

var file_path := ""
var _file: FileAccess
var _start_ms := 0
var _counts: Dictionary[String, int] = {}
var _assists_enabled := true
var _tuning_changed_at := -1.0


func _ready() -> void:
	if not player or (DisplayServer.get_name() == "headless" and not record_headless):
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(log_dir))
	var stamp := Time.get_datetime_string_from_system().replace(":", "-")
	file_path = "%s/%s.jsonl" % [log_dir, stamp]
	_file = FileAccess.open(file_path, FileAccess.WRITE)
	if not _file:
		push_warning("Playtest log: can't write %s (%s)" % [file_path, error_string(FileAccess.get_open_error())])
		return
	_start_ms = Time.get_ticks_msec()
	_assists_enabled = player.assists_enabled
	player.bonked.connect(_record.bind("bonk"))
	player.assisted.connect(func(kind: StringName, nudge: Vector2) -> void:
		_record("assist", {kind = kind, nudge_px = roundi(nudge.length())}))
	player.respawned.connect(func(_at: Vector2) -> void: _record("respawn"))
	player.state_changed.connect(_on_player_state_changed)
	player.tuning.changed.connect(func() -> void: _tuning_changed_at = _now())
	_record("session_start", {tuning = _tuning_snapshot(), godot = Engine.get_version_info().string})
	print("Playtest log: %s" % ProjectSettings.globalize_path(file_path))


func _physics_process(_delta: float) -> void:
	if not _file:
		return
	if player.assists_enabled != _assists_enabled:
		_assists_enabled = player.assists_enabled
		_record("assists_toggled")
	if _tuning_changed_at >= 0.0 and _now() - _tuning_changed_at > TUNING_SETTLE_TIME:
		_tuning_changed_at = -1.0
		_record("tuning", {tuning = _tuning_snapshot()})


func _exit_tree() -> void:
	if _file:
		# The player may already be out of the tree, so skip position tagging.
		_file.store_line(JSON.stringify({t = snappedf(_now(), 0.01), event = "session_end", counts = _counts}))
		_file.close()
		_file = null


func _on_player_state_changed(from: StringName, to: StringName) -> void:
	if to == &"jump":
		_record("jump")
	elif (from == &"jump" or from == &"fall") and (to == &"idle" or to == &"run"):
		_record("land")


func _record(event: String, extra: Dictionary = {}) -> void:
	_counts[event] = _counts.get(event, 0) + 1
	var pos := player.global_position
	var entry := {
		t = snappedf(_now(), 0.01),
		event = event,
		assists = player.assists_enabled,
		pos = [roundi(pos.x), roundi(pos.y)],
	}
	if course and course.has_method(&"describe"):
		entry.merge(course.describe(pos))
	entry.merge(extra, true)
	_file.store_line(JSON.stringify(entry))
	_file.flush()


func _now() -> float:
	return (Time.get_ticks_msec() - _start_ms) / 1000.0


func _tuning_snapshot() -> Dictionary:
	var values := {}
	for prop: Dictionary in player.tuning.get_property_list():
		if prop.usage & PROPERTY_USAGE_EDITOR and prop.hint == PROPERTY_HINT_RANGE:
			values[prop.name] = player.tuning.get(prop.name)
	return values
