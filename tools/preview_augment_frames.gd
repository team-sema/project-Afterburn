extends SceneTree
## Run through tools/run-godot.cmd --rendering-method gl_compatibility --script res://tools/preview_augment_frames.gd


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(640, 360)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	var overlay := preload("res://menus/augment_selection_overlay.tscn").instantiate()
	root.add_child(overlay)
	var choices: Array = []
	for path in [
		"res://resources/player_augments/weapon/trait_shotgun_expanded_shell.tres",
		"res://resources/player_augments/weapon/trait_plasma_gravity.tres",
		"res://resources/player_augments/weapon/trait_missile_multi_rack.tres",
	]:
		choices.append(load(path).duplicate())
	for index in choices.size():
		choices[index].tier = index
	overlay.set_reroll_state(2, true)
	await overlay.open_choices("증강 선택", choices, overlay.player_accent_color, true)
	for index in choices.size():
		overlay.choice_buttons[index].grab_focus()
		await create_timer(0.4).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/augment_frame_%d.png" % index)
	print("augment frame render: PASS")
	quit()
