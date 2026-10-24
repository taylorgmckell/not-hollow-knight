extends BlockCourse
## Acceptance course for movement (M1 + M2). Unlike the graybox, failing here
## counts: pits and spikes kill and send you back to the last checkpoint.
##
## Every obstacle is inside the *comfortable* range in docs/metrics.md, so a
## death is a signal: either the controls let the player down, or the
## comfortable numbers are wrong. Done-check: a clean run (no deaths) and no
## death in the playtest log attributable to the controls.
##
## R restarts the run. Number keys jump to a checkpoint for practice; that run
## is marked PRACTICE and doesn't count.

signal run_started
signal run_finished(time: float, deaths: int, practice: bool)
signal run_abandoned(time: float, deaths: int)
signal died(cause: String)
signal checkpoint_reached(checkpoint_name: String)

enum RunState { READY, RUNNING, FINISHED }

## Below this the player is dead (pits have no floor).
const DEATH_Y := (GROUND_ROW + 6) * TILE

var run_state := RunState.READY
var run_number := 1
var run_time := 0.0
var deaths := 0
var practice := false
var checkpoint_index := 0
var best_clean_time := -1.0
var _finish_x := 0.0
var _hud := Label.new()


func controls_hint() -> String:
	return "\n".join([
		"F1 overlay   F2 tuning   F3 assists   F6 graybox   F7/touchpad art   R/Options restart run",
		"1-6 practice from a checkpoint (run won't count)",
	])


func _course_ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 40
	_hud.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_hud.offset_left = -560
	_hud.offset_right = -16
	_hud.offset_top = 16
	_hud.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hud.add_theme_font_size_override(&"font_size", 26)
	_hud.add_theme_color_override(&"font_outline_color", Color.BLACK)
	_hud.add_theme_constant_override(&"outline_size", 5)
	layer.add_child(_hud)
	add_child(layer)
	restart_run()


func _course_physics(delta: float) -> void:
	if Input.is_action_just_pressed(&"debug_reset"):
		if run_state == RunState.RUNNING:
			run_abandoned.emit(run_time, deaths)
		restart_run()
		return

	if run_state == RunState.READY and player.global_position.x > sections[0].at.x + 2 * TILE:
		run_state = RunState.RUNNING
		run_started.emit()
	if run_state == RunState.RUNNING:
		run_time += delta

	if touching_hazard():
		_die("spikes")
	elif player.global_position.y > DEATH_Y:
		_die("pit")

	if player.is_on_floor():
		_check_checkpoints()
		if run_state == RunState.RUNNING and player.global_position.x >= _finish_x:
			_finish()
	_update_hud()


func _on_section_key(index: int) -> void:
	if run_state == RunState.FINISHED:
		restart_run()
	practice = true
	if run_state == RunState.READY:
		run_state = RunState.RUNNING
		run_started.emit()
	checkpoint_index = index
	player.respawn(sections[index].at)


func restart_run() -> void:
	if run_state != RunState.READY or run_time > 0.0:
		run_number += 1
	run_state = RunState.READY
	run_time = 0.0
	deaths = 0
	practice = false
	checkpoint_index = 0
	player.health.restore(true)
	player.respawn(sections[0].at)


func _die(cause: String) -> void:
	deaths += 1
	died.emit(cause)
	# Movement test: any death is a clean restart from the checkpoint.
	player.health.restore(false)
	player.respawn(sections[checkpoint_index].at)


func _on_player_died() -> void:
	_die("damage")


func _check_checkpoints() -> void:
	var x := player.global_position.x
	for i: int in range(checkpoint_index + 1, sections.size()):
		if x >= sections[i].at.x - TILE:
			checkpoint_index = i
			checkpoint_reached.emit(sections[i].name)


func _finish() -> void:
	run_state = RunState.FINISHED
	if not practice and deaths == 0 and (best_clean_time < 0.0 or run_time < best_clean_time):
		best_clean_time = run_time
	run_finished.emit(run_time, deaths, practice)


func _update_hud() -> void:
	var lines := PackedStringArray()
	var status := "PRACTICE" if practice else "Run %d" % run_number
	lines.append("%s   %s   deaths %d" % [status, _format_time(run_time), deaths])
	lines.append("checkpoint: %s" % sections[checkpoint_index].name)
	if best_clean_time >= 0.0:
		lines.append("best clean run %s" % _format_time(best_clean_time))
	match run_state:
		RunState.READY:
			lines.append("Run right to start the clock")
		RunState.FINISHED:
			var verdict := "CLEAN RUN!" if deaths == 0 and not practice else "Finished"
			lines.append("%s  R to run again" % verdict)
	_hud.text = "\n".join(lines)


