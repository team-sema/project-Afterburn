extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var lab := preload("res://menus/augment_frame_test.tscn").instantiate()
	root.add_child(lab)
	var deadline := Time.get_ticks_msec() + 15000
	while lab.busy and Time.get_ticks_msec() < deadline:
		await process_frame
	if lab.busy:
		push_error("augment frame lab: opening timed out")
		quit(1)
		return
	for index in 3:
		assert(lab.overlay.current_choices[index].tier == index)
	await lab.show_mode(PlayerAugment.Tier.GOLD)
	var original: Resource = lab.overlay.current_choices[0]
	lab.overlay.reroll_requested.emit(0)
	assert(lab.rerolls == 1)
	assert(lab.overlay.current_choices[0] != original)
	assert(lab.overlay.current_choices[0].tier == PlayerAugment.Tier.GOLD)
	lab.overlay.reroll_requested.emit(0)
	assert(lab.rerolls == 0 and lab.overlay.reroll_button.disabled)
	await lab._select(lab.overlay.current_choices[0])
	while lab.busy:
		await process_frame
	assert(lab.rerolls == 2 and lab.overlay.is_accepting_input)
	await lab.show_mode(PlayerAugment.Tier.PRISMATIC)
	for choice in lab.overlay.current_choices:
		assert(choice.tier == PlayerAugment.Tier.PRISMATIC)
	# The lab styles duplicates only; source cards keep their module tier.
	for source in lab.SAMPLES:
		assert(source.tier == source.trait_definition.tier)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var result := root.get_texture().get_image().save_png("res://artifacts/augment_frame_lab.png")
		assert(result == OK)
	lab.queue_free()
	await process_frame
	print("augment frame lab smoke test: PASS")
	quit(0)
