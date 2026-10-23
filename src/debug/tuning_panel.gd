extends CanvasLayer
## F2: live sliders for every ranged number exported on the player's tuning
## resource. "Save" writes the values back to the .tres file (editor runs only).

@export var player: Player

var _panel := PanelContainer.new()
var _status := Label.new()


func _ready() -> void:
	layer = 60
	visible = false
	_build()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"debug_tuning"):
		visible = not visible


func _build() -> void:
	var tuning := player.tuning
	_panel.position = Vector2(16, 220)
	_panel.custom_minimum_size = Vector2(520, 640)
	add_child(_panel)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(500, 620)
	_panel.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(rows)

	for prop: Dictionary in tuning.get_property_list():
		if prop.usage & PROPERTY_USAGE_GROUP:
			var header := Label.new()
			header.text = prop.name
			header.add_theme_color_override(&"font_color", Color.GOLD)
			rows.add_child(header)
		elif prop.usage & PROPERTY_USAGE_EDITOR and prop.hint == PROPERTY_HINT_RANGE:
			if prop.type == TYPE_FLOAT or prop.type == TYPE_INT:
				rows.add_child(_slider_row(tuning, prop))

	var save := Button.new()
	save.text = "Save to %s" % tuning.resource_path.get_file()
	save.pressed.connect(_save)
	rows.add_child(save)
	rows.add_child(_status)


func _slider_row(tuning: PlayerTuning, prop: Dictionary) -> Control:
	var range_parts: PackedStringArray = (prop.hint_string as String).split(",")
	var row := HBoxContainer.new()
	var name_label := Label.new()
	name_label.text = prop.name
	name_label.custom_minimum_size.x = 210
	var slider := HSlider.new()
	slider.min_value = range_parts[0].to_float()
	slider.max_value = range_parts[1].to_float()
	slider.step = range_parts[2].to_float() if range_parts.size() > 2 else 0.01
	slider.value = tuning.get(prop.name)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var value_label := Label.new()
	value_label.custom_minimum_size.x = 70
	value_label.text = str(slider.value)
	slider.value_changed.connect(func(value: float) -> void:
		tuning.set(prop.name, int(value) if prop.type == TYPE_INT else value)
		tuning.emit_changed()
		value_label.text = str(tuning.get(prop.name)))
	row.add_child(name_label)
	row.add_child(slider)
	row.add_child(value_label)
	return row


func _save() -> void:
	var err := ResourceSaver.save(player.tuning)
	_status.text = "Saved." if err == OK else "Save failed: %s" % error_string(err)
