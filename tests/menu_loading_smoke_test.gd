extends SceneTree

const MENU_SCENE := preload("res://menus/menu.tscn")

var failures: PackedStringArray = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var menu := MENU_SCENE.instantiate() as Control
	root.add_child(menu)
	current_scene = menu
	menu.set_process(false)

	var start_button := menu.get_node("%StartButton") as Button
	var settings_button := menu.get_node("%SettingsButton") as Button
	_expect(start_button.has_focus(), "start item is focused when the menu opens")

	menu.call("_request_start")
	menu.call("_enter_game_when_ready")
	var status_label := menu.get_node("%StatusLabel") as Label
	_expect(status_label.text == "게임 준비 중...", "early start input shows loading feedback")
	_expect(
		settings_button.disabled and settings_button.focus_mode == Control.FOCUS_NONE,
		"other menu items are locked while the game is starting",
	)

	var deadline := Time.get_ticks_msec() + 10000
	while menu.get("_game_scene") == null and Time.get_ticks_msec() < deadline:
		menu.call("_poll_game_scene_load")
		await process_frame
	_expect(menu.get("_game_scene") is PackedScene, "game scene finishes loading in the background")

	if menu.get("_game_scene") != null:
		menu.call("_enter_game_when_ready")
		deadline = Time.get_ticks_msec() + 3000
		while (current_scene == null or current_scene.name != "World") and Time.get_ticks_msec() < deadline:
			await process_frame
		_expect(current_scene != null and current_scene.name == "World", "loaded game scene becomes current")
	if current_scene != null:
		current_scene.queue_free()
		current_scene = null
		await process_frame

	if failures.is_empty():
		print("menu loading smoke test: PASS")
		quit()
		return
	for failure in failures:
		push_error("menu loading smoke test: %s" % failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
