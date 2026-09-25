extends SceneTree

var failures: Array[String] = []
var fixture := ""

func _initialize() -> void:
	run.call_deferred()

func expect(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func write_pattern(source: String) -> void:
	var file := FileAccess.open(fixture, FileAccess.WRITE)
	file.store_string(source)
	file.close()

func source(count: int) -> String:
	return "extends BarrageSequence\nfunc _init():\n\tvar shot = BarrageShot.new()\n\tshot.appearance = preload(\"res://resources/projectiles/round.tres\")\n\tshot.behavior = BulletBehavior.new().homing(60, 2)\n\tfire_fan(shot, %d, 60, 70)\n\twait(1)\n\trepeat()\n" % count

func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame

func capture(path: String) -> void:
	if not "--capture" in OS.get_cmdline_user_args(): return
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)

func run() -> void:
	fixture = "res://tests/fixtures/lab_reload_%d.gd" % Time.get_ticks_usec()
	write_pattern(source(2))
	var lab = load("res://projectiles/bullet_lab.tscn").instantiate()
	root.add_child(lab)
	await process_frame
	lab.safety_button.button_pressed = false
	expect(lab.apply_script(fixture, 1), "valid project pattern loads")
	await process_frame
	expect(lab._custom_sequence.steps[0].volley.count == 2, "loaded constructor executes once")
	expect(lab.emitter.position == Vector2(208, 144), "custom emitter placement")
	expect(lab.pattern_choice.selected == 10 and not lab.safety_button.button_pressed, "script mode retains diagnostics options")
	var old_sequence: BarrageSequence = lab._custom_sequence
	write_pattern(source(7))
	await key(KEY_F5)
	expect(lab._custom_sequence.steps[0].volley.count == 7, "F5 reads saved edits instead of cached source")
	expect(old_sequence.steps[0].volley.count == 2, "reload cannot mutate an earlier sequence")
	var good_sequence: BarrageSequence = lab._custom_sequence
	for invalid in ["extends Resource\n", "extends BarrageSequence\nfunc _init(required):\n\twait(1)\n", "extends BarrageSequence\nfunc _init():\n\twait(-1)\n", "extends BarrageSequence\nfunc !!!\n"]:
		write_pattern(invalid)
		expect(not lab.apply_script(fixture, 0), "invalid script rejected")
		expect(lab._custom_sequence == good_sequence and lab.pattern_player.running, "failure preserves last valid playback")
		expect(paused and not lab._script_panel.error_label.text.is_empty(), "failure shows error in paused dialog")
		await key(KEY_ESCAPE)
		expect(not paused and not lab._script_shade.visible, "Escape resumes previous run")
	expect(not lab.apply_script("res://does-not-exist.gd", 0), "missing file reported")
	await key(KEY_ESCAPE)
	var loader = load("res://labs/pattern_loader.gd")
	expect(not loader.load_pattern("C:/outside.gd").error.is_empty(), "outside project path rejected")
	write_pattern(source(3))
	lab.apply_script(fixture, 0)
	lab.toggle_pause()
	lab._script_button.grab_focus()
	lab._open_script_panel()
	await process_frame
	expect(lab._script_panel.get_global_rect().end.y <= 360, "script dialog fits viewport")
	expect(lab.shape_choice.focus_mode == Control.FOCUS_NONE, "modal excludes background controls from focus")
	await key(KEY_ESCAPE)
	expect(paused and root.gui_get_focus_owner() == lab._script_button, "cancel restores pause and focus")
	lab.toggle_pause()
	expect(lab.apply_script("res://patterns/lab_example_pattern.gd", 0), "starter pattern works")
	await create_timer(0.6).timeout
	await capture("res://artifacts/pattern_lab.png")
	lab._open_script_panel()
	await capture("res://artifacts/pattern_picker.png")
	lab.queue_free()
	await process_frame
	DirAccess.remove_absolute(fixture)
	if FileAccess.file_exists(fixture + ".uid"): DirAccess.remove_absolute(fixture + ".uid")
	# Hub switches real scenes. Its F1 navigator survives a Lab scene reload.
	var hub = load("res://labs/lab_hub.tscn").instantiate()
	root.add_child(hub)
	current_scene = hub
	await capture("res://artifacts/lab_hub.png")
	hub.open_lab("res://projectiles/bullet_lab.tscn")
	await process_frame
	await process_frame
	expect(current_scene.scene_file_path == "res://projectiles/bullet_lab.tscn", "hub opens selected Lab")
	reload_current_scene()
	await process_frame
	await process_frame
	expect(root.has_node("LabReturn"), "navigation survives scene restart")
	await key(KEY_F1)
	await process_frame
	expect(current_scene.scene_file_path == "res://labs/lab_hub.tscn" and not root.has_node("LabReturn"), "F1 returns to hub and removes navigation")
	for path in ["res://weapon_test/weapon_test_lab.tscn", "res://menus/augment_frame_test.tscn"]:
		current_scene.open_lab(path)
		await process_frame
		await process_frame
		expect(current_scene.scene_file_path == path, "hub opens " + path)
		await key(KEY_F1)
		await process_frame
		expect(current_scene.scene_file_path == "res://labs/lab_hub.tscn", "F1 returns from " + path)
	current_scene.queue_free()
	await process_frame
	if failures.is_empty(): print("pattern lab smoke test: PASS")
	else:
		for failure in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)
