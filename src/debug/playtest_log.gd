class_name PlaytestLog
extends Node
## Records a playtest session as JSON Lines, one file per run, so it can be
## reviewed afterwards. Files land in user://playtests/ (on Windows:
## %APPDATA%\Godot\app_userdata\not-hollow-knight\playtests\).
##
## Every line has: t (seconds), event, assists and abilities (on/off), pos,
## plus section and feature when a course provides
## `describe(position) -> Dictionary`.
## Events: session_start, jump (with kind: ground/wall/double), dash,
## wall_grab, land, bonk, assist, respawn, assists_toggled, abilities_toggled,
## tuning, attack (direction), nail_hit (target, direction, pogo),
## hurt (amount, masks left), out_of_masks, heal, focus_interrupted (soul lost),
## cast, session_end. On the challenge course also: run_start, run_finish,
## run_abandon, checkpoint, and death (with cause and what happened just
## before it, to judge whether the controls were at fault).
## Each line is flushed so a killed run keeps its data.

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
var _abilities_enabled := false
var _tuning_changed_at := -1.0
var _last_bonk_at := -INF
var _last_jump_at := -INF
var _last_jump_kind := ""


func _ready() -> void:
	if not player or (DisplayServer.get_name() == "headless" and not record_headless):
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(log_dir))
	# Milliseconds too: switching courses (F6) can start two sessions in one second.
	var stamp := "%s-%03d" % [Time.get_datetime_string_from_system().replace(":", "-"),
			Time.get_ticks_msec() % 1000]
	file_path = "%s/%s.jsonl" % [log_dir, stamp]
	_file = FileAccess.open(file_path, FileAccess.WRITE)
	if not _file:
		push_warning("Playtest log: can't write %s (%s)" % [file_path, error_string(FileAccess.get_open_error())])
		return
	_start_ms = Time.get_ticks_msec()
	_assists_enabled = player.assists_enabled
	_abilities_enabled = GameState.has_dash
	player.bonked.connect(func() -> void:
		_last_bonk_at = _now()
		_record("bonk"))
	player.assisted.connect(func(kind: StringName, nudge: Vector2) -> void:
		_record("assist", {kind = kind, nudge_px = roundi(nudge.length())}))
	player.respawned.connect(func(_at: Vector2) -> void: _record("respawn"))
	player.state_changed.connect(_on_player_state_changed)
	player.nail.swung.connect(func(direction: StringName) -> void:
		_record("attack", {direction = direction}))
	player.nail.hit.connect(func(box: Hurtbox, direction: StringName, pogo: bool) -> void:
		_record("nail_hit", {target = _target_kind(box), direction = direction, pogo = pogo}))
	var health := player.health
	health.damaged.connect(func(amount: int, _from: Vector2) -> void:
		_record("hurt", {amount = amount, masks = health.masks, soul = health.soul}))
	health.died.connect(func() -> void: _record("out_of_masks"))
	health.healed.connect(func() -> void: _record("heal", {masks = health.masks, soul = health.soul}))
	health.focus_interrupted.connect(func(lost: int) -> void:
		_record("focus_interrupted", {soul_lost = lost, soul = health.soul}))
	health.spell_cast.connect(func() -> void: _record("cast", {soul = health.soul}))
	player.tuning.changed.connect(func() -> void: _tuning_changed_at = _now())
	_connect_course()
	var course_name := String(course.name) if course else ""
	_record("session_start", {course = course_name, tuning = _tuning_snapshot(), godot = Engine.get_version_info().string})
	print("Playtest log: %s" % ProjectSettings.globalize_path(file_path))


func _physics_process(_delta: float) -> void:
	if not _file:
		return
	if player.assists_enabled != _assists_enabled:
		_assists_enabled = player.assists_enabled
		_record("assists_toggled")
	if GameState.has_dash != _abilities_enabled:
		_abilities_enabled = GameState.has_dash
		_record("abilities_toggled")
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
		_last_jump_at = _now()
		_last_jump_kind = player.last_jump_kind
		_record("jump", {kind = player.last_jump_kind})
	elif to == &"dash":
		_record("dash", {direction = player.dash_direction})
	elif to == &"wall_slide":
		_record("wall_grab")
	elif from in [&"jump", &"fall", &"dash", &"wall_slide"] and (to == &"idle" or to == &"run"):
		_record("land")


static func _target_kind(box: Hurtbox) -> String:
	var dummy := box.get_parent() as TrainingDummy
	if dummy:
		return "lantern" if dummy.lantern else "dummy"
	return "spikes" if not box.takes_damage else "other"


## Hooks up the challenge course's signals when the course has them.
func _connect_course() -> void:
	if not course or not course.has_signal(&"died"):
		return
	course.died.connect(func(cause: String) -> void:
		_record("death", {
			cause = cause,
			run = course.run_number,
			deaths_this_run = course.deaths,
			last_jump_kind = _last_jump_kind,
			since_last_jump_s = snappedf(_now() - _last_jump_at, 0.01),
			since_last_bonk_s = snappedf(_now() - _last_bonk_at, 0.01),
		}))
	course.checkpoint_reached.connect(func(checkpoint_name: String) -> void:
		_record("checkpoint", {checkpoint = checkpoint_name, run = course.run_number}))
	course.run_started.connect(func() -> void:
		_record("run_start", {run = course.run_number, practice = course.practice}))
	course.run_finished.connect(func(time: float, deaths: int, practice: bool) -> void:
		_record("run_finish", {run = course.run_number, time_s = snappedf(time, 0.01), deaths = deaths, practice = practice}))
	course.run_abandoned.connect(func(time: float, deaths: int) -> void:
		_record("run_abandon", {run = course.run_number, time_s = snappedf(time, 0.01), deaths = deaths}))


func _record(event: String, extra: Dictionary = {}) -> void:
	_counts[event] = _counts.get(event, 0) + 1
	var pos := player.global_position
	var entry := {
		t = snappedf(_now(), 0.01),
		event = event,
		assists = player.assists_enabled,
		abilities = GameState.has_dash,
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
