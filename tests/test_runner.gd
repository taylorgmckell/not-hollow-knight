extends Node
## Runs every suite and exits with a non-zero code on failure. Run headless:
##   godot --headless --fixed-fps 60 res://tests/test_runner.tscn

const SUITES: Array[Script] = [
	preload("res://tests/test_player_movement.gd"),
	preload("res://tests/test_graybox.gd"),
	preload("res://tests/test_playtest_log.gd"),
]


func _ready() -> void:
	var passed := 0
	var failed := 0
	for suite_script: Script in SUITES:
		var suite_name := suite_script.resource_path.get_file().get_basename()
		for method: Dictionary in suite_script.get_script_method_list():
			var test_name: String = method.name
			if not test_name.begins_with("test_"):
				continue
			var suite: TestCase = suite_script.new()
			add_child(suite)
			await suite.before_each()
			await suite.call(test_name)
			await suite.after_each()
			if suite.failures.is_empty():
				passed += 1
				print("  PASS  %s.%s" % [suite_name, test_name])
			else:
				failed += 1
				print("  FAIL  %s.%s" % [suite_name, test_name])
				for failure: String in suite.failures:
					print("          %s" % failure)
			suite.queue_free()
			await get_tree().process_frame
	print("\n%d passed, %d failed" % [passed, failed])
	get_tree().quit(1 if failed > 0 else 0)
