extends Node2D
## Movement test course built from measured blocks.
##
## Gaps and pillar heights step up one tile at a time so jump reach can be read
## straight off the labels. Measured reach is recorded in docs/metrics.md.

const TILE := 32
const GROUND_ROW := 10
const KILL_Y := 30 * TILE
const BLOCK_COLOR := Color(0.32, 0.34, 0.4)
const LABEL_COLOR := Color(0.75, 0.78, 0.85)
const LABEL_WIDTH := 240.0
## Depth of the pits under the gaps, in tiles. Shallow enough to jump out of.
const PIT_DEPTH := 2
## How far from a label (in tiles) an event still counts as at that feature.
const FEATURE_RADIUS := 6.0
const SECTION_ACTIONS: Array[StringName] = [
	&"debug_section_1", &"debug_section_2", &"debug_section_3", &"debug_section_4",
	&"debug_section_5", &"debug_section_6", &"debug_section_7",
]

## Course blocks in tile units (fractions allowed). Built in _ready.
var _blocks: Array[Rect2] = []
var _labels: Array[Dictionary] = []
## Each: {name, at}. Keys 1-7 jump to them; R and falling out return to the last one.
var _sections: Array[Dictionary] = []
var _spawn_point := Vector2.ZERO

@onready var _player: Player = $Player


func _enter_tree() -> void:
	# Before children's _ready, so the playtest log starts with abilities on.
	GameState.set_all_abilities(true)


func _ready() -> void:
	_build_course()
	for rect: Rect2 in _blocks:
		_add_collider(rect)
	_spawn_point = _sections[0].at
	_player.global_position = _spawn_point
	queue_redraw()


func _physics_process(_delta: float) -> void:
	for i: int in mini(SECTION_ACTIONS.size(), _sections.size()):
		if Input.is_action_just_pressed(SECTION_ACTIONS[i]):
			_spawn_point = _sections[i].at
			_player.respawn(_spawn_point)
	if _player.global_position.y > KILL_Y or Input.is_action_just_pressed(&"debug_reset"):
		_player.respawn(_spawn_point)


func _draw() -> void:
	for rect: Rect2 in _blocks:
		draw_rect(Rect2(rect.position * TILE, rect.size * TILE), BLOCK_COLOR)
	var font := ThemeDB.fallback_font
	for label: Dictionary in _labels:
		draw_string(font, label.at, label.text, HORIZONTAL_ALIGNMENT_CENTER, LABEL_WIDTH, 18, LABEL_COLOR)


