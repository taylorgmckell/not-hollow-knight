extends Node2D
## F1: shows player state, velocity and feel timers, plus a trail of recent
## positions coloured by state so jump arcs can be compared while tuning.
## Forgiveness assists and bonks (ceiling hits that kill a jump) are marked
## where they happen and counted. F3 turns assists on/off, F4 abilities.

const TRAIL_LENGTH := 180
const MARKER_LIFETIME := 2.0
const STATE_COLORS := {
	&"idle": Color.GRAY,
	&"run": Color.LIGHT_GREEN,
	&"jump": Color.ORANGE,
	&"fall": Color.CORNFLOWER_BLUE,
	&"dash": Color.WHITE,
	&"wall_slide": Color.MEDIUM_PURPLE,
}
const ASSIST_COLORS := {
	&"corner": Color.MAGENTA,
	&"ledge": Color.YELLOW,
	&"bonk": Color.RED,
}

@export var player: Player

var _trail: Array[Vector2] = []
var _trail_colors: Array[Color] = []
## Each: {kind, at, nudge, age}
var _markers: Array[Dictionary] = []
var _assist_counts := {&"corner": 0, &"ledge": 0, &"bonk": 0}
var _label := Label.new()
var _layer := CanvasLayer.new()


func _ready() -> void:
	z_index = 10
	_layer.layer = 50
	_label.position = Vector2(16, 16)
	_label.add_theme_font_size_override(&"font_size", 20)
	_label.add_theme_color_override(&"font_outline_color", Color.BLACK)
	_label.add_theme_constant_override(&"outline_size", 4)
	_layer.add_child(_label)
	add_child(_layer)
	if player:
		player.assisted.connect(_on_player_assisted)
		player.bonked.connect(_on_player_assisted.bind(&"bonk", Vector2.ZERO))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"debug_overlay"):
		visible = not visible
		_layer.visible = visible
	elif event.is_action_pressed(&"debug_assists") and player:
		player.assists_enabled = not player.assists_enabled
	elif event.is_action_pressed(&"debug_abilities"):
		GameState.set_all_abilities(not GameState.has_dash)


func _physics_process(delta: float) -> void:
	if not player:
		return
	_trail.append(player.global_position)
	_trail_colors.append(STATE_COLORS.get(player.state_name, Color.WHITE))
	if _trail.size() > TRAIL_LENGTH:
		_trail.pop_front()
		_trail_colors.pop_front()
	for marker: Dictionary in _markers:
		marker.age += delta
	_markers = _markers.filter(func(m: Dictionary) -> bool: return m.age < MARKER_LIFETIME)
	if visible:
		queue_redraw()
		_label.text = _describe()


func _draw() -> void:
	for i: int in _trail.size():
		draw_circle(_trail[i], 2.0, _trail_colors[i])
	var font := ThemeDB.fallback_font
	for marker: Dictionary in _markers:
		var color: Color = ASSIST_COLORS[marker.kind]
		color.a = 1.0 - marker.age / MARKER_LIFETIME
		var at: Vector2 = marker.at
		# Arrow from where the player was to where the assist put them.
		draw_line(at - marker.nudge * 4.0, at, color, 3.0)
		draw_circle(at, 5.0, color)
		var text: String = marker.kind
		if marker.kind != &"bonk":
			text += " %dpx" % roundi((marker.nudge as Vector2).length())
		draw_string(font, at + Vector2(8, -8), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, color)


func _on_player_assisted(kind: StringName, nudge: Vector2) -> void:
	_assist_counts[kind] += 1
	# Mark the top of the head for corners and bonks, the feet for ledges.
	var at := player.global_position + (Vector2.ZERO if kind == &"ledge" else Vector2(0, -40))
	_markers.append({kind = kind, at = at, nudge = nudge, age = 0.0})


func _describe() -> String:
	return "\n".join([
		"state   %s" % player.state_name,
		"vel     (%.0f, %.0f)" % [player.velocity.x, player.velocity.y],
		"floor   %s" % player.is_on_floor(),
		"coyote  %.3f" % player.coyote_timer,
		"buffer  %.3f" % player.jump_buffer_timer,
		"air     dash %s   double %s   dash cd %.2f" % [
			"ready" if player.air_dash_available else "used",
			"ready" if player.double_jump_available else "used",
			player.dash_cooldown_timer],
		"abilities %s" % ("ON" if GameState.has_dash else "OFF"),
		"assists %s   corner x%d   ledge x%d   bonks x%d" % [
			"ON" if player.assists_enabled else "OFF",
			_assist_counts[&"corner"], _assist_counts[&"ledge"], _assist_counts[&"bonk"]],
		"",
		_controls_hint(),
	])


## Key help comes from the course, since each one binds keys differently.
func _controls_hint() -> String:
	var course := get_parent()
	return course.controls_hint() if course.has_method(&"controls_hint") else ""
