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
	var laser_acq := load("res://resources/player_augments/weapon/acquire_main_laser.tres") as PlayerAugment
	_expect(offer._is_player_augment_available(laser_acq, loadout), "laser acquire is available")
	_expect(loadout.offer_equip_weapon(laser_acq.weapon_definition, 1), "laser equips into empty bay")

	var level_blaster := load("res://resources/player_augments/weapon/level_main_blaster.tres") as PlayerAugment
	_expect(offer._is_player_augment_available(level_blaster, loadout), "blaster level card available")
	_expect(loadout.upgrade_weapon_level(&"main_blaster"), "blaster levels via offer path")

	var cannon := load("res://resources/weapons/definitions/aux_test_cannon.tres") as WeaponDefinition
	var shotgun := load("res://resources/weapons/definitions/main_shotgun.tres") as WeaponDefinition
	_expect(loadout.offer_equip_weapon(cannon, 1), "third bay fills")
	_expect(not loadout.offer_equip_weapon(shotgun, 1), "full bays require replace")
	var slot := loadout.find_equipped_slot(&"main_laser")
	_expect(loadout.request_replace_equipped(slot, shotgun, 1), "replace API swaps a bay")
	_expect(not loadout.has_weapon_progress(&"main_laser"), "replaced progress deleted")
	_expect(loadout.get_weapon_level(&"main_shotgun") == 1, "replacement starts fresh")

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
