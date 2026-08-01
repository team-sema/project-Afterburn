class_name WeaponLoadoutHud
extends VBoxContainer

const HEX_MODULE_SCENE := preload("res://menus/hex_module_frame.tscn")

@export var ship: Node2D

@onready var main_module: HexModuleFrame = $MainRow/MainModule
@onready var reserve_module: HexModuleFrame = $MainRow/ReserveModule
@onready var block_new_main_status: Label = $BlockNewMainStatus
@onready var aux_row: HBoxContainer = $AuxRow

var _aux_modules: Array[HexModuleFrame] = []


func _ready() -> void:
	_ensure_aux_modules()
	call_deferred("_bind_acquisition")
	if ship == null:
		return
	var loadout := _get_loadout()
	if loadout == null:
		return
	loadout.loadout_changed.connect(refresh)
	call_deferred("refresh")


func _bind_acquisition() -> void:
	var controller := _get_acquisition()
	if controller != null:
		if not controller.block_unknown_main_pickups_changed.is_connected(_on_block_new_main_changed):
			controller.block_unknown_main_pickups_changed.connect(_on_block_new_main_changed)
	_refresh_block_status()


func refresh() -> void:
	var loadout := _get_loadout()
	if loadout == null:
		_set_module(main_module, "메인", "—", true)
		_set_module(reserve_module, "예비", "—", true)
		for module in _aux_modules:
			_set_module(module, "보조", "—", true)
		return

	_refresh_main_slot_module(loadout)
	_refresh_reserve_slot_module(loadout)

	for index in PlayerWeaponLoadout.AUX_SLOT_COUNT:
		var module := _aux_modules[index]
		var slot := loadout.get_auxiliary_slot(index)
		if slot == null or not slot.unlocked:
			_set_module(module, "보조%d" % (index + 1), "잠김", true)
			continue
		var slot_title := "A%d L%d" % [index + 1, slot.level]
		if slot.is_empty():
			_set_module(module, slot_title, "—", true)
			continue
		var charges_text := _format_charges(slot.equipped_weapon_instance)
		_set_module(module, slot_title, _slot_body(slot, charges_text), false, _slot_icon(slot))

func _refresh_main_slot_module(loadout: PlayerWeaponLoadout) -> void:
	var main_slot: WeaponSlotState = loadout.get_main_slot()
	var slot_lv: int = 1 if main_slot == null else main_slot.level
	var title := "메인 Lv.%d" % slot_lv
	if main_slot == null or main_slot.is_empty():
		_set_module(main_module, title, "—", true)
		return
	var weapon_lv: int = loadout.get_weapon_level(main_slot.equipped_weapon_id)
	_set_module(main_module, title, _slot_body(main_slot, "Lv.%d" % weapon_lv), false, _slot_icon(main_slot))


func _refresh_reserve_slot_module(loadout: PlayerWeaponLoadout) -> void:
	var reserve_slot: WeaponSlotState = loadout.get_reserve_slot()
	var title := "예비"
	if reserve_slot == null or reserve_slot.is_empty():
		_set_module(reserve_module, title, "—", true)
		return
	var weapon_lv: int = loadout.get_weapon_level(reserve_slot.equipped_weapon_id)
	_set_module(
		reserve_module,
		title,
		_slot_body(reserve_slot, "Lv.%d" % weapon_lv),
		false,
		_slot_icon(reserve_slot),
	)


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


func _ensure_aux_modules() -> void:
	_aux_modules.clear()
	if aux_row == null:
		return
	for child in aux_row.get_children():
		child.queue_free()
	for index in PlayerWeaponLoadout.AUX_SLOT_COUNT:
		var module := HEX_MODULE_SCENE.instantiate() as HexModuleFrame
		module.name = "AuxModule%d" % (index + 1)
		module.custom_minimum_size = Vector2(48, 48)
		aux_row.add_child(module)
		_aux_modules.append(module)


func _slot_icon(slot: WeaponSlotState) -> Texture2D:
	if slot == null or slot.equipped_weapon_definition == null:
		return null
	return slot.equipped_weapon_definition.icon


## The icon carries the weapon identity, so the name only reappears when an icon is missing.
func _slot_body(slot: WeaponSlotState, meta: String) -> String:
	if slot == null or _slot_icon(slot) != null:
		return meta
	var weapon_name: String = slot.equipped_weapon_display_name
	if weapon_name.is_empty():
		weapon_name = String(slot.equipped_weapon_id)
	if meta.is_empty():
		return weapon_name
	return "%s\n%s" % [weapon_name, meta]


func _set_module(
	module: HexModuleFrame,
	title: String,
	body: String,
	dimmed: bool,
	icon: Texture2D = null,
) -> void:
	if module == null:
		return
	module.set_module_text(title, body)
	module.set_module_icon(icon)
	module.dimmed = dimmed
	module.border_color = Color(0.45, 0.9, 1.0, 0.95) if not dimmed else Color(0.18, 0.45, 0.6, 0.7)
	module.fill_color = Color(0.06, 0.18, 0.3, 0.95) if not dimmed else Color(0.03, 0.08, 0.14, 0.7)
	module.queue_redraw()


func _get_loadout() -> PlayerWeaponLoadout:
	if ship != null and ship.has_method("get_weapon_loadout"):
		return ship.call("get_weapon_loadout") as PlayerWeaponLoadout
	return null


func _get_acquisition() -> WeaponAcquisitionController:
	return get_tree().get_first_node_in_group("weapon_acquisition") as WeaponAcquisitionController


func _on_block_new_main_changed(_enabled: bool) -> void:
	_refresh_block_status()


func _refresh_block_status() -> void:
	if block_new_main_status == null:
		return
	var controller := _get_acquisition()
	var enabled := controller != null and controller.block_unknown_main_pickups
	block_new_main_status.text = "X 새주무기차단: 켬" if enabled else "X 새주무기차단: 끔"
	block_new_main_status.modulate = Color(1.0, 0.55, 0.45, 1.0) if enabled else Color(0.55, 0.75, 0.9, 0.85)
