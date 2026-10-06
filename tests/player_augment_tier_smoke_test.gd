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
	root.add_child(gameplay)
	await process_frame
	var offer_controller := gameplay.get_node("AugmentOfferController") as AugmentOfferController
	_expect(offer_controller.player_augment_pool.size() == 64, "the current player augment pool remains intact")
	# Silver 7 acquire + 14 weapon + 8 facility · Gold 22 weapon + 5 facility · Prismatic 2.
	var tier_counts := [0, 0, 0]
	for augment in offer_controller.player_augment_pool:
		tier_counts[int(augment.tier)] += 1
		if augment.augment_type == PlayerAugmentKind.Kind.WEAPON_ACQUIRE:
			_expect(augment.tier == PlayerAugment.Tier.SILVER, "%s acquisition is Silver" % augment.augment_id)
	_expect(tier_counts == [28, 25, 11], "pool splits into 28 Silver / 25 Gold / 11 Prismatic (got %s)" % str(tier_counts))
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

	var buttons: Array[Button] = overlay.choice_buttons
	var expected_labels := ["SILVER", "GOLD", "PRISMATIC"]
	var card_scenes: Array[String] = []
	for index in buttons.size():
		var art := buttons[index].get_node("CardArt") as Control
		var tier_label := art.get_node("TierLabel") as Label
		var tier_accent := art.get_node("TierAccent") as ColorRect
		_expect(tier_label.visible, "player augment tier label %d is visible" % index)
		_expect(tier_label.text == expected_labels[index], "player augment tier label %d is correct" % index)
		_expect(tier_accent.visible, "player augment tier accent %d is visible" % index)
		_expect(
			buttons[index].get_theme_stylebox("disabled") == buttons[index].get_theme_stylebox("normal"),
			"tier %d keeps disabled and normal card geometry aligned" % index,
		)
		card_scenes.append(art.scene_file_path)
	_expect(
		card_scenes[0] != card_scenes[1]
		and card_scenes[1] != card_scenes[2]
		and card_scenes[0] != card_scenes[2],
		"Silver, Gold, and Prismatic use distinct card scenes",
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
	var enemy_art := buttons[0].get_node("CardArt") as Control
	_expect(
		enemy_art.scene_file_path == "res://menus/cards/augment_card_enemy.tscn",
		"enemy augments use the red enemy card scene",
	)
	_expect((enemy_art.get_node("TierLabel") as Label).text == "THREAT", "enemy cards show THREAT instead of a tier")
	_expect((enemy_art.get_node("Title") as Label).text == "Enemy Test", "enemy card shows the augment name")
	_expect(
		(enemy_art.get_node("Icon") as TextureRect).texture != null,
		"enemy cards without an icon use the shared threat icon",
	)

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
