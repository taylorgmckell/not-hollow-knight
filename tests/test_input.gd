extends TestCase
## Default bindings: simulated controller events reach the right actions.


func after_each() -> void:
	# Release everything so held inputs don't leak into later tests.
	_send_axis(JOY_AXIS_TRIGGER_RIGHT, 0.0)
	_send_button(JOY_BUTTON_RIGHT_SHOULDER, false)
	_send_button(JOY_BUTTON_A, false)


func _send_axis(axis: JoyAxis, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	Input.parse_input_event(event)


func _send_button(button: JoyButton, pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = pressed
	Input.parse_input_event(event)


func test_r2_trigger_dashes() -> void:
	_send_axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)
	await tick()
	assert_true(Input.is_action_pressed(&"dash"), "full R2 pull is dash")
	_send_axis(JOY_AXIS_TRIGGER_RIGHT, 0.0)
	await tick()
	assert_true(not Input.is_action_pressed(&"dash"), "released R2 isn't dash")


func test_light_r2_touch_does_not_dash() -> void:
	_send_axis(JOY_AXIS_TRIGGER_RIGHT, 0.2)
	await tick()
	assert_true(not Input.is_action_pressed(&"dash"), "a light touch stays under the deadzone")


func test_r1_no_longer_dashes() -> void:
	_send_button(JOY_BUTTON_RIGHT_SHOULDER, true)
	await tick()
	assert_true(not Input.is_action_pressed(&"dash"), "R1 is free")


func test_cross_jumps() -> void:
	_send_button(JOY_BUTTON_A, true)
	await tick()
	assert_true(Input.is_action_pressed(&"jump"), "Cross (bottom face button) is jump")
