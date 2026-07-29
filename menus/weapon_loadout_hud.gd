class_name WeaponLoadoutHud
extends VBoxContainer

const HEX_MODULE_SCENE := preload("res://menus/hex_module_frame.tscn")

@export var ship: Node2D

@onready var main_module: HexModuleFrame = $MainModule
@onready var owned_main_row: HBoxContainer = $OwnedMainRow
@onready var aux_row: HBoxContainer = $AuxRow

var _aux_modules: Array[HexModuleFrame] = []


func _ready() -> void:
	_ensure_aux_modules()
	if ship == null:
		return
	var loadout := _get_loadout()
	if loadout == null:
		return
	loadout.loadout_changed.connect(refresh)
	call_deferred("refresh")


func refresh() -> void:
	var loadout := _get_loadout()
	if loadout == null:
		_set_module(main_module, "주무기", "—", true)
		for module in _aux_modules:
			_set_module(module, "보조", "—", true)
		_refresh_owned_main(null)
		return

	var main_slot := loadout.get_main_slot()
	var main_empty := main_slot == null or main_slot.is_empty()
	var main_slot_lv: int = 1 if main_slot == null else main_slot.level
	if main_empty:
		_set_module(main_module, "주무기 Lv.%d" % main_slot_lv, "—", true)
	else:
		var main_name := main_slot.equipped_weapon_display_name
		if main_name.is_empty():
			main_name = String(main_slot.equipped_weapon_id)
		var weapon_lv: int = loadout.get_weapon_level(main_slot.equipped_weapon_id)
		_set_module(main_module, "주무기 Lv.%d" % main_slot_lv, "%s\nLv.%d" % [main_name, weapon_lv], false)

	for index in PlayerWeaponLoadout.AUX_SLOT_COUNT:
		var module := _aux_modules[index]
		var slot := loadout.get_auxiliary_slot(index)
		if slot == null or not slot.unlocked:
			_set_module(module, "보조%d" % (index + 1), "잠김", true)
			continue
		var slot_title := "보조%d Lv.%d" % [index + 1, slot.level]
		if slot.is_empty():
			_set_module(module, slot_title, "—", true)
			continue
		var weapon_name := slot.equipped_weapon_display_name
		if weapon_name.is_empty():
			weapon_name = String(slot.equipped_weapon_id)
		var charges_text := _format_charges(slot.equipped_weapon_instance)
		if charges_text.is_empty():
			_set_module(module, slot_title, weapon_name, false)
		else:
			_set_module(module, slot_title, "%s\n%s" % [weapon_name, charges_text], false)

	_refresh_owned_main(loadout)


func _refresh_owned_main(loadout: PlayerWeaponLoadout) -> void:
	_clear_row(owned_main_row)
	if loadout == null or owned_main_row == null:
		return
	for weapon_id in loadout.get_tracked_weapon_ids_by_category(WeaponDefinition.Category.MAIN):
		var module := HEX_MODULE_SCENE.instantiate() as HexModuleFrame
		module.custom_minimum_size = Vector2(36, 36)
		var display_name: String = loadout.get_weapon_display_name(weapon_id)
		var level: int = loadout.get_weapon_level(weapon_id)
		owned_main_row.add_child(module)
		_set_module(module, _short_name(display_name), "Lv.%d" % level, false)


func _format_charges(weapon: WeaponSystem) -> String:
	if weapon == null or not is_instance_valid(weapon):
		return ""
	var remaining: int = weapon.get_consumable_remaining()
	var maximum: int = weapon.get_consumable_max()
	if remaining < 0 or maximum < 0:
		return ""
	return "%d/%d" % [remaining, maximum]


func _clear_row(row: HBoxContainer) -> void:
	if row == null:
		return
	for child in row.get_children():
		child.queue_free()


func _short_name(display_name: String) -> String:
	if display_name.length() <= 3:
		return display_name
	return display_name.substr(0, 3)


func _ensure_aux_modules() -> void:
	_aux_modules.clear()
	if aux_row == null:
		return
	for child in aux_row.get_children():
		child.queue_free()
	for index in PlayerWeaponLoadout.AUX_SLOT_COUNT:
		var module := HEX_MODULE_SCENE.instantiate() as HexModuleFrame
		module.name = "AuxModule%d" % (index + 1)
		module.custom_minimum_size = Vector2(54, 54)
		aux_row.add_child(module)
		_aux_modules.append(module)


func _set_module(module: HexModuleFrame, title: String, body: String, dimmed: bool) -> void:
	if module == null:
		return
	module.set_module_text(title, body)
	module.dimmed = dimmed
	module.border_color = Color(0.45, 0.9, 1.0, 0.95) if not dimmed else Color(0.18, 0.45, 0.6, 0.7)
	module.fill_color = Color(0.06, 0.18, 0.3, 0.95) if not dimmed else Color(0.03, 0.08, 0.14, 0.7)
	module.queue_redraw()


func _get_loadout() -> PlayerWeaponLoadout:
	if ship != null and ship.has_method("get_weapon_loadout"):
		return ship.call("get_weapon_loadout") as PlayerWeaponLoadout
	return null