static func _format_time(seconds: float) -> String:
	return "%d:%04.1f" % [floori(seconds / 60.0), fmod(seconds, 60.0)]


func build() -> void:
	# Walls at both ends. Pits have no floor: falling in is a death.
	add_block(Rect2(-2, -10, 2, 24))

	# 1. Basics: plain jumps (gaps up to 7), a spike strip and a 5-tile step.
	add_section("start", 3)
	add_block(Rect2(0, GROUND_ROW, 12, 4))
	_gap(12, 4, "gap 4")
	add_block(Rect2(16, GROUND_ROW, 5, 4))
	_gap(21, 6, "gap 6")
	add_block(Rect2(27, GROUND_ROW, 5, 4))
	_gap(32, 7, "gap 7")
	add_block(Rect2(39, GROUND_ROW, 21, 4))
	add_hazard(Rect2(44, GROUND_ROW - 0.5, 4, 0.5))
	add_label(46, GROUND_ROW - 2, "spikes")
	add_block(Rect2(52, GROUND_ROW - 5, 4, 5))
	add_label(54, GROUND_ROW - 6, "step 5")

	# 2. Corners: jump a pit as you leave a low overhang, then climb floating
	# platforms over a pit from below their edges.
	add_section("corner", 58)
	add_block(Rect2(60, GROUND_ROW, 12, 4))
	# Ends a tile before the pit, so a jump at the edge is clean and the
	# corner assist covers jumps a little early.
	add_block(Rect2(63, GROUND_ROW - 3, 8, 1))
	add_label(67, GROUND_ROW - 4, "overhang")
	_gap(72, 5, "overhang gap")
	add_block(Rect2(77, GROUND_ROW, 6, 4))
	add_block(Rect2(86, GROUND_ROW - 4, 3, 1))
	add_block(Rect2(92, GROUND_ROW - 7, 3, 1))
	add_label(90, GROUND_ROW - 9, "platforms")
	add_block(Rect2(98, GROUND_ROW - 4, 8, 8))
	add_block(Rect2(106, GROUND_ROW, 6, 4))

	# 3. Dash: gaps of 10 and 12 (comfortable with jump + dash).
	add_section("dash", 109)
	_gap(112, 10, "dash gap 10")
	add_block(Rect2(122, GROUND_ROW, 5, 4))
	_gap(127, 12, "dash gap 12")
	add_block(Rect2(139, GROUND_ROW, 8, 4))

	# 4. Walls: climb a 12-tall shaft, then a 6-tile running jump from the
	# 2-wide wall top to a high block, over a pit.
	add_section("walls", 144)
	add_block(Rect2(147, GROUND_ROW, 13, 4))
	add_block(Rect2(152, GROUND_ROW - 12, 2, 10))
	add_block(Rect2(158, GROUND_ROW - 12, 2, 12))
	add_label(156, GROUND_ROW - 13, "shaft")
	_gap(160, 6, "high gap 6", GROUND_ROW - 13)
	add_block(Rect2(166, GROUND_ROW - 12, 6, 16))
	add_block(Rect2(172, GROUND_ROW, 8, 4))

	# 5. Double jump: a 9-tile tower, then a 12-tile gap at the top.
	add_section("double jump", 176)
	add_block(Rect2(180, GROUND_ROW, 2, 4))
	add_block(Rect2(182, GROUND_ROW - 9, 5, 13))
	add_label(184.5, GROUND_ROW - 10, "tower 9")
	_gap(187, 12, "high gap 12", GROUND_ROW - 10)
	add_block(Rect2(199, GROUND_ROW - 9, 6, 13))
	add_block(Rect2(205, GROUND_ROW, 6, 4))

	# 6. Finale: a 16-tile gap needing jump + double jump + dash.
	add_section("finale", 208)
	_gap(211, 16, "gap 16")
	add_block(Rect2(227, GROUND_ROW, 10, 4))
	_finish_x = 231 * TILE
	add_label(231, GROUND_ROW - 2, "FINISH")
	add_block(Rect2(237, -10, 2, 24))


## Labels a pit gap (no floor) by its centre.
func _gap(start: float, width: float, text: String, label_row: float = GROUND_ROW - 1) -> void:
	add_label(start + width / 2.0, label_row, text)
