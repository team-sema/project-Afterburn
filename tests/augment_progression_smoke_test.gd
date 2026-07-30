extends SceneTree

var failures: PackedStringArray = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var world_scene: PackedScene = load("res://world.tscn")
	var world: Control = world_scene.instantiate() as Control
	root.add_child(world)
	var gameplay: Node = world.get_node("Layout/Playfield/ViewportContainer/PlayfieldViewport/Gameplay")
	var progression: Node = gameplay.get_node("AugmentProgressionController")
	var offer_controller: Node = gameplay.get_node("AugmentOfferController")
	var progression_hud: Node = world.get_node("Layout/LeftPanel/Margin/VBox/ProgressionHud")
	var experience_label: Label = progression_hud.get_node("ExperienceLabel") as Label
	var experience_bar: ProgressBar = progression_hud.get_node("ExperienceBar") as ProgressBar
	var normal_fill := experience_bar.get_theme_stylebox("fill") as StyleBoxFlat
	var normal_fill_color := normal_fill.bg_color

	_expect(progression.level == 1, "run starts at level 1")
	_expect(progression.experience_required == 5, "first level requires 5 XP")
	_expect(InputMap.has_action("open_augment_offer"), "augment offer input action exists")
	var has_c_key := false
	for event in InputMap.action_get_events("open_augment_offer"):
		if event is InputEventKey and (event.keycode == KEY_C or event.physical_keycode == KEY_C):
			has_c_key = true
	_expect(has_c_key, "augment offer action is bound to C")

	var ship: Node2D = gameplay.get_node("Ship") as Node2D
	var collector: Area2D = ship.get_node("ExperienceCollector") as Area2D
	var orb_scene: PackedScene = load("res://pickups/experience_orb.tscn")
	var orb: Area2D = orb_scene.instantiate() as Area2D
	gameplay.add_child(orb)
	orb.setup(7, collector.global_position + Vector2(60.0, 0.0))
	for _index in 2:
		await physics_frame
		await process_frame
	_expect(progression.current_experience == 0, "orb outside the collector radius is not collected")
	orb.global_position = collector.global_position + Vector2(20.0, 0.0)
	var collected_amount: int = await orb.collected

	_expect(collected_amount == 7, "collector receives the orb's XP amount")
	_expect(progression.level == 1, "filling the bar does not level up automatically")
	_expect(progression.current_experience == 7, "experience can accumulate past the requirement")
	_expect(progression.experience_required == 5, "requirement stays unchanged until level-up")
	_expect(not offer_controller.is_offer_active, "filling the bar does not open an augment offer")
	_expect(experience_label.text.contains("[C]"), "full experience bar shows the augment input hint")
	progression_hud.call("_process", 0.5)
	var highlighted_fill := experience_bar.get_theme_stylebox("fill") as StyleBoxFlat
	_expect(highlighted_fill.bg_color != normal_fill_color, "full experience bar cycles highlight colors")

	Input.action_press("open_augment_offer")
	progression._process(0.0)
	Input.action_release("open_augment_offer")
	_expect(progression.level == 2, "augment input levels the player")
	_expect(progression.current_experience == 2, "level-up subtracts only the current requirement")
	_expect(progression.experience_required == 8, "level-up applies the next requirement")
	_expect(offer_controller.is_offer_active, "augment input requests an augment offer")
	_expect(not experience_label.text.contains("[C]"), "input hint clears below the next requirement")
	var restored_fill := experience_bar.get_theme_stylebox("fill") as StyleBoxFlat
	_expect(restored_fill.bg_color == normal_fill_color, "experience bar restores its normal color")

	progression.add_experience(6)
	_expect(progression.current_experience == 8, "experience keeps accumulating during an active offer")
	Input.action_press("open_augment_offer")
	progression._process(0.0)
	Input.action_release("open_augment_offer")
	_expect(progression.level == 2, "active offer blocks another level-up")
	_expect(progression.current_experience == 8, "blocked level-up does not spend experience")
	_expect(
		offer_controller.active_offer_type == AugmentOfferController.OfferType.PLAYER,
		"level-up requests a player offer",
	)

	progression._process(60.0)
	_expect(progression.enemy_augment_tier == 1, "60 seconds reaches enemy augment tier 1")
	_expect(progression.pending_offers.size() == 1, "enemy offer waits behind an active player offer")
	if not progression.pending_offers.is_empty():
		_expect(
			progression.pending_offers.front() == AugmentOfferController.OfferType.ENEMY,
			"queued offer is an enemy offer",
		)

	if failures.is_empty():
		print("augment progression smoke test: PASS")
		quit()
		return
	for failure in failures:
		push_error("augment progression smoke test: %s" % failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
