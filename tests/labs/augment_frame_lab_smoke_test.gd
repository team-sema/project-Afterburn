extends SceneTree

var failures: PackedStringArray = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var lab := preload("res://labs/augment_cards/augment_frame_test.tscn").instantiate()
	root.add_child(lab)
	var deadline := Time.get_ticks_msec() + 15000
	while lab.busy and Time.get_ticks_msec() < deadline:
		await process_frame
	if lab.busy:
		push_error("augment frame lab: opening timed out")
		quit(1)
		return
	for index in 3:
		_expect(lab.overlay.current_choices[index].tier == index, "opening offer shows one card per tier")
	await lab.show_mode(PlayerAugment.Tier.GOLD)
	var original: Resource = lab.overlay.current_choices[0]
	lab.overlay.reroll_requested.emit(0)
	_expect(lab.rerolls == 1, "reroll consumes one charge")
	_expect(lab.overlay.current_choices[0] != original, "reroll replaces the focused card")
	_expect(lab.overlay.current_choices[0].tier == PlayerAugment.Tier.GOLD, "reroll keeps the gold tier")
	lab.overlay.reroll_requested.emit(0)
	_expect(lab.rerolls == 0 and lab.overlay.reroll_button.disabled, "last reroll disables the button")
	await lab._select(lab.overlay.current_choices[0])
	while lab.busy:
		await process_frame
	_expect(lab.rerolls == 2 and lab.overlay.is_accepting_input, "selecting a card refills rerolls and reopens input")
	await lab.show_mode(PlayerAugment.Tier.PRISMATIC)
	for choice in lab.overlay.current_choices:
		_expect(choice.tier == PlayerAugment.Tier.PRISMATIC, "prismatic mode shows only prismatic cards")
	# The lab styles duplicates only; source cards keep their module tier.
	for source in lab.SAMPLES:
		_expect(source.tier == source.trait_definition.tier, "lab sample keeps its module tier")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var result := root.get_texture().get_image().save_png("res://artifacts/augment_frame_lab.png")
		_expect(result == OK, "frame lab screenshot saves")
	lab.queue_free()
	await process_frame
	if failures.is_empty():
		print("augment frame lab smoke test: PASS")
		quit()
		return
	for failure in failures:
		push_error("augment frame lab smoke test: %s" % failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
