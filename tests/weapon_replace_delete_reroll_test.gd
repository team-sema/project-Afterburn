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
	var weapon_hud := world.get_node(
		"Layout/RightPanel/Margin/VBox/WeaponBox/Margin/WeaponLoadoutHud"
	)
	for _i in 4:
		await process_frame

	_expect(loadout.is_weapon_equipped(&"main_blaster"), "starts with blaster")
	_expect(not weapon_hud.has_node("%RecordsScroll"), "STATUS records UI removed")
	_expect(weapon_hud.has_node("%BayRow"), "STATUS bay row remains")

	var laser := load("res://resources/weapons/definitions/main_laser.tres") as WeaponDefinition
	_expect(loadout.offer_equip_weapon(laser), "laser equips")
	loadout.add_or_upgrade_weapon_trait(&"main_laser", &"laser_refract", 2)
	_expect(int(loadout.get_weapon_traits(&"main_laser")[&"laser_refract"]) == 2, "laser module leveled")

	var shotgun := load("res://resources/weapons/definitions/main_shotgun.tres") as WeaponDefinition
	var cannon := load("res://resources/weapons/definitions/aux_test_cannon.tres") as WeaponDefinition
	_expect(loadout.offer_equip_weapon(cannon), "third bay fills")
	_expect(loadout.is_bays_full(), "bays full")
	var laser_slot := loadout.find_equipped_slot(&"main_laser")
	_expect(laser_slot >= 0, "laser slot known")
	_expect(loadout.request_replace_equipped(laser_slot, shotgun), "replace deletes old growth")
	_expect(not loadout.has_weapon_progress(&"main_laser"), "replaced laser progress deleted")
	_expect(loadout.is_weapon_equipped(&"main_shotgun"), "shotgun equipped")
	_expect(loadout.get_weapon_traits(&"main_shotgun").is_empty(), "new weapon has no modules")

	# Re-acquire laser after delete → fresh
	loadout.unequip_weapon(&"main_shotgun")
	loadout.clear_weapon_progress(&"main_shotgun")
	_expect(loadout.offer_equip_weapon(laser), "laser reacquired fresh")
	_expect(loadout.get_weapon_traits(&"main_laser").is_empty(), "reacquire has no modules")

	var module_card := load(
		"res://resources/player_augments/weapon/trait_laser_refract.tres"
	) as PlayerAugment
	_expect(offer._is_player_augment_available(module_card, loadout), "module card for equipped laser")
	loadout.unequip_weapon(&"main_laser")
	loadout.clear_weapon_progress(&"main_laser")
	_expect(not offer._is_player_augment_available(module_card, loadout), "module card hidden when unequipped")

	_expect(offer.max_reroll_count == 2, "default max reroll is 2")
	_expect(offer.remaining_reroll_count == 2, "run starts with full rerolls")

	world.queue_free()
	await process_frame
	if failures.is_empty():
		print("weapon replace delete reroll test: PASS")
		quit()
		return
	for failure in failures:
		push_error("weapon replace delete reroll test: %s" % failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
