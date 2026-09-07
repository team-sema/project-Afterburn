extends SceneTree

const OVERLAY_SCENE := preload("res://menus/augment_selection_overlay.tscn")

var failures := PackedStringArray()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var default_augment := PlayerAugment.new()
	_expect(default_augment.tier == PlayerAugment.Tier.SILVER, "player augments default to Silver")
	_expect(default_augment.get_tier_label() == "SILVER", "Silver tier has a stable display label")
	var gameplay := (load("res://gameplay.tscn") as PackedScene).instantiate()
	var offer_controller := gameplay.get_node("AugmentOfferController") as AugmentOfferController
	_expect(offer_controller.player_augment_pool.size() == 48, "the current player augment pool remains intact")
	for augment in offer_controller.player_augment_pool:
		_expect(augment.tier == PlayerAugment.Tier.SILVER, "%s defaults to Silver" % augment.augment_id)
	gameplay.free()

	var silver := _make_augment(&"tier_silver", "Silver Test", PlayerAugment.Tier.SILVER)
	var gold := _make_augment(&"tier_gold", "Gold Test", PlayerAugment.Tier.GOLD)
	var prismatic := _make_augment(
		&"tier_prismatic",
		"Prismatic Test",
		PlayerAugment.Tier.PRISMATIC,
	)
	_expect(gold.get_tier_label() == "GOLD", "Gold tier has a stable display label")
	_expect(prismatic.get_tier_label() == "PRISMATIC", "Prismatic tier has a stable display label")

	var overlay := OVERLAY_SCENE.instantiate() as AugmentSelectionOverlay
	root.add_child(overlay)
	overlay.call("_set_choices", [silver, gold, prismatic])

	var buttons: Array[Button] = [
		overlay.get_node("MarginContainer/PanelContainer/VBoxContainer/ChoiceCarousel/ChoiceButton1") as Button,
		overlay.get_node("MarginContainer/PanelContainer/VBoxContainer/ChoiceCarousel/ChoiceButton2") as Button,
		overlay.get_node("MarginContainer/PanelContainer/VBoxContainer/ChoiceCarousel/ChoiceButton3") as Button,
	]
	var expected_labels := ["SILVER", "GOLD", "PRISMATIC"]
	var expected_border_widths := [1, 2, 3]
	var border_colors: Array[Color] = []
	for index in buttons.size():
		var tier_label := buttons[index].get_node("CardArt/TierLabel") as Label
		var tier_accent := buttons[index].get_node("CardArt/TierAccent") as ColorRect
		var normal_style := buttons[index].get_theme_stylebox("normal") as StyleBoxFlat
		_expect(tier_label.visible, "player augment tier label %d is visible" % index)
		_expect(tier_label.text == expected_labels[index], "player augment tier label %d is correct" % index)
		_expect(tier_accent.visible, "player augment tier accent %d is visible" % index)
		_expect(
			normal_style.border_width_left == expected_border_widths[index],
			"tier %d has a distinct frame weight" % index,
		)
		_expect(
			buttons[index].get_theme_stylebox("disabled") == normal_style,
			"tier %d keeps disabled and normal card geometry aligned" % index,
		)
		border_colors.append(normal_style.border_color)
	_expect(
		border_colors[0] != border_colors[1]
		and border_colors[1] != border_colors[2]
		and border_colors[0] != border_colors[2],
		"Silver, Gold, and Prismatic frames use distinct colors",
	)

	var prismatic_accent := buttons[2].get_node("CardArt/TierAccent") as ColorRect
	var initial_prismatic_color := prismatic_accent.modulate
	overlay.visible = true
	buttons[2].get_node("CardArt").call("_process", 1.0)
	_expect(
		prismatic_accent.modulate != initial_prismatic_color,
		"Prismatic tier has an animated spectral accent",
	)

	var enemy_augment := EnemyAugment.new()
	enemy_augment.display_name = "Enemy Test"
	enemy_augment.description = "Existing enemy card presentation"
	overlay.call("_set_choices", [enemy_augment])
	var enemy_tier_label := buttons[0].get_node("TierLabel") as Label
	var enemy_tier_accent := buttons[0].get_node("TierAccent") as ColorRect
	var enemy_style := buttons[0].get_theme_stylebox("normal") as StyleBoxFlat
	_expect(not enemy_tier_label.visible, "enemy augment cards do not show a player tier label")
	_expect(not enemy_tier_accent.visible, "enemy augment cards do not show a player tier accent")
	_expect(enemy_style.content_margin_top == 8.0, "enemy augment cards retain their original content spacing")

	overlay.queue_free()
	await process_frame
	if failures.is_empty():
		print("player augment tier smoke test: PASS")
		quit(0)
		return
	for failure in failures:
		push_error("player augment tier smoke test: %s" % failure)
	quit(1)


func _make_augment(
	augment_id: StringName,
	display_name: String,
	tier: PlayerAugment.Tier,
) -> PlayerAugment:
	var augment := PlayerAugment.new()
	augment.augment_id = augment_id
	augment.display_name = display_name
	augment.description = "Tier presentation test"
	augment.tier = tier
	return augment


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
