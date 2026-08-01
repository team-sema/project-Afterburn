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
	var loadout: Node = ship.call("get_weapon_loadout")
	var weapon_hud: Node = world.get_node(
		"Layout/RightPanel/Margin/VBox/WeaponBox/Margin/WeaponLoadoutHud"
	)
	for _index in 4:
		await process_frame

	var blaster: WeaponDefinition = load(DEFINITION_PATHS[0]) as WeaponDefinition
	var main_module: HexModuleFrame = weapon_hud.get_node("MainRow/MainModule") as HexModuleFrame
	var main_icon: TextureRect = main_module.get_node("IconRect") as TextureRect
	var main_title: Label = main_module.get_node("TitleLabel") as Label
	var main_body: Label = main_module.get_node("BodyLabel") as Label

	_expect(main_icon.visible, "equipped main module shows its icon")
	_expect(main_icon.texture == blaster.icon, "main module uses the equipped weapon's icon")
	_expect(main_body.text == "Lv.1", "main module body carries only the weapon level")
	_expect(
		not main_body.text.contains(blaster.display_name),
		"main module no longer prints the weapon name",
	)
	_expect(main_title.text.contains("메인"), "main module keeps its slot title")
	_expect(
		main_icon.offset_top >= main_title.offset_bottom - 0.01,
		"icon sits below the slot title",
	)
	_expect(
		main_icon.offset_bottom <= main_body.offset_top + 0.01,
		"icon sits above the level text",
	)
	_expect(_fits_hexagon(main_module, main_icon), "icon stays inside the hexagon outline")

	var reserve_module: HexModuleFrame = weapon_hud.get_node("MainRow/ReserveModule") as HexModuleFrame
	var reserve_icon: TextureRect = reserve_module.get_node("IconRect") as TextureRect
	_expect(not reserve_icon.visible, "empty reserve module shows no icon")

	var laser: WeaponDefinition = load(DEFINITION_PATHS[1]) as WeaponDefinition
	loadout.call("equip_reserve_weapon", laser)
	await process_frame
	_expect(reserve_icon.visible, "stowed reserve weapon shows its icon")
	_expect(reserve_icon.texture == laser.icon, "reserve module uses the stowed weapon's icon")

	var owned_row: HBoxContainer = weapon_hud.get_node("OwnedMainRow") as HBoxContainer
	_expect(owned_row.get_child_count() >= 2, "owned main row lists tracked main weapons")
	var owned_module: HexModuleFrame = owned_row.get_child(0) as HexModuleFrame
	var owned_icon: TextureRect = owned_module.get_node("IconRect") as TextureRect
	var owned_title: Label = owned_module.get_node("TitleLabel") as Label
	_expect(owned_icon.visible, "owned main modules show icons")
	_expect(owned_title.text.is_empty(), "owned main modules drop the shortened name")

	var barrier: WeaponDefinition = load(DEFINITION_PATHS[6]) as WeaponDefinition
	loadout.call("equip_auxiliary_weapon", barrier, 0)
	await process_frame
	var aux_module: HexModuleFrame = weapon_hud.get_node("AuxRow/AuxModule1") as HexModuleFrame
	var aux_icon: TextureRect = aux_module.get_node("IconRect") as TextureRect
	var aux_body: Label = aux_module.get_node("BodyLabel") as Label
	_expect(aux_icon.visible, "equipped auxiliary module shows its icon")
	_expect(aux_icon.texture == barrier.icon, "auxiliary module uses the equipped weapon's icon")
	_expect(aux_body.text.is_empty(), "chargeless auxiliary weapons leave the body text empty")

	var cannon: WeaponDefinition = load(DEFINITION_PATHS[3]) as WeaponDefinition
	loadout.call("equip_auxiliary_weapon", cannon, 1)
	await process_frame
	var cannon_module: HexModuleFrame = weapon_hud.get_node("AuxRow/AuxModule2") as HexModuleFrame
	var cannon_icon: TextureRect = cannon_module.get_node("IconRect") as TextureRect
	var cannon_body: Label = cannon_module.get_node("BodyLabel") as Label
	_expect(cannon_icon.texture == cannon.icon, "consumable auxiliary module shows its icon")
	_expect(cannon_body.text.contains("/"), "consumable auxiliary module keeps its charge counter")
	_expect(
		not cannon_body.text.contains(cannon.display_name),
		"consumable auxiliary module no longer prints the weapon name",
	)

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


## Every icon corner must be inside the flat-top hexagon the frame draws.
func _fits_hexagon(module: HexModuleFrame, icon: TextureRect) -> bool:
	var radius: float = minf(module.size.x, module.size.y) * 0.48
	var center := module.size * 0.5
	for corner in [
		Vector2(icon.offset_left, icon.offset_top),
		Vector2(icon.offset_right, icon.offset_top),
		Vector2(icon.offset_left, icon.offset_bottom),
		Vector2(icon.offset_right, icon.offset_bottom),
	]:
		var offset: Vector2 = corner - center
		if absf(offset.y) > radius * 0.866025 + 0.01:
			return false
		if absf(offset.x) > radius - 0.577350 * absf(offset.y) + 0.01:
			return false
	return true
