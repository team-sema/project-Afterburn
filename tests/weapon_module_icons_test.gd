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
	_expect(bay_row.get_child_count() == loadout.get_max_equipped_weapon_count(), "bay count matches setting")
	var first_cluster := bay_row.get_child(0) as WeaponCoreCluster
	_expect(first_cluster != null, "bay row hosts weapon core clusters")
	_expect(first_cluster.weapon_id == &"main_blaster", "first bay shows starting blaster")

	var laser: WeaponDefinition = load(DEFINITION_PATHS[1]) as WeaponDefinition
	loadout.equip_weapon(laser)
	await process_frame
	weapon_hud.call("refresh")
	await process_frame
	_expect(bay_row.get_child(1).weapon_id == &"main_laser", "second bay shows laser icon cluster")

	loadout.unequip_weapon(&"main_laser")
	await process_frame
	weapon_hud.call("refresh")
	await process_frame
	_expect(not loadout.has_weapon_progress(&"main_laser"), "unequip deletes weapon growth")
	_expect(not weapon_hud.has_node("%RecordsScroll"), "no records UI")
	_expect(bay_row.get_child(1).weapon_id == &"", "second bay empty after unequip")

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
