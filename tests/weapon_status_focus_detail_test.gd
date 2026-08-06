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
	_expect(weapon_hud.get_node("%DetailRule") != null, "detail rule line exists")
	var name_label: Label = weapon_hud.get_node("%SelectedWeaponName") as Label
	_expect(name_label.text.contains("블래스터") or name_label.text.contains("Lv."), "auto-focuses starting weapon detail")
	var footer: Label = weapon_hud.get_node("%WeaponDetailFooter") as Label
	_expect(footer.text.contains("블래스터") or footer.text.contains("발사"), "footer shows selected weapon description")

	loadout.add_or_upgrade_weapon_trait(&"main_blaster", &"blaster_accel_ap", 1)
	await process_frame
	weapon_hud.refresh()
	await process_frame
	var grid: HexHoneycombContainer = weapon_hud.get_node("%ModulesGrid") as HexHoneycombContainer
	_expect(grid.get_child_count() == 4, "module grid keeps four slots")
	_expect(is_equal_approx(grid.hex_side, 28.0), "equipped module hexes use the enlarged 28px size")
	var first_hex := grid.get_child(0) as HexModuleFrame
	var second_hex := grid.get_child(1) as HexModuleFrame
	_expect(first_hex != null, "equipped module is a bare HexModuleFrame")
	_expect(
		_hexes_share_edge(first_hex, second_hex),
		"equipped module hexes share a honeycomb edge without gaps",
	)
	_expect(loadout.get_trait_icon(&"blaster_accel_ap") != null, "blaster accel AP has a visible icon for STATUS")
	first_hex.module_hovered.emit()
	await process_frame
	footer = weapon_hud.get_node("%WeaponDetailFooter") as Label
	_expect(footer.text.contains("철갑") or footer.text.contains("관통"), "hovering module hex shows full trait name in description")

	var laser: WeaponDefinition = load("res://resources/weapons/definitions/main_laser.tres") as WeaponDefinition
	loadout.equip_weapon(laser)
	await process_frame
	weapon_hud.refresh()
	await process_frame
	var bay_row: HexHoneycombContainer = weapon_hud.get_node("%BayRow") as HexHoneycombContainer
	_expect(bay_row.get_child_count() == loadout.get_max_equipped_weapon_count(), "bay row lists every slot equally")
	_expect(is_equal_approx(bay_row.hex_side, 48.0), "weapon bay hexes use the enlarged 48px size")
	var first_bay := bay_row.get_child(0) as WeaponCoreCluster
	var second_bay := bay_row.get_child(1) as WeaponCoreCluster
	_expect(
		_hexes_share_edge(first_bay.get_node("%Core") as HexModuleFrame, second_bay.get_node("%Core") as HexModuleFrame),
		"weapon bay hexes share a honeycomb edge without gaps",
	)
	var laser_cluster: WeaponCoreCluster = null
	for child in bay_row.get_children():
		var cluster := child as WeaponCoreCluster
		if cluster != null and cluster.weapon_id == &"main_laser":
			laser_cluster = cluster
			break
	_expect(laser_cluster != null, "laser bay appears in equal row")
	_expect(
		is_equal_approx(
			laser_cluster.slot_size.x,
			weapon_hud.get_node("%BaySlotTemplate").custom_minimum_size.x
		),
		"bay hex matches BaySlotTemplate size",
	)
	_expect(weapon_hud.get_node("%SelectedWeaponHex") != null, "selected weapon uses scene placeholder hex")
	_expect(weapon_hud.get_node("%ModuleHexTemplate") != null, "module hex template placeholder exists")
	laser_cluster.core_hovered.emit(laser_cluster.weapon_id, false)
	await process_frame
	name_label = weapon_hud.get_node("%SelectedWeaponName") as Label
	_expect(name_label.text.contains("레이저") or name_label.text.contains("Lv."), "hovering bay updates selected weapon")
	_expect(laser_cluster.is_focused, "hovered bay is marked focused without row rebuild")
	footer = weapon_hud.get_node("%WeaponDetailFooter") as Label
	_expect(footer.text.contains("레이저") or footer.text.contains("빔"), "footer follows hovered weapon description")

	var ship_panel: ShipPanel = world.get_node("Layout/RightPanel/Margin/VBox/ShipPanel") as ShipPanel
	_expect(
		ship_panel.get_detail_text().contains("범용 슬롯 0/5"),
		"facility detail shows universal slot usage by default",
	)
	ship_panel.slot_rack.slot_hovered.emit(0)
	await process_frame
	_expect(
		ship_panel.get_detail_text().contains("슬롯 1 · 빈 슬롯"),
		"hovering an empty hex updates its slot detail",
	)
	ship_panel.slot_rack.slot_hover_exited.emit()

	var detail_cols := weapon_hud.get_node_or_null("%DetailColumns") as HBoxContainer
	_expect(detail_cols != null, "selected weapon and modules sit in side-by-side columns")
	var footer_clip := weapon_hud.get_node_or_null("%WeaponDetailFooterClip") as Control
	var layout := world.get_node("Layout") as Control
	var right_panel := world.get_node("Layout/RightPanel") as Control
	var right_box := world.get_node("Layout/RightPanel/Margin/VBox") as VBoxContainer
	var right_margin := world.get_node("Layout/RightPanel/Margin") as MarginContainer
	_expect(footer_clip != null, "weapon description uses a fixed clipping region")
	var layout_size_before := layout.size
	var right_minimum_before := right_box.get_combined_minimum_size()
	weapon_hud._set_description(
		"긴 설명\n두 번째 줄\n세 번째 줄은 레이아웃을 늘리지 않아야 합니다."
		+ "\n네 번째 줄\n다섯 번째 줄"
	)
	await process_frame
	await process_frame
	var margin_height := float(
		right_margin.get_theme_constant("margin_top")
		+ right_margin.get_theme_constant("margin_bottom")
	)
	_expect(footer.max_lines_visible == 2, "weapon description is limited to two visible lines")
	_expect(footer.clip_text, "weapon description clips overflow text")
	_expect(
		is_equal_approx(footer_clip.size.y, 28.0),
		"weapon description region keeps its fixed two-line height",
	)
	_expect(layout.size == layout_size_before, "long weapon descriptions do not resize the world layout")
	_expect(
		right_box.get_combined_minimum_size().y <= right_minimum_before.y + 0.5,
		"long weapon descriptions do not increase the right rail minimum height",
	)
	_expect(
		right_panel.size.y <= layout.size.y + 0.5
		and right_box.get_combined_minimum_size().y <= layout.size.y - margin_height + 0.5,
		"long weapon descriptions stay inside the 640x360 shell",
	)

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


func _hexes_share_edge(first: HexModuleFrame, second: HexModuleFrame) -> bool:
	if first == null or second == null:
		return false
	var first_polygon := first.get_hex_polygon()
	var second_polygon := second.get_hex_polygon()
	if first_polygon.size() != 6 or second_polygon.size() != 6:
		return false
	var first_origin := first.get_global_transform_with_canvas().origin
	var second_origin := second.get_global_transform_with_canvas().origin
	return (
		(first_origin + first_polygon[0]).is_equal_approx(second_origin + second_polygon[4])
		and (first_origin + first_polygon[1]).is_equal_approx(second_origin + second_polygon[3])
	)
