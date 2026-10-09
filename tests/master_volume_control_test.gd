extends SceneTree

const VOLUME_CONTROL_SCENE := preload("res://menus/master_volume_control.tscn")
const MENU_SCENE := preload("res://menus/menu.tscn")
const WORLD_SCENE := preload("res://world.tscn")

var failures: PackedStringArray = []


func _initialize() -> void:
	var music_player := root.get_node_or_null("MusicPlayer") as AudioStreamPlayer
	if music_player != null:
		music_player.stop()
		music_player.stream = null
	_run.call_deferred()


func _run() -> void:
	GameSettings.instance.save_enabled = false
	var original_setting := GameSettings.instance.get_volume(&"Master")
	var master_bus := AudioServer.get_bus_index(&"Master")
	var original_db := AudioServer.get_bus_volume_db(master_bus)
	var original_muted := AudioServer.is_bus_mute(master_bus)
	var control := VOLUME_CONTROL_SCENE.instantiate() as MasterVolumeControl
	root.add_child(control)
	var slider := control.get_node("VolumeSlider") as HSlider

	slider.value = 0.25
	_expect(not AudioServer.is_bus_mute(master_bus), "positive volume unmutes the Master bus")
	_expect(
		is_equal_approx(AudioServer.get_bus_volume_db(master_bus), linear_to_db(0.25)),
		"slider value maps to Master bus decibels",
	)
	_expect(
		is_equal_approx(GameSettings.instance.get_volume(&"Master"), 0.25),
		"slider writes the Master volume through GameSettings",
	)
	slider.value = 0.0
	_expect(AudioServer.is_bus_mute(master_bus), "zero volume mutes the Master bus")
	GameSettings.instance.set_volume(&"Master", 0.6)
	_expect(is_equal_approx(slider.value, 0.6), "slider follows volume changes made elsewhere")
	_expect(control.process_mode == Node.PROCESS_MODE_ALWAYS, "control remains active while paused")
	var menu := MENU_SCENE.instantiate()
	var world := WORLD_SCENE.instantiate()
	_expect(not menu.has_node(^"MasterVolumeControl"), "main menu omits the in-game volume slider")
	root.add_child(world)
	await process_frame
	_expect(not world.has_node(^"Layout/LeftPanel/Margin/VBox/MasterVolumeControl"),
		"cockpit omits the volume slider; settings retains volume controls")

	menu.free()
	world.queue_free()
	control.queue_free()
	GameSettings.instance.set_volume(&"Master", original_setting)
	await process_frame
	AudioServer.set_bus_volume_db(master_bus, original_db)
	AudioServer.set_bus_mute(master_bus, original_muted)

	if failures.is_empty():
		print("master volume control test: PASS")
		quit()
		return
	for failure in failures:
		push_error("master volume control test: %s" % failure)
	quit(1)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