func _build_course() -> void:
	var x := 0.0
	# Left wall and start area.
	_blocks.append(Rect2(-2, 0, 2, GROUND_ROW + 4))
	_blocks.append(Rect2(0, GROUND_ROW, 10, 4))
	x = 10.0

	# Gaps: 2..9 tiles. Current reach for each is in docs/metrics.md. They are
	# shallow pits, so missing one costs a climb out, not the run.
	_add_section("gaps", 3)
	x = _add_gap_run(x, range(2, 10), "gap")

	# Pillars: 1..5 tiles tall on continuous ground.
	_add_section("pillars", x + 1)
	var ground_start := x
	for height: int in range(1, 6):
		x += 4
		_blocks.append(Rect2(x, GROUND_ROW - height, 3, height))
		_label(x + 1.5, GROUND_ROW - height - 1, "h %d" % height)
		x += 3

	# Corner correction: two places where jumping a moment early clips a
	# ceiling corner. Without the assist that's a bonk; with it, a small slide
	# past the edge. Compare the bonk count in the F1 overlay with F3 on and off.
	x += 5
	_add_section("corner", x + 1)
	# Overhang: a low ceiling (2 tiles clear) to run out from under and jump.
	_blocks.append(Rect2(x, GROUND_ROW - 3, 8, 1))
	_label(x + 4, GROUND_ROW - 4, "overhang: jump as you leave")
	x += 8 + 5
	# Floating platform: approach from the left and jump up onto it late.
	_blocks.append(Rect2(x, GROUND_ROW - 4, 4, 1))
	_label(x + 2, GROUND_ROW - 5, "platform: jump up from close")
	x += 4 + 6

	# Ledge forgiveness: the top sits half the assist limit above the jump peak,
	# so you only make it with the assist. Follows tuning at scene load.
	_add_section("ledge", x - 4)
	var tuning := _player.tuning
	var ledge_height := (tuning.jump_height + tuning.ledge_forgiveness / 2.0) / TILE
	_blocks.append(Rect2(x, GROUND_ROW - ledge_height, 8, ledge_height))
	_label(x + 4, GROUND_ROW - ledge_height - 1, "ledge: just out of reach")
	x += 8

	_blocks.append(Rect2(ground_start, GROUND_ROW, x + 6 - ground_start, 4))
	x += 6

	# --- M2 abilities (all unlocked in the graybox; F4 toggles them) ---

	# Dash gaps: wider than any plain jump. Jump, then dash at the top.
	_add_section("dash", x - 3)
	x = _add_gap_run(x, [10, 12, 14, 16], "dash gap")

	# Wall shaft: two walls 4 tiles apart, 12 tall. Walk in under the left
	# wall, climb by wall jumping side to side, then step onto the right wall.
	ground_start = x
	x += 6
	_add_section("walls", x - 3)
	_blocks.append(Rect2(x, GROUND_ROW - 12, 2, 10))
	_blocks.append(Rect2(x + 6, GROUND_ROW - 12, 2, 12))
	_label(x + 4, GROUND_ROW - 13, "shaft: wall jump up")
	x += 8 + 6
	# Single wall: climbing it needs repeated jumps off the same face.
	_blocks.append(Rect2(x, GROUND_ROW - 10, 3, 10))
	_label(x + 1.5, GROUND_ROW - 11, "single wall")
	x += 3 + 6

	# Double jump pillars: past what one jump reaches.
	_add_section("double jump", x - 2)
	for height: int in range(7, 12):
		x += 4
		_blocks.append(Rect2(x, GROUND_ROW - height, 3, height))
		_label(x + 1.5, GROUND_ROW - height - 1, "h %d" % height)
		x += 3
	x += 6
	_blocks.append(Rect2(ground_start, GROUND_ROW, x - ground_start, 4))

	# Right wall, tall enough to hold in the abilities area.
	_blocks.append(Rect2(x, GROUND_ROW - 16, 2, 20))


## Platforms separated by labelled gaps, over one shallow pit. Missing a gap
## costs a climb out, not the run. Returns the x after the last platform.
func _add_gap_run(x: float, gaps: Array, label_prefix: String) -> float:
	var start := x
	for gap: int in gaps:
		_label(x + gap / 2.0, GROUND_ROW - 1, "%s %d" % [label_prefix, gap])
		x += gap
		_blocks.append(Rect2(x, GROUND_ROW, 5, 4))
		x += 5
	_blocks.append(Rect2(start, GROUND_ROW + PIT_DEPTH, x - start, 4 - PIT_DEPTH))
	return x


## Tags a position for the playtest log: {section, feature, in_pit}. The
## feature is the nearest label's short name ("gap 7", "overhang", ...).
func describe(pos: Vector2) -> Dictionary:
	var section := ""
	for s: Dictionary in _sections:
		if pos.x >= s.at.x - 2 * TILE:
			section = s.name
	var feature := ""
	var best := FEATURE_RADIUS * TILE
	for label: Dictionary in _labels:
		var distance := absf(pos.x - label.center_x)
		if distance < best:
			best = distance
			feature = (label.text as String).get_slice(":", 0)
	return {section = section, feature = feature, in_pit = pos.y > GROUND_ROW * TILE + 8}


## Registers a section start the number keys can jump to.
func _add_section(section_name: String, tile_x: float) -> void:
	_sections.append({name = section_name, at = Vector2(tile_x * TILE, GROUND_ROW * TILE)})


func _label(tile_x: float, tile_y: float, text: String) -> void:
	_labels.append({
		at = Vector2(tile_x * TILE - LABEL_WIDTH / 2.0, tile_y * TILE + 20),
		center_x = tile_x * TILE,
		text = text,
	})


func _add_collider(rect: Rect2) -> void:
	var body := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = rect.size * TILE
	shape.shape = box
	body.position = rect.get_center() * TILE
	body.add_child(shape)
	add_child(body)
