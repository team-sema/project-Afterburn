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

	_expect(loadout.is_weapon_equipped(&"main_blaster"), "starts with blaster")
	_expect(not loadout.is_bays_full(), "start has empty weapon bays")
	_expect(
		offer.acquire_weight_has_empty_bay > offer.trait_weight_has_empty_bay,
		"empty-bay acquire multiplier exceeds trait",
	)
	_expect(
		offer.acquire_weight_bays_full > 0.0
		and offer.acquire_weight_bays_full < offer.acquire_weight_has_empty_bay,
		"full-bay acquire multiplier is reduced but non-zero",
	)
	_expect(
		offer.trait_weight_bays_full >= offer.trait_weight_has_empty_bay,
		"full-bay module multiplier is not reduced (growth matters once bays are set)",
	)
	# Category multipliers act inside one offer tier; pin the offer to Silver,
	# where acquisition cards live, so the mix below measures the multipliers.
	offer.silver_offer_weight = 100.0
	offer.gold_offer_weight = 0.0
	offer.prismatic_offer_weight = 0.0

	var empty_acquire := 0
	var empty_trait := 0
	var empty_offers_with_acquire := 0
	for _n in 80:
		var picks := offer._pick_player_choices()
		_expect(picks.size() == 3, "offer always returns three choices")
		var saw_acquire := false
		for pick in picks:
			match pick.augment_type:
				PlayerAugmentKind.Kind.WEAPON_ACQUIRE:
					empty_acquire += 1
					saw_acquire = true
				PlayerAugmentKind.Kind.WEAPON_TRAIT:
					empty_trait += 1
		if saw_acquire:
			empty_offers_with_acquire += 1
	_expect(empty_acquire > empty_trait, "with empty bays, acquires outnumber traits")
	_expect(
		empty_offers_with_acquire > 0 and empty_offers_with_acquire < 80,
		"acquires appear by weight, not every offer",
	)

	var laser := load("res://resources/weapons/definitions/main_laser.tres") as WeaponDefinition
	var barrier := load("res://resources/weapons/definitions/aux_orbital_barrier.tres") as WeaponDefinition
	_expect(loadout.offer_equip_weapon(laser), "equip laser")
	_expect(loadout.offer_equip_weapon(barrier), "equip barrier")
	_expect(loadout.is_bays_full(), "bays are full")

	var full_acquire := 0
	var full_trait := 0
	var full_offers_with_acquire := 0
	for _n in 80:
		var picks := offer._pick_player_choices()
		var saw_acquire := false
		for pick in picks:
			match pick.augment_type:
				PlayerAugmentKind.Kind.WEAPON_ACQUIRE:
					full_acquire += 1
					saw_acquire = true
				PlayerAugmentKind.Kind.WEAPON_TRAIT:
					full_trait += 1
		if saw_acquire:
			full_offers_with_acquire += 1
	_expect(full_offers_with_acquire > 0, "full bays still allow some acquire offers")
	_expect(
		full_offers_with_acquire < empty_offers_with_acquire,
		"full bays show acquires less often than empty bays",
	)

	var baseline := offer._pick_player_choices()
	offer._current_player_choices = baseline.duplicate()
	offer.is_offer_active = true
	offer.active_offer_type = AugmentOfferController.OfferType.PLAYER
	offer._awaiting_final_choice = true
	offer.remaining_reroll_count = 2
	offer.selection_ui._set_choices(baseline)
	var focus := 0
	var preferred_kind: PlayerAugmentKind.Kind = baseline[0].augment_type
	for index in baseline.size():
		preferred_kind = baseline[index].augment_type
		focus = index
		break
	offer.selection_ui._focused_choice_index = focus
	var before_id := baseline[focus].augment_id
	offer._on_reroll_requested(focus)
	var after := offer._current_player_choices[focus]
	_expect(after != null and after.augment_id != before_id, "reroll replaces focused card")
	_expect(after.augment_type == preferred_kind, "reroll keeps focused kind when possible")

	if failures.is_empty():
		print("offer category mix test: PASS")
		print(
			"empty acquire/trait/offers=%d/%d/%d; full=%d/%d/%d"
			% [
				empty_acquire,
				empty_trait,
				empty_offers_with_acquire,
				full_acquire,
				full_trait,
				full_offers_with_acquire,
			]
		)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("offer category mix test: FAIL (%d)" % failures.size())
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
