extends SceneTree

var failures: PackedStringArray = []


func _initialize() -> void:
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
	_expect(
		gameplay.get_node("WeaponAcquisitionController").try_collect(
			load("res://resources/weapons/definitions/main_laser.tres")
		) == false,
		"field acquisition is disabled",
	)

	var laser_acq := load("res://resources/player_augments/weapon/acquire_main_laser.tres") as PlayerAugment
	_expect(offer._is_player_augment_available(laser_acq, loadout), "laser acquire is available")
	_expect(loadout.offer_equip_weapon(laser_acq.weapon_definition, 1), "laser equips into empty bay")

	var level_blaster := load("res://resources/player_augments/weapon/level_main_blaster.tres") as PlayerAugment
	_expect(offer._is_player_augment_available(level_blaster, loadout), "blaster level card available")
	_expect(loadout.upgrade_weapon_level(&"main_blaster"), "blaster levels via offer path")
	_expect(loadout.get_weapon_level(&"main_blaster") == 2, "blaster is Lv.2")

	loadout.unequip_weapon(&"main_laser")
	_expect(laser_acq.get_offer_title(loadout).contains("복원"), "recorded weapon shows restore text")
	_expect(loadout.offer_equip_weapon(laser_acq.weapon_definition, 1), "restore equips")
	_expect(loadout.get_weapon_level(&"main_laser") == 1, "restore does not auto +1")

	var cannon := load("res://resources/weapons/definitions/aux_test_cannon.tres") as WeaponDefinition
	var shotgun := load("res://resources/weapons/definitions/main_shotgun.tres") as WeaponDefinition
	_expect(loadout.offer_equip_weapon(cannon, 1), "third bay fills")
	_expect(loadout.is_bays_full(), "bays are full")
	_expect(not loadout.offer_equip_weapon(shotgun, 1), "full bays require replace")
	_expect(loadout.request_replace_equipped(1, shotgun, 1), "replace API swaps a bay")
	_expect(loadout.is_weapon_equipped(&"main_shotgun"), "shotgun equipped after replace")
	_expect(loadout.has_weapon_progress(&"main_laser") or loadout.has_weapon_progress(&"main_blaster") or loadout.has_weapon_progress(&"aux_test_cannon"), "replaced weapons stay in progress")

	var trait_card := load("res://resources/player_augments/weapon/trait_blaster_pierce.tres") as PlayerAugment
	if loadout.is_weapon_equipped(&"main_blaster"):
		_expect(offer._is_player_augment_available(trait_card, loadout), "trait available for equipped blaster")
		loadout.add_or_upgrade_weapon_trait(&"main_blaster", &"blaster_pierce", 1)
		_expect(int(loadout.get_weapon_traits(&"main_blaster")[&"blaster_pierce"]) == 1, "trait rank stored")
	else:
		# Blaster may have been replaced; still verify storage API.
		loadout.add_or_upgrade_weapon_trait(&"main_blaster", &"blaster_pierce", 1)
		_expect(int(loadout.get_weapon_traits(&"main_blaster")[&"blaster_pierce"]) == 1, "trait rank stored on recorded id")

	var enemy := load("res://enemies/enemy.tscn").instantiate() as Node
	var xp := enemy.get_node("ExperienceDropComponent") as ExperienceDropComponent
	_expect(is_equal_approx(xp.drop_chance, 0.62), "base enemy XP drop_chance is 0.62")
	var weapon_drop := enemy.get_node("WeaponDropComponent") as WeaponDropComponent
	_expect(weapon_drop.enabled == false, "weapon drop disabled")
	enemy.queue_free()

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
