extends SceneTree

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
	for _i in 4:
		await process_frame

	var acquire_count := 0
	var trait_count := 0
	var facility_count := 0
	var rule_count := 0
	for augment in offer.player_augment_pool:
		match augment.augment_type:
			PlayerAugmentKind.Kind.WEAPON_ACQUIRE:
				acquire_count += 1
			PlayerAugmentKind.Kind.WEAPON_TRAIT:
				trait_count += 1
			PlayerAugmentKind.Kind.FACILITY_EFFECT:
				facility_count += 1
			PlayerAugmentKind.Kind.SHIP_RULE:
				rule_count += 1
	_expect(acquire_count == 7, "gameplay pool keeps seven weapon acquisition cards")
	_expect(trait_count == 36, "gameplay pool keeps 36 levelled weapon modules")
	_expect(facility_count == 13, "gameplay pool includes 13 facility modules")
	_expect(rule_count == 1, "gameplay pool includes the fourth-bay rule card")
	_expect(offer.player_augment_pool.size() == 57, "legacy weapon level cards are removed")

	_expect(loadout.is_weapon_equipped(&"main_blaster"), "starts with blaster")
	var laser_acq := load("res://resources/player_augments/weapon/acquire_main_laser.tres") as PlayerAugment
	_expect(offer._is_player_augment_available(laser_acq, loadout), "laser acquire is available")
	_expect(loadout.offer_equip_weapon(laser_acq.weapon_definition), "laser equips into empty bay")

	var rapid_loader := load(
		"res://resources/player_augments/weapon/trait_blaster_rapid_loader.tres"
	) as PlayerAugment
	_expect(offer._is_player_augment_available(rapid_loader, loadout), "module card is available")
	_expect(rapid_loader.get_offer_title(loadout).contains("Lv.I"), "new module card previews Lv.I")
	_expect(rapid_loader.tier == PlayerAugment.Tier.SILVER, "rapid loader is a silver module")
	_expect(
		rapid_loader.get_offer_description(loadout) == "연사 간격 ×0.93.",
		"new module card describes Lv.I values",
	)
	# Silver modules stack to Lv.V without trade-offs.
	var intervals := ["0.93", "0.87", "0.81", "0.76", "0.71"]
	var roman := ["", "I", "II", "III", "IV", "V"]
	for expected_rank in range(1, 6):
		_expect(
			loadout.add_or_upgrade_weapon_trait(
				&"main_blaster",
				rapid_loader.trait_id,
				rapid_loader.trait_rank_increase,
			) == expected_rank,
			"module advances to expected level",
		)
		if expected_rank < 5:
			_expect(
				rapid_loader.get_offer_title(loadout).contains(
					"Lv.%s" % roman[expected_rank + 1]
				),
				"module card previews its next level",
			)
			_expect(
				rapid_loader.get_offer_description(loadout)
				== "연사 간격 ×%s→%s." % [intervals[expected_rank - 1], intervals[expected_rank]],
				"module card shows current→next values for Lv.%d" % (expected_rank + 1),
			)
	_expect(
		not offer._is_player_augment_available(rapid_loader, loadout),
		"maxed module card leaves the offer pool",
	)

	var cannon := load("res://resources/weapons/definitions/aux_test_cannon.tres") as WeaponDefinition
	var shotgun := load("res://resources/weapons/definitions/main_shotgun.tres") as WeaponDefinition
	_expect(loadout.offer_equip_weapon(cannon), "third bay fills")
	_expect(not loadout.offer_equip_weapon(shotgun), "full bays require replace")
	var slot := loadout.find_equipped_slot(&"main_laser")
	_expect(loadout.request_replace_equipped(slot, shotgun), "replace API swaps a bay")
	_expect(not loadout.has_weapon_progress(&"main_laser"), "replaced progress deleted")
	_expect(loadout.get_weapon_traits(&"main_shotgun").is_empty(), "replacement starts without modules")

	_expect(offer.remaining_reroll_count == offer.max_reroll_count, "rerolls start full")

	world.queue_free()
	await process_frame
	if failures.is_empty():
		print("weapon augment acquisition test: PASS")
		quit()
		return
	for failure in failures:
		push_error("weapon augment acquisition test: %s" % failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
