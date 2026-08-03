extends SceneTree

var failures: PackedStringArray = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var world_scene: PackedScene = load("res://world.tscn")
	var world: Control = world_scene.instantiate() as Control
	root.add_child(world)
	var gameplay: Node = world.get_node("Layout/Playfield/ViewportContainer/PlayfieldViewport/Gameplay")
	var ship: Node2D = gameplay.get_node("Ship") as Node2D
	var loadout: PlayerWeaponLoadout = ship.call("get_weapon_loadout") as PlayerWeaponLoadout
	var weapon_hud: WeaponLoadoutHud = world.get_node(
		"Layout/RightPanel/Margin/VBox/WeaponBox/Margin/WeaponLoadoutHud"
	) as WeaponLoadoutHud
	for _index in 4:
		await process_frame

	weapon_hud.refresh()
	await process_frame

	_expect(weapon_hud.get_node("%SelectedWeaponTitle") != null, "selected weapon title exists")
	_expect(weapon_hud.get_node("%ModulesGrid") != null, "modules grid exists")
	_expect(weapon_hud.get_node("%SelectedWeaponName") != null, "selected weapon name exists")
	var name_label: Label = weapon_hud.get_node("%SelectedWeaponName") as Label
	_expect(name_label.text.contains("블래스터") or name_label.text.contains("Lv."), "auto-focuses starting weapon detail")

	loadout.add_or_upgrade_weapon_trait(&"main_blaster", &"blaster_pierce", 1)
	await process_frame
	weapon_hud.refresh()
	await process_frame
	var grid: GridContainer = weapon_hud.get_node("%ModulesGrid") as GridContainer
	_expect(grid.get_child_count() == 4, "module grid keeps four slots")
	var first_card := grid.get_child(0) as Control
	_expect(first_card != null, "first module card exists")
	var hex_nodes := first_card.find_children("*", "HexModuleFrame", true, false)
	_expect(not hex_nodes.is_empty(), "module card uses HexModuleFrame")
	var found_pierce := false
	for node in first_card.find_children("*", "Label", true, false):
		var label := node as Label
		if label != null and label.text.contains("관통"):
			found_pierce = true
			break
	_expect(found_pierce, "pierce trait shows display name")

	var laser: WeaponDefinition = load("res://resources/weapons/definitions/main_laser.tres") as WeaponDefinition
	loadout.equip_weapon(laser)
	await process_frame
	weapon_hud.refresh()
	await process_frame
	var bay_row: HBoxContainer = weapon_hud.get_node("%BayRow") as HBoxContainer
	_expect(bay_row.get_child_count() == loadout.get_max_equipped_weapon_count(), "bay row lists every slot equally")
	var laser_cluster: WeaponCoreCluster = null
	for child in bay_row.get_children():
		var cluster := child as WeaponCoreCluster
		if cluster != null and cluster.weapon_id == &"main_laser":
			laser_cluster = cluster
			break
	_expect(laser_cluster != null, "laser bay appears in equal row")
	_expect(
		(bay_row.get_child(0) as Control).get_combined_minimum_size()
		== laser_cluster.get_combined_minimum_size(),
		"bay hexes share the same size",
	)
	laser_cluster.core_selected.emit(laser_cluster.weapon_id, false)
	await process_frame
	weapon_hud.refresh()
	await process_frame
	name_label = weapon_hud.get_node("%SelectedWeaponName") as Label
	_expect(name_label.text.contains("레이저") or name_label.text.contains("Lv."), "focusing bay updates selected weapon")

	var ship_panel: ShipPanel = world.get_node("Layout/RightPanel/Margin/VBox/ShipPanel") as ShipPanel
	_expect(ship_panel.get_detail_text().contains(" : "), "facility detail shows name : slots by default")
	var hangar := ship_panel.get_facility_module(&"hangar")
	hangar.facility_hovered.emit(&"hangar")
	await process_frame
	_expect(ship_panel.get_detail_text().begins_with("격납고"), "hovering hangar updates facility detail line")

	var detail_cols := weapon_hud.get_node_or_null("%DetailColumns") as HBoxContainer
	_expect(detail_cols != null, "selected weapon and modules sit in side-by-side columns")

	if failures.is_empty():
		print("weapon status focus detail test: PASS")
		quit()
		return
	for failure in failures:
		push_error("weapon status focus detail test: %s" % failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
