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
	var player_registry := gameplay.get_node("PlayerAugmentRegistry") as PlayerAugmentRegistry
	var augment_applier := ship.get_node("PlayerAugmentApplier") as PlayerAugmentApplier
	var weapon_hud := world.get_node(
		"Layout/RightPanel/Margin/VBox/WeaponBox/Margin/WeaponLoadoutHud"
	)
	var main_upgrade := load(
		"res://resources/player_augments/weapon/upgrade_main_weapon.tres"
	) as PlayerAugment
	var auxiliary_upgrade := load(
		"res://resources/player_augments/weapon/upgrade_auxiliary_weapon.tres"
	) as PlayerAugment
	for _index in 4:
		await process_frame

	var main_slot := loadout.get_main_slot()
	_expect(not _has_property(main_slot, &"level"), "weapon slots no longer carry a level")
	_expect(loadout.get_weapon_level(&"main_blaster") == 1, "default main weapon starts at Lv.1")
	player_registry.add_augment(main_upgrade)
	_expect(loadout.get_weapon_level(&"main_blaster") == 2, "main upgrade raises its weapon level")
	var blaster := main_slot.equipped_weapon_instance
	_expect(
		is_equal_approx(blaster.get_effective_damage_multiplier(), 1.2),
		"Lv.2 main weapon receives the unified damage multiplier",
	)

	var laser_definition := load(
		"res://resources/weapons/definitions/main_laser.tres"
	) as WeaponDefinition
	loadout.equip_reserve_weapon(laser_definition)
	_expect(loadout.get_weapon_level(&"main_laser") == 1, "reserve weapon keeps its own level")
	_expect(loadout.swap_main_and_reserve(), "main and reserve weapons swap")
	_expect(loadout.upgrade_equipped_main_weapon(), "newly equipped main weapon upgrades")
	_expect(loadout.get_weapon_level(&"main_laser") == 2, "main augment targets the active weapon")
	_expect(loadout.get_weapon_level(&"main_blaster") == 2, "stowed weapon keeps its prior level")

	var cannon_definition := load(
		"res://resources/weapons/definitions/aux_test_cannon.tres"
	) as WeaponDefinition
	loadout.equip_auxiliary_weapon(cannon_definition, 0)
	_expect(loadout.get_weapon_level(&"aux_test_cannon") == 1, "auxiliary weapon starts at Lv.1")
	augment_applier.set_pending_auxiliary_weapon_slot(0)
	player_registry.add_augment(auxiliary_upgrade)
	_expect(loadout.get_weapon_level(&"aux_test_cannon") == 2, "auxiliary upgrade raises weapon level")
	var cannon := loadout.get_auxiliary_slot(0).equipped_weapon_instance
	_expect(
		is_equal_approx(cannon.get_effective_damage_multiplier(), 1.2),
		"Lv.2 auxiliary weapon receives the unified damage multiplier",
	)

	loadout.clear_auxiliary_slot(0)
	loadout.equip_auxiliary_weapon(cannon_definition, 0)
	_expect(
		loadout.get_weapon_level(&"aux_test_cannon") == 2,
		"auxiliary weapon level survives removal and re-equip",
	)
	cannon = loadout.get_auxiliary_slot(0).equipped_weapon_instance
	_expect(
		is_equal_approx(cannon.get_effective_damage_multiplier(), 1.2),
		"re-equipped auxiliary weapon restores its level multiplier",
	)
	_expect(loadout.upgrade_auxiliary_weapon(0), "auxiliary weapon reaches Lv.3")
	_expect(not loadout.can_upgrade_auxiliary_weapon(0), "Lv.3 auxiliary weapon is maxed")
	_expect(
		is_equal_approx(cannon.get_effective_fire_rate_multiplier(), 1.2),
		"Lv.3 auxiliary weapon receives the unified fire-rate multiplier",
	)
	_expect(
		loadout.get_tracked_weapon_ids_by_category(WeaponDefinition.Category.AUXILIARY).has(
			&"aux_test_cannon"
		),
		"auxiliary progress uses the shared weapon-level registry",
	)

	weapon_hud.call("refresh")
	await process_frame
	var main_title := weapon_hud.get_node("MainRow/MainModule/TitleLabel") as Label
	var main_body := weapon_hud.get_node("MainRow/MainModule/BodyLabel") as Label
	var aux_title := weapon_hud.get_node("AuxRow/AuxModule1/TitleLabel") as Label
	_expect(main_title.text == "메인", "main slot title has no slot level")
	_expect(main_body.text == "Lv.2", "main module shows the weapon level once")
	_expect(aux_title.text == "A1 L3", "auxiliary module shows only its weapon level")

	world.queue_free()
	await process_frame
	if failures.is_empty():
		print("weapon level unification test: PASS")
		quit()
		return
	for failure in failures:
		push_error("weapon level unification test: %s" % failure)
	quit(1)


func _has_property(object: Object, property_name: StringName) -> bool:
	for property in object.get_property_list():
		if StringName(property["name"]) == property_name:
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
