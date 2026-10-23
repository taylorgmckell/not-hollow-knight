class_name BlockCourse
extends Node2D
## Shared base for test courses built from blocks in tile units: drawing,
## colliders, labels, spike hazards, named sections and switching courses (F6).
##
## Subclasses fill the course in `build()` and react in `_course_physics()`.
## The scene must have a `Player` child. With preview art on (F7) a CourseSkin
## child draws the blocks instead of the grey boxes; collision is identical.

const TILE := 32
const GROUND_ROW := 10
const KILL_Y := 30 * TILE
const BLOCK_COLOR := Color(0.32, 0.34, 0.4)
const HAZARD_COLOR := Color(0.85, 0.25, 0.25)
const LABEL_COLOR := Color(0.75, 0.78, 0.85)
const LABEL_WIDTH := 240.0
## How far from a label (in tiles) an event still counts as at that feature.
const FEATURE_RADIUS := 6.0
const SECTION_ACTIONS: Array[StringName] = [
	&"debug_section_1", &"debug_section_2", &"debug_section_3", &"debug_section_4",
	&"debug_section_5", &"debug_section_6", &"debug_section_7",
]

## Scene that F6 switches to.
@export_file("*.tscn") var other_course := ""

## Solid blocks and spike hazards in tile units (fractions allowed).
var blocks: Array[Rect2] = []
var hazards: Array[Rect2] = []
var labels: Array[Dictionary] = []
## Each: {name, at}. Number keys 1-7 trigger `_on_section_key`.
var sections: Array[Dictionary] = []

@onready var player: Player = $Player


func _enter_tree() -> void:
	# Before children's _ready, so the playtest log starts with abilities on.
	GameState.set_all_abilities(true)


func _ready() -> void:
	build()
	for rect: Rect2 in blocks:
		_add_collider(rect)
	add_child(CourseSkin.new(self))
	queue_redraw()
	_course_ready()


func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed(&"debug_switch_course") and not other_course.is_empty():
		get_tree().change_scene_to_file.call_deferred(other_course)
		return
	for i: int in mini(SECTION_ACTIONS.size(), sections.size()):
		if Input.is_action_just_pressed(SECTION_ACTIONS[i]):
			_on_section_key(i)
	_course_physics(delta)


func _draw() -> void:
	if not PreviewArt.enabled:
		for rect: Rect2 in blocks:
			draw_rect(Rect2(rect.position * TILE, rect.size * TILE), BLOCK_COLOR)
		for rect: Rect2 in hazards:
			_draw_spikes(Rect2(rect.position * TILE, rect.size * TILE))
	var font := ThemeDB.fallback_font
	for label: Dictionary in labels:
		draw_string(font, label.at, label.text, HORIZONTAL_ALIGNMENT_CENTER, LABEL_WIDTH, 18, LABEL_COLOR)


## Fills blocks, hazards, labels and sections.
func build() -> void:
	pass


func _course_ready() -> void:
	pass


func _course_physics(_delta: float) -> void:
	pass


func _on_section_key(_index: int) -> void:
	pass


## Key help shown in the F1 overlay.
func controls_hint() -> String:
	return ""


func add_block(rect: Rect2) -> void:
	blocks.append(rect)


## Spikes: no collider, touching them is checked with `touching_hazard`.
func add_hazard(rect: Rect2) -> void:
	hazards.append(rect)


func add_label(tile_x: float, tile_y: float, text: String) -> void:
	labels.append({
		at = Vector2(tile_x * TILE - LABEL_WIDTH / 2.0, tile_y * TILE + 20),
		center_x = tile_x * TILE,
		text = text,
	})


func add_section(section_name: String, tile_x: float, tile_y: float = GROUND_ROW) -> void:
	sections.append({name = section_name, at = Vector2(tile_x * TILE, tile_y * TILE)})


func touching_hazard() -> bool:
	var body := Rect2(player.global_position + Vector2(-10, -40), Vector2(20, 40))
	for rect: Rect2 in hazards:
		if body.intersects(Rect2(rect.position * TILE, rect.size * TILE)):
			return true
	return false


## Tags a position for the playtest log: {section, feature, in_pit}. The
## section is the last one started at or before x; the feature is the
## nearest label's short name ("gap 7", "overhang", ...).
func describe(pos: Vector2) -> Dictionary:
	var section := ""
	for s: Dictionary in sections:
		if pos.x >= s.at.x - 2 * TILE:
			section = s.name
	var feature := ""
	var best := FEATURE_RADIUS * TILE
	for label: Dictionary in labels:
		var distance := absf(pos.x - label.center_x)
		if distance < best:
			best = distance
			feature = (label.text as String).get_slice(":", 0)
	return {section = section, feature = feature, in_pit = pos.y > GROUND_ROW * TILE + 8}


func _add_collider(rect: Rect2) -> void:
	var body := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = rect.size * TILE
	shape.shape = box
	body.position = rect.get_center() * TILE
	body.add_child(shape)
	add_child(body)


func _draw_spikes(area: Rect2) -> void:
	var count := maxi(1, roundi(area.size.x / 16.0))
	var width := area.size.x / count
	for i: int in count:
		var left := area.position.x + i * width
		draw_colored_polygon(PackedVector2Array([
			Vector2(left, area.end.y),
			Vector2(left + width / 2.0, area.position.y),
			Vector2(left + width, area.end.y),
		]), HAZARD_COLOR)
