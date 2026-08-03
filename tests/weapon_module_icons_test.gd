extends SceneTree

const DEFINITION_PATHS: PackedStringArray = [
	"res://resources/weapons/definitions/main_blaster.tres",
	"res://resources/weapons/definitions/main_laser.tres",
	"res://resources/weapons/definitions/main_shotgun.tres",
	"res://resources/weapons/definitions/aux_test_cannon.tres",
	"res://resources/weapons/definitions/aux_test_flak.tres",
	"res://resources/weapons/definitions/aux_homing_missile.tres",
	"res://resources/weapons/definitions/aux_orbital_barrier.tres",
]

var failures: PackedStringArray = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for definition_path in DEFINITION_PATHS:
		var definition: WeaponDefinition = load(definition_path) as WeaponDefinition
		_expect(definition != null, "%s loads as a WeaponDefinition" % definition_path)
		if definition == null:
			continue
		_expect(definition.icon != null, "%s declares an icon" % String(definition.id))

	var world_scene: PackedScene = load("res://world.tscn")
	var world: Control = world_scene.instantiate() as Control
	root.add_child(world)
	var gameplay: Node = world.get_node("Layout/Playfield/ViewportContainer/PlayfieldViewport/Gameplay")
	var ship: Node2D = gameplay.get_node("Ship") as Node2D
	var loadout: PlayerWeaponLoadout = ship.call("get_weapon_loadout") as PlayerWeaponLoadout
	var weapon_hud: Node = world.get_node(
		"Layout/RightPanel/Margin/VBox/WeaponBox/Margin/WeaponLoadoutHud"
	)
	for _index in 4:
		await process_frame

	weapon_hud.call("refresh")
	await process_frame
	var bay_row: HBoxContainer = weapon_hud.get_node("%BayRow") as HBoxContainer
	_expect(bay_row.get_child_count() >= 1, "bay row has focus cluster")
	var first_cluster := bay_row.get_child(0) as WeaponCoreCluster
	_expect(first_cluster != null, "bay row hosts focused weapon core")
	_expect(first_cluster.weapon_id == &"main_blaster", "focus cluster shows starting blaster")

	var laser: WeaponDefinition = load(DEFINITION_PATHS[1]) as WeaponDefinition
	loadout.equip_weapon(laser)
	await process_frame
	weapon_hud.call("refresh")
	await process_frame
	_expect(bay_row.get_child_count() == loadout.get_max_equipped_weapon_count(), "bay row keeps equal slots")
	var laser_cluster: WeaponCoreCluster = null
	for child in bay_row.get_children():
		var cluster := child as WeaponCoreCluster
		if cluster != null and cluster.weapon_id == &"main_laser":
			laser_cluster = cluster
			break
	_expect(laser_cluster != null and laser_cluster.weapon_id == &"main_laser", "equal row shows laser")
	_expect(
		(bay_row.get_child(0) as Control).get_combined_minimum_size().x
		== laser_cluster.get_combined_minimum_size().x,
		"all bay hexes use the same width",
	)

	loadout.unequip_weapon(&"main_laser")
	await process_frame
	weapon_hud.call("refresh")
	await process_frame
	_expect(not loadout.has_weapon_progress(&"main_laser"), "unequip deletes weapon growth")
	_expect(not weapon_hud.has_node("%RecordsScroll"), "no records UI")
	var empty_or_other := false
	for child in bay_row.get_children():
		var cluster := child as WeaponCoreCluster
		if cluster != null and cluster.weapon_id == &"":
			empty_or_other = true
			break
	_expect(empty_or_other, "unequip leaves an empty equal-size bay")
	var selected_name: Label = weapon_hud.get_node("%SelectedWeaponName") as Label
	_expect(selected_name != null, "selected weapon detail label exists")
	_expect(weapon_hud.get_node("%ModulesGrid") != null, "equipped modules grid exists")

	if failures.is_empty():
		print("weapon module icons test: PASS")
		quit()
		return
	for failure in failures:
		push_error("weapon module icons test: %s" % failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
