extends SceneTree

var failures: PackedStringArray = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var world_scene: PackedScene = load("res://world.tscn")
	var world: Control = world_scene.instantiate() as Control
	root.add_child(world)
	GameSettings.instance.save_enabled = false
	var pause_overlay := world.get_node("Layout/Playfield/PauseOverlay") as PauseMenu
	var progression: Node = world.get_node(
		"Layout/Playfield/ViewportContainer/PlayfieldViewport/Gameplay/AugmentProgressionController"
	)

	_expect(not pause_overlay.visible, "pause overlay starts hidden")
	_send_escape(world)
	_expect(paused, "Escape pauses the scene tree")
	_expect(pause_overlay.visible, "Escape shows the playfield pause overlay")
	var threat_elapsed: float = progression.enemy_augment_elapsed
	await process_frame
	await process_frame
	_expect(
		is_equal_approx(progression.enemy_augment_elapsed, threat_elapsed),
		"Threat timer stops while paused",
	)

	var resume_button := pause_overlay.get_node("%ResumeButton") as Button
	var settings_button := pause_overlay.get_node("%SettingsButton") as Button
	var settings_menu := world.get_node("%SettingsMenu") as SettingsMenu
	_expect(resume_button.has_focus(), "pause menu opens focused on resume")
	_expect(pause_overlay.theme != null, "pause menu uses the shared UI theme")
	_press(&"ui_down")
	_expect(settings_button.has_focus(), "down moves to the settings item")
	_press(&"ui_accept")
	_expect(settings_menu.visible, "settings item opens the settings panel while paused")
	_expect(paused, "opening settings keeps the game paused")
	_send_escape(world)
	_expect(paused, "Escape inside settings does not resume the game")
	_press(&"ui_cancel")
	_expect(not settings_menu.visible, "cancel closes the settings panel")
	_expect(settings_button.has_focus(), "closing settings returns focus to the pause settings item")
	_expect(paused, "closing settings keeps the game paused")

	_send_escape(world)
	_expect(not paused, "a second Escape resumes the scene tree")
	_expect(not pause_overlay.visible, "resuming hides the playfield pause overlay")

	_send_escape(world)
	_press(&"ui_accept")
	_expect(not paused, "accept on resume resumes the scene tree")
	_expect(not pause_overlay.visible, "resume item hides the pause overlay")

	paused = true
	_send_escape(world)
	_expect(paused, "Escape does not cancel a pause owned by another system")
	_expect(not pause_overlay.visible, "external pauses do not show the manual pause overlay")
	paused = false

	if failures.is_empty():
		print("pause smoke test: PASS")
		quit()
		return
	for failure in failures:
		push_error("pause smoke test: %s" % failure)
	quit(1)


func _press(action: StringName) -> void:
	for pressed in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		root.push_input(event)


func _send_escape(world: Control) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	world.call("_unhandled_input", event)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
