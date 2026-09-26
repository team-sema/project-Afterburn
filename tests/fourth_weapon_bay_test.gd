extends SceneTree

## Prismatic rule card: fourth weapon bay with an all-weapon damage trade-off.

var failures: PackedStringArray = []


func _initialize() -> void:
	var music_player := root.get_node_or_null("MusicPlayer") as AudioStreamPlayer
	if music_player != null:
		music_player.stop()
		music_player.stream = null
	_run.call_deferred()


func _run() -> void:
	var world := load("res://world.tscn").instantiate() as Control
	root.add_child(world)
	var gameplay := world.get_node("Layout/Playfield/ViewportContainer/PlayfieldViewport/Gameplay")
	var ship := gameplay.get_node("Ship") as Node2D
	var loadout := ship.call("get_weapon_loadout") as PlayerWeaponLoadout
	var offer := gameplay.get_node("AugmentOfferController") as AugmentOfferController
	var slot_ui := offer.weapon_slot_ui
	var weapon_hud := world.get_node("Layout/RightPanel/Margin/VBox/WeaponBox/Margin/WeaponLoadoutHud")
	for _i in 4:
		await process_frame

	var card := load("res://resources/player_augments/rules/prism_fourth_weapon_bay.tres") as PlayerAugment
	_expect(card.tier == PlayerAugment.Tier.PRISMATIC, "fourth bay is a prismatic card")
	_expect(card.augment_type == PlayerAugmentKind.Kind.SHIP_RULE, "fourth bay is a rule card")
	_expect(loadout.get_max_equipped_weapon_count() == 3, "run starts with three bays")
	_expect(offer._is_player_augment_available(card, loadout), "fourth bay is offered at three bays")

	var blaster := loadout.get_bay(0).equipped_weapon_instance as WeaponSystem
	var damage_before := blaster.get_effective_damage_multiplier()
	_expect(await offer._resolve_player_augment(card), "fourth bay resolves")
	_expect(loadout.get_max_equipped_weapon_count() == 4, "loadout now has four bays")
	_expect(not offer._is_player_augment_available(card, loadout), "fourth bay is one-time")
	_expect(
		is_equal_approx(blaster.get_effective_damage_multiplier(), damage_before * 0.85),
		"equipped weapons take the ×0.85 trade-off",
	)

	for path in [
		"res://resources/weapons/definitions/main_laser.tres",
		"res://resources/weapons/definitions/main_shotgun.tres",
		"res://resources/weapons/definitions/aux_test_cannon.tres",
	]:
		_expect(loadout.offer_equip_weapon(load(path) as WeaponDefinition), "%s fills a bay" % path.get_file())
	_expect(loadout.get_equipped_weapon_ids().size() == 4, "four weapons fire together")
	_expect(loadout.is_bays_full(), "four bays are full")
	var fourth := loadout.get_bay(3).equipped_weapon_instance as WeaponSystem
	_expect(
		fourth != null and is_equal_approx(fourth.get_effective_damage_multiplier(), damage_before * 0.85),
		"a weapon equipped later also takes the trade-off",
	)

	await process_frame
	_expect(weapon_hud.get("_bay_clusters").size() == 4, "STATUS shows four weapon bays")

	var plasma := load("res://resources/weapons/definitions/plasma_bomb.tres") as WeaponDefinition
	slot_ui.open_for_replace(loadout, "무기 교체", "", plasma)
	var visible_buttons := 0
	for button in slot_ui.slot_buttons:
		if button.visible and not button.disabled:
			visible_buttons += 1
	_expect(visible_buttons == 4, "replace overlay lists all four bays")
	slot_ui.close()

	world.queue_free()
	await process_frame
	if failures.is_empty():
		print("fourth_weapon_bay_test: PASS")
		quit()
		return
	for failure in failures:
		push_error("fourth_weapon_bay_test: %s" % failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
