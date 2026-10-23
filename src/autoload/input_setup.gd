extends Node
## Registers the default input map at startup.
##
## Bindings live in code rather than project.godot so they are readable and
## reviewable in diffs. Actions already defined in project settings are left
## alone, so rebinding through the editor still wins.

const KEYS := {
	&"move_left": [KEY_LEFT, KEY_A],
	&"move_right": [KEY_RIGHT, KEY_D],
	&"move_up": [KEY_UP, KEY_W],
	&"move_down": [KEY_DOWN, KEY_S],
	&"jump": [KEY_Z, KEY_SPACE],
	&"attack": [KEY_X, KEY_J],
	&"dash": [KEY_C, KEY_K],
	&"debug_overlay": [KEY_F1],
	&"debug_tuning": [KEY_F2],
	&"debug_assists": [KEY_F3],
	&"debug_abilities": [KEY_F4],
	&"debug_switch_course": [KEY_F6],
	&"debug_reset": [KEY_R],
	&"debug_section_1": [KEY_1],
	&"debug_section_2": [KEY_2],
	&"debug_section_3": [KEY_3],
	&"debug_section_4": [KEY_4],
	&"debug_section_5": [KEY_5],
	&"debug_section_6": [KEY_6],
	&"debug_section_7": [KEY_7],
}

const JOY_BUTTONS := {
	&"move_left": [JOY_BUTTON_DPAD_LEFT],
	&"move_right": [JOY_BUTTON_DPAD_RIGHT],
	&"move_up": [JOY_BUTTON_DPAD_UP],
	&"move_down": [JOY_BUTTON_DPAD_DOWN],
	&"jump": [JOY_BUTTON_A],
	&"attack": [JOY_BUTTON_X],
	&"dash": [JOY_BUTTON_RIGHT_SHOULDER],
}

## action -> [axis, direction]
const JOY_AXES := {
	&"move_left": [JOY_AXIS_LEFT_X, -1.0],
	&"move_right": [JOY_AXIS_LEFT_X, 1.0],
	&"move_up": [JOY_AXIS_LEFT_Y, -1.0],
	&"move_down": [JOY_AXIS_LEFT_Y, 1.0],
}

const STICK_DEADZONE := 0.4


func _enter_tree() -> void:
	register_defaults()


static func register_defaults() -> void:
	for action: StringName in KEYS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action, STICK_DEADZONE)
		for keycode: int in KEYS[action]:
			var key := InputEventKey.new()
			key.physical_keycode = keycode as Key
			InputMap.action_add_event(action, key)
		for button: int in JOY_BUTTONS.get(action, []):
			var joy_button := InputEventJoypadButton.new()
			joy_button.button_index = button as JoyButton
			InputMap.action_add_event(action, joy_button)
		if JOY_AXES.has(action):
			var joy_motion := InputEventJoypadMotion.new()
			joy_motion.axis = JOY_AXES[action][0] as JoyAxis
			joy_motion.axis_value = JOY_AXES[action][1]
			InputMap.action_add_event(action, joy_motion)
