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
	var weapon_hud := world.get_node(
		"Layout/RightPanel/Margin/VBox/WeaponBox/Margin/WeaponLoadoutHud"
	)
	for _index in 4:
		await process_frame

	_expect(loadout.get_weapon_level(&"main_blaster") == 1, "default weapon starts at Lv.1")
	_expect(loadout.is_weapon_equipped(&"main_blaster"), "blaster starts equipped")
	_expect(loadout.upgrade_weapon_level(&"main_blaster"), "level up works")
	_expect(loadout.get_weapon_level(&"main_blaster") == 2, "blaster reaches Lv.2")
	var blaster := loadout.get_all_weapon_systems()[0]
	_expect(
		is_equal_approx(blaster.get_effective_damage_multiplier(), 1.2),
		"Lv.2 weapon receives damage multiplier",
	)

	var laser := load("res://resources/weapons/definitions/main_laser.tres") as WeaponDefinition
	_expect(loadout.offer_equip_weapon(laser), "laser equips into an empty bay")
	_expect(loadout.get_weapon_level(&"main_laser") == 1, "new weapon starts at Lv.1")
	_expect(loadout.get_equipped_weapon_ids().size() == 2, "two weapons fire together")

	_expect(loadout.unequip_weapon(&"main_laser"), "laser can move to records")
	_expect(not loadout.is_weapon_equipped(&"main_laser"), "laser is recorded not equipped")
	_expect(loadout.get_recorded_weapons().size() == 1, "recorded weapons list includes laser")
	_expect(loadout.get_weapon_level(&"main_laser") == 1, "recorded level is preserved")

	_expect(loadout.offer_equip_weapon(laser), "recorded laser re-equips with saved level")
	_expect(loadout.get_weapon_level(&"main_laser") == 1, "reacquire default does not auto +1")
	loadout.upgrade_weapon_level(&"main_laser")
	loadout.upgrade_weapon_level(&"main_laser")
	_expect(loadout.get_weapon_level(&"main_laser") == 3, "laser reaches max level")
	_expect(not loadout.can_upgrade_weapon(&"main_laser"), "Lv.3 is maxed")

	var cannon := load("res://resources/weapons/definitions/aux_test_cannon.tres") as WeaponDefinition
	_expect(loadout.offer_equip_weapon(cannon), "third bay accepts cannon")
	_expect(loadout.is_bays_full(), "default three bays are full")
	_expect(
		not loadout.offer_equip_weapon(
			load("res://resources/weapons/definitions/main_shotgun.tres") as WeaponDefinition
		),
		"full bays leave new offers needing replace",
	)

	loadout.add_or_upgrade_weapon_trait(&"main_blaster", &"pierce_stub", 1)
	_expect(
		int(loadout.get_weapon_traits(&"main_blaster").get(&"pierce_stub", 0)) == 1,
		"trait ranks are stored on weapon_id",
	)

	weapon_hud.call("refresh")
	await process_frame
	_expect(weapon_hud.has_node("%BayRow"), "STATUS HUD has bay row")
	_expect(weapon_hud.has_node("%RecordsScroll"), "STATUS HUD has records scroll")
	_expect(not weapon_hud.has_node("MainSwapHint"), "Z swap hint is removed")
	_expect(not weapon_hud.has_node("BlockNewMainStatus"), "X block status is removed")

	world.queue_free()
	await process_frame
	if failures.is_empty():
		print("weapon level unification test: PASS")
		quit()
		return
	for failure in failures:
		push_error("weapon level unification test: %s" % failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
