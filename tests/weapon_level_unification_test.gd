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

	_expect(loadout.is_weapon_equipped(&"main_blaster"), "blaster starts equipped")
	_expect(not loadout.has_method("get_weapon_level"), "weapon core level API is removed")
	_expect(
		loadout.add_or_upgrade_weapon_trait(&"main_blaster", &"blaster_rapid_loader", 1) == 1,
		"module starts at Lv.I",
	)
	_expect(
		loadout.add_or_upgrade_weapon_trait(&"main_blaster", &"blaster_rapid_loader", 1) == 2,
		"module reaches Lv.II",
	)
	_expect(
		loadout.add_or_upgrade_weapon_trait(&"main_blaster", &"blaster_rapid_loader", 1) == 3,
		"module reaches Lv.III",
	)
	_expect(
		not loadout.can_upgrade_weapon_trait(&"main_blaster", &"blaster_rapid_loader"),
		"maxed module cannot upgrade",
	)
	var blaster := loadout.get_bay(0).equipped_weapon_instance as WeaponSystem
	_expect(
		is_equal_approx(
			float(blaster.get_trait_param(&"blaster_rapid_loader", &"fire_interval_mult", 1.0)),
			0.52
		),
		"module Lv.III resolves its explicit combat params",
	)

	var laser := load("res://resources/weapons/definitions/main_laser.tres") as WeaponDefinition
	_expect(loadout.offer_equip_weapon(laser), "laser equips into an empty bay")
	_expect(loadout.get_equipped_weapon_ids().size() == 2, "two weapons fire together")

	var cannon := load("res://resources/weapons/definitions/aux_test_cannon.tres") as WeaponDefinition
	_expect(loadout.offer_equip_weapon(cannon), "third bay accepts cannon")
	_expect(loadout.is_bays_full(), "default three bays are full")
	_expect(
		not loadout.offer_equip_weapon(
			load("res://resources/weapons/definitions/main_shotgun.tres") as WeaponDefinition
		),
		"full bays need replace",
	)

	var laser_slot := loadout.find_equipped_slot(&"main_laser")
	_expect(
		loadout.request_replace_equipped(
			laser_slot,
			load("res://resources/weapons/definitions/main_shotgun.tres") as WeaponDefinition
		),
		"replace works",
	)
	_expect(not loadout.has_weapon_progress(&"main_laser"), "replaced weapon progress deleted")

	weapon_hud.call("refresh")
	await process_frame
	_expect(weapon_hud.has_node("%BayRow"), "STATUS HUD has bay row")
	_expect(not weapon_hud.has_node("%RecordsScroll"), "STATUS records scroll removed")
	_expect(not weapon_hud.has_node("MainSwapHint"), "Z swap hint is removed")

	world.queue_free()
	await process_frame
	if failures.is_empty():
		print("weapon module level test: PASS")
		quit()
		return
	for failure in failures:
		push_error("weapon module level test: %s" % failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
