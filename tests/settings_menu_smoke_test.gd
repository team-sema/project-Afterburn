extends SceneTree

## 시작화면 → 설정 모달 키보드 흐름과 GameSettings 반영을 확인한다.

const MENU_SCENE := preload("res://menus/menu.tscn")

var failures: PackedStringArray = []


func _initialize() -> void:
	var music_player := root.get_node_or_null("MusicPlayer") as AudioStreamPlayer
	if music_player != null:
		music_player.stop()
	_run.call_deferred()


func _run() -> void:
	GameSettings.instance.save_enabled = false
	var original_master := GameSettings.instance.get_volume(&"Master")
	var original_fullscreen := GameSettings.instance.is_fullscreen()
	GameSettings.instance.set_volume(&"Master", 0.5)

	var menu := MENU_SCENE.instantiate() as Control
	root.add_child(menu)
	current_scene = menu
	await process_frame

	var start_button := menu.get_node("%StartButton") as Button
	var settings_button := menu.get_node("%SettingsButton") as Button
	var quit_button := menu.get_node("%QuitButton") as Button
	var settings_menu := menu.get_node("%SettingsMenu") as SettingsMenu
	_expect(menu.theme != null, "menu uses the shared UI theme")
	_expect(start_button.has_focus(), "start item is focused on entry")

	_press(&"ui_down")
	_expect(settings_button.has_focus(), "down moves to the settings item")
	_press(&"ui_up")
	_press(&"ui_up")
	_expect(quit_button.has_focus(), "up from the first item wraps to the last item")
	_press(&"ui_down")
	_expect(start_button.has_focus(), "down from the last item wraps to the first item")

	_press(&"ui_down")
	_press(&"ui_accept")
	_expect(settings_menu.visible, "accept on the settings item opens the settings panel")
	_expect(start_button.focus_mode == Control.FOCUS_NONE, "menu items leave the focus path while settings is open")

	var master_row := settings_menu.get_node("Center/Panel/VBox/Rows/MasterRow") as PanelContainer
	var master_slider := master_row.get_node("HBox/Slider") as HSlider
	var master_value := master_row.get_node("HBox/Value") as Label
	_expect(master_slider.has_focus(), "settings opens focused on the master volume row")
	_expect(master_row.theme_type_variation == &"SettingsRowFocused", "focused row is highlighted")
	_expect(master_value.text == "50%", "volume row shows the current percentage")

	_press(&"ui_right")
	_expect(is_equal_approx(GameSettings.instance.get_volume(&"Master"), 0.55), "right raises the volume by 5%")
	_expect(master_value.text == "55%", "volume label follows the slider")
	var master_bus := AudioServer.get_bus_index(&"Master")
	_expect(
		is_equal_approx(AudioServer.get_bus_volume_db(master_bus), linear_to_db(0.55)),
		"volume change is applied to the Master bus",
	)

	var fullscreen_button := settings_menu.get_node("%FullscreenButton") as Button
	for i in 3:
		_press(&"ui_down")
	_expect(fullscreen_button.has_focus(), "down walks the rows to the fullscreen toggle")
	_expect(master_row.theme_type_variation == &"SettingsRow", "unfocused row loses the highlight")
	var fullscreen_before := GameSettings.instance.is_fullscreen()
	_press(&"ui_right")
	_expect(GameSettings.instance.is_fullscreen() != fullscreen_before, "left/right toggles fullscreen")
	_expect(fullscreen_button.has_focus(), "toggling fullscreen keeps focus on the row")
	_press(&"ui_left")
	_expect(GameSettings.instance.is_fullscreen() == fullscreen_before, "toggling again restores fullscreen")

	_press(&"ui_down")
	var event_button := settings_menu.get_node("%EventLogButton") as Button
	_expect(event_button.has_focus(), "event log toggle follows fullscreen")
	var log_before := GameSettings.instance.is_combat_event_log_enabled()
	_press(&"ui_right")
	_expect(GameSettings.instance.is_combat_event_log_enabled() != log_before, "right toggles event log")
	_press(&"ui_accept")
	_expect(GameSettings.instance.is_combat_event_log_enabled() == log_before, "accept restores event log")
	_press(&"ui_down")
	_expect((settings_menu.get_node("%BackButton") as Button).has_focus(), "back item follows the toggle")
	_press(&"ui_down")
	_expect(master_slider.has_focus(), "down from the back item wraps to the first row")

	_press(&"ui_cancel")
	_expect(not settings_menu.visible, "cancel closes the settings panel")
	_expect(settings_button.has_focus(), "closing settings returns focus to the settings item")
	_expect(start_button.focus_mode == Control.FOCUS_ALL, "menu items rejoin the focus path")

	_press(&"ui_down")
	_press(&"ui_up")
	_press(&"ui_accept")
	_expect(settings_menu.visible, "settings can be reopened from the keyboard")
	_press(&"ui_down")
	_press(&"ui_down")
	_press(&"ui_down")
	_press(&"ui_down")
	_press(&"ui_down")
	_press(&"ui_accept")
	_expect(not settings_menu.visible, "back item closes the settings panel")

	await _wait_for_background_load(menu)
	menu.queue_free()
	current_scene = null
	await process_frame
	GameSettings.instance.set_volume(&"Master", original_master)
	GameSettings.instance.set_fullscreen(original_fullscreen)

	if failures.is_empty():
		print("settings menu smoke test: PASS")
		quit()
		return
	for failure in failures:
		push_error("settings menu smoke test: %s" % failure)
	quit(1)


func _press(action: StringName) -> void:
	for pressed in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		root.push_input(event)


## 메뉴가 시작한 World 비동기 로딩이 끝날 때까지 기다려 종료 시 로더 오류를 피한다.
func _wait_for_background_load(menu: Node) -> void:
	var deadline := Time.get_ticks_msec() + 15000
	while menu.get("_game_scene") == null and Time.get_ticks_msec() < deadline:
		await process_frame


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
