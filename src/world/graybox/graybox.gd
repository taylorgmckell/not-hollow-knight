extends BlockCourse
## Movement measuring course built from measured blocks.
##
## Gaps and pillar heights step up one tile at a time so jump reach can be read
## straight off the labels. Measured reach is recorded in docs/metrics.md.
## Failing is cheap here on purpose: impossible gaps drop into climb-out pits.
## The challenge course (F6) is where deaths count.

## Depth of the pits under the gaps, in tiles. Shallow enough to jump out of.
const PIT_DEPTH := 2

var _spawn_point := Vector2.ZERO


func _course_ready() -> void:
	_spawn_point = sections[0].at
	player.global_position = _spawn_point


func _course_physics(_delta: float) -> void:
	if player.global_position.y > KILL_Y or Input.is_action_just_pressed(&"debug_reset"):
		player.respawn(_spawn_point)


func _on_section_key(index: int) -> void:
	_spawn_point = sections[index].at
	player.respawn(_spawn_point)


func controls_hint() -> String:
	return "\n".join([
		"F1 overlay   F2 tuning   F3 assists   F4 abilities   F6 challenge   F7/touchpad art   R/Options reset",
		"1 gaps   2 pillars   3 corner   4 ledge   5 dash   6 walls   7 double jump",
	])


func build() -> void:
	var x := 0.0
	# Left wall and start area.
	add_block(Rect2(-2, 0, 2, GROUND_ROW + 4))
	add_block(Rect2(0, GROUND_ROW, 10, 4))
	x = 10.0

	# Gaps: 2..9 tiles. Current reach for each is in docs/metrics.md.
	add_section("gaps", 3)
	x = _add_gap_run(x, range(2, 10), "gap")

	# Pillars: 1..5 tiles tall on continuous ground.
	add_section("pillars", x + 1)
	var ground_start := x
	for height: int in range(1, 6):
		x += 4
		add_block(Rect2(x, GROUND_ROW - height, 3, height))
		add_label(x + 1.5, GROUND_ROW - height - 1, "h %d" % height)
		x += 3

	# Corner correction: two places where jumping a moment early clips a
	# ceiling corner. Without the assist that's a bonk; with it, a small slide
	# past the edge. Compare the bonk count in the F1 overlay with F3 on and off.
	x += 5
	add_section("corner", x + 1)
	# Overhang: a low ceiling (2 tiles clear) to run out from under and jump.
	add_block(Rect2(x, GROUND_ROW - 3, 8, 1))
	add_label(x + 4, GROUND_ROW - 4, "overhang: jump as you leave")
	x += 8 + 5
	# Floating platform: approach from the left and jump up onto it late.
	add_block(Rect2(x, GROUND_ROW - 4, 4, 1))
	add_label(x + 2, GROUND_ROW - 5, "platform: jump up from close")
	x += 4 + 6

	# Ledge forgiveness: the top sits half the assist limit above the jump peak,
	# so you only make it with the assist. Follows tuning at scene load.
	add_section("ledge", x - 4)
	var tuning := player.tuning
	var ledge_height := (tuning.jump_height + tuning.ledge_forgiveness / 2.0) / TILE
	add_block(Rect2(x, GROUND_ROW - ledge_height, 8, ledge_height))
	add_label(x + 4, GROUND_ROW - ledge_height - 1, "ledge: just out of reach")
	x += 8

	add_block(Rect2(ground_start, GROUND_ROW, x + 6 - ground_start, 4))
	x += 6

	# --- M2 abilities (all unlocked in the graybox; F4 toggles them) ---

	# Dash gaps: wider than any plain jump. Jump, then dash at the top.
	add_section("dash", x - 3)
	x = _add_gap_run(x, [10, 12, 14, 16], "dash gap")

	# Wall shaft: two walls 4 tiles apart, 12 tall. Walk in under the left
	# wall, climb by wall jumping side to side, then step onto the right wall.
	ground_start = x
	x += 6
	add_section("walls", x - 3)
	add_block(Rect2(x, GROUND_ROW - 12, 2, 10))
	add_block(Rect2(x + 6, GROUND_ROW - 12, 2, 12))
	add_label(x + 4, GROUND_ROW - 13, "shaft: wall jump up")
	x += 8 + 6
	# Single wall: climbing it needs repeated jumps off the same face.
	add_block(Rect2(x, GROUND_ROW - 10, 3, 10))
	add_label(x + 1.5, GROUND_ROW - 11, "single wall")
	x += 3 + 6

	# Double jump pillars: past what one jump reaches.
	add_section("double jump", x - 2)
	for height: int in range(7, 12):
		x += 4
		add_block(Rect2(x, GROUND_ROW - height, 3, height))
		add_label(x + 1.5, GROUND_ROW - height - 1, "h %d" % height)
		x += 3
	x += 6
	add_block(Rect2(ground_start, GROUND_ROW, x - ground_start, 4))

	# Right wall, tall enough to hold in the abilities area.
	add_block(Rect2(x, GROUND_ROW - 16, 2, 20))


## Platforms separated by labelled gaps, over one shallow pit. Missing a gap
## costs a climb out, not the run. Returns the x after the last platform.
func _add_gap_run(x: float, gaps: Array, label_prefix: String) -> float:
	var start := x
	for gap: int in gaps:
		add_label(x + gap / 2.0, GROUND_ROW - 1, "%s %d" % [label_prefix, gap])
		x += gap
		add_block(Rect2(x, GROUND_ROW, 5, 4))
		x += 5
	add_block(Rect2(start, GROUND_ROW + PIT_DEPTH, x - start, 4 - PIT_DEPTH))
	return x
