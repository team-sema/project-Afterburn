class_name PlayerWeaponLoadout
extends Node2D

signal main_weapon_changed(weapon_definition: WeaponDefinition)
signal auxiliary_weapon_changed(slot_index: int, weapon_definition: WeaponDefinition)
signal slot_unlocked(slot_index: int)
signal slot_upgraded(category: WeaponDefinition.Category, slot_index: int, new_level: int)
signal loadout_changed

const AUX_SLOT_COUNT := 3

@export var default_main_weapon: WeaponDefinition
@export var player_path: NodePath

@onready var main_weapon_mount: Node2D = $MainWeaponMount
@onready var auxiliary_weapon_mounts: Node2D = $AuxiliaryWeaponMounts

var _player: Node2D
var _main_slot: WeaponSlotState = WeaponSlotState.new()
var _aux_slots: Array[WeaponSlotState] = []
var _global_damage_multiplier := 1.0
var _global_fire_rate_multiplier := 1.0


func _ready() -> void:
	_player = get_node_or_null(player_path) as Node2D
	if _player == null:
		_player = get_parent() as Node2D

	_main_slot.slot_type = WeaponDefinition.Category.MAIN
	_main_slot.slot_index = 0
	_main_slot.unlocked = true
	_main_slot.level = 1

	_aux_slots.clear()
	for index in AUX_SLOT_COUNT:
		var slot := WeaponSlotState.new()
		slot.slot_type = WeaponDefinition.Category.AUXILIARY
		slot.slot_index = index
		slot.unlocked = true
		slot.level = 1
		_aux_slots.append(slot)

	if default_main_weapon != null:
		equip_main_weapon(default_main_weapon)


func set_global_stat_multipliers(damage_multiplier: float, fire_rate_multiplier: float) -> void:
	_global_damage_multiplier = maxf(0.01, damage_multiplier)
	_global_fire_rate_multiplier = maxf(0.01, fire_rate_multiplier)
	_refresh_all_weapon_multipliers()


func get_all_weapon_systems() -> Array[WeaponSystem]:
	var systems: Array[WeaponSystem] = []
	if _main_slot.equipped_weapon_instance != null and is_instance_valid(_main_slot.equipped_weapon_instance):
		systems.append(_main_slot.equipped_weapon_instance)
	for slot in _aux_slots:
		if slot.equipped_weapon_instance != null and is_instance_valid(slot.equipped_weapon_instance):
			systems.append(slot.equipped_weapon_instance)
	return systems


func equip_main_weapon(weapon_definition: WeaponDefinition) -> void:
	if weapon_definition == null:
		push_error("PlayerWeaponLoadout.equip_main_weapon: weapon_definition is null.")
		return
	if weapon_definition.category != WeaponDefinition.Category.MAIN:
		push_error("PlayerWeaponLoadout.equip_main_weapon: '%s' is not a MAIN weapon." % String(weapon_definition.id))
		return
	if weapon_definition.weapon_scene == null:
		push_error("PlayerWeaponLoadout.equip_main_weapon: '%s' has no weapon_scene." % String(weapon_definition.id))
		return

	_clear_slot_instance(_main_slot)
	_main_slot.level = 1
	var instance := _instantiate_weapon(weapon_definition, WeaponDefinition.Category.MAIN, 0, main_weapon_mount)
	if instance == null:
		return

	_main_slot.equipped_weapon_id = weapon_definition.id
	_main_slot.equipped_weapon_display_name = weapon_definition.display_name
	_main_slot.equipped_weapon_instance = instance
	_apply_multipliers_to_weapon(instance, WeaponDefinition.Category.MAIN, 0)
	main_weapon_changed.emit(weapon_definition)
	loadout_changed.emit()


func equip_auxiliary_weapon(weapon_definition: WeaponDefinition, slot_index: int = -1) -> void:
	if weapon_definition == null:
		push_error("PlayerWeaponLoadout.equip_auxiliary_weapon: weapon_definition is null.")
		return
	if weapon_definition.category != WeaponDefinition.Category.AUXILIARY:
		push_error("PlayerWeaponLoadout.equip_auxiliary_weapon: '%s' is not AUXILIARY." % String(weapon_definition.id))
		return
	if has_auxiliary_weapon(weapon_definition.id):
		push_error("PlayerWeaponLoadout.equip_auxiliary_weapon: '%s' already equipped." % String(weapon_definition.id))
		return

	var target_index := slot_index
	if target_index < 0:
		target_index = get_first_empty_auxiliary_slot()
	if target_index < 0:
		push_error("PlayerWeaponLoadout.equip_auxiliary_weapon: no empty unlocked auxiliary slot.")
		return
	replace_auxiliary_weapon(target_index, weapon_definition)


func replace_auxiliary_weapon(slot_index: int, weapon_definition: WeaponDefinition) -> void:
	if not _is_valid_aux_index(slot_index):
		push_error("PlayerWeaponLoadout.replace_auxiliary_weapon: invalid slot_index %s." % slot_index)
		return
	if weapon_definition == null or weapon_definition.category != WeaponDefinition.Category.AUXILIARY:
		push_error("PlayerWeaponLoadout.replace_auxiliary_weapon: invalid weapon_definition.")
		return
	if weapon_definition.weapon_scene == null:
		push_error("PlayerWeaponLoadout.replace_auxiliary_weapon: missing weapon_scene.")
		return

	var slot := _aux_slots[slot_index]
	if not slot.unlocked:
		push_error("PlayerWeaponLoadout.replace_auxiliary_weapon: slot %s is locked." % slot_index)
		return

	if has_auxiliary_weapon(weapon_definition.id) and slot.equipped_weapon_id != weapon_definition.id:
		push_error("PlayerWeaponLoadout.replace_auxiliary_weapon: '%s' already in another slot." % String(weapon_definition.id))
		return

	var mount := _get_aux_mount(slot_index)
	if mount == null:
		push_error("PlayerWeaponLoadout.replace_auxiliary_weapon: missing AuxMount for slot %s." % slot_index)
		return

	_clear_slot_instance(slot)
	slot.level = 1
	var instance := _instantiate_weapon(weapon_definition, WeaponDefinition.Category.AUXILIARY, slot_index, mount)
	if instance == null:
		return

	slot.equipped_weapon_id = weapon_definition.id
	slot.equipped_weapon_display_name = weapon_definition.display_name
	slot.equipped_weapon_instance = instance
	_apply_multipliers_to_weapon(instance, WeaponDefinition.Category.AUXILIARY, slot_index)
	auxiliary_weapon_changed.emit(slot_index, weapon_definition)
	loadout_changed.emit()


func unlock_next_auxiliary_slot() -> bool:
	for index in AUX_SLOT_COUNT:
		var slot := _aux_slots[index]
		if not slot.unlocked:
			slot.unlocked = true
			slot_unlocked.emit(index)
			loadout_changed.emit()
			return true
	return false


func upgrade_main_slot() -> bool:
	if not _main_slot.can_upgrade():
		return false
	_main_slot.level += 1
	_refresh_slot_weapon_multipliers(WeaponDefinition.Category.MAIN, 0)
	slot_upgraded.emit(WeaponDefinition.Category.MAIN, 0, _main_slot.level)
	loadout_changed.emit()
	return true


func upgrade_auxiliary_slot(slot_index: int) -> bool:
	if not _is_valid_aux_index(slot_index):
		push_error("PlayerWeaponLoadout.upgrade_auxiliary_slot: invalid slot_index %s." % slot_index)
		return false
	var slot := _aux_slots[slot_index]
	if not slot.can_upgrade():
		return false
	slot.level += 1
	_refresh_slot_weapon_multipliers(WeaponDefinition.Category.AUXILIARY, slot_index)
	slot_upgraded.emit(WeaponDefinition.Category.AUXILIARY, slot_index, slot.level)
	loadout_changed.emit()
	return true


func get_main_slot() -> WeaponSlotState:
	return _main_slot


func get_auxiliary_slot(slot_index: int) -> WeaponSlotState:
	if not _is_valid_aux_index(slot_index):
		return null
	return _aux_slots[slot_index]


func get_first_empty_auxiliary_slot() -> int:
	for index in AUX_SLOT_COUNT:
		var slot := _aux_slots[index]
		if slot.unlocked and slot.is_empty():
			return index
	return -1


func upgrade_auxiliary_weapon(weapon_id: StringName) -> bool:
	for index in AUX_SLOT_COUNT:
		var slot := _aux_slots[index]
		if slot.equipped_weapon_id == weapon_id:
			return upgrade_auxiliary_slot(index)
	return false


func has_auxiliary_weapon(weapon_id: StringName) -> bool:
	for slot in _aux_slots:
		if slot.equipped_weapon_id == weapon_id:
			return true
	return false


func get_main_weapon_id() -> StringName:
	return _main_slot.equipped_weapon_id


func has_locked_auxiliary_slot() -> bool:
	for slot in _aux_slots:
		if not slot.unlocked:
			return true
	return false


func has_upgradable_auxiliary_slot() -> bool:
	for slot in _aux_slots:
		if slot.can_upgrade():
			return true
	return false


func get_upgradable_auxiliary_indices() -> Array[int]:
	var indices: Array[int] = []
	for index in AUX_SLOT_COUNT:
		if _aux_slots[index].can_upgrade():
			indices.append(index)
	return indices


func get_occupied_auxiliary_indices() -> Array[int]:
	var indices: Array[int] = []
	for index in AUX_SLOT_COUNT:
		var slot := _aux_slots[index]
		if slot.unlocked and not slot.is_empty():
			indices.append(index)
	return indices


func get_slot_damage_multiplier(category: WeaponDefinition.Category, slot_index: int) -> float:
	var slot := _get_slot(category, slot_index)
	if slot == null:
		return 1.0
	return slot.get_damage_multiplier()


func get_slot_attack_rate_multiplier(category: WeaponDefinition.Category, slot_index: int) -> float:
	var slot := _get_slot(category, slot_index)
	if slot == null:
		return 1.0
	return slot.get_attack_rate_multiplier()


func _instantiate_weapon(
	weapon_definition: WeaponDefinition,
	category: WeaponDefinition.Category,
	slot_index: int,
	mount: Node,
) -> WeaponSystem:
	var node := weapon_definition.weapon_scene.instantiate()
	var weapon := node as WeaponSystem
	if weapon == null:
		push_error("PlayerWeaponLoadout: scene for '%s' is not a WeaponSystem." % String(weapon_definition.id))
		node.queue_free()
		return null
	mount.add_child(weapon)
	weapon.setup_weapon(_player, self, category, slot_index)
	return weapon


func _clear_slot_instance(slot: WeaponSlotState) -> void:
	if slot.equipped_weapon_instance != null and is_instance_valid(slot.equipped_weapon_instance):
		slot.equipped_weapon_instance.shutdown_weapon()
		slot.equipped_weapon_instance.queue_free()
	slot.equipped_weapon_instance = null
	slot.equipped_weapon_id = &""
	slot.equipped_weapon_display_name = ""


func _apply_multipliers_to_weapon(weapon: WeaponSystem, category: WeaponDefinition.Category, slot_index: int) -> void:
	if weapon == null or not is_instance_valid(weapon):
		return
	weapon.set_global_damage_multiplier(_global_damage_multiplier)
	weapon.set_global_fire_rate_multiplier(_global_fire_rate_multiplier)
	weapon.set_local_damage_multiplier(get_slot_damage_multiplier(category, slot_index))
	weapon.set_local_fire_rate_multiplier(get_slot_attack_rate_multiplier(category, slot_index))


func _refresh_slot_weapon_multipliers(category: WeaponDefinition.Category, slot_index: int) -> void:
	var slot := _get_slot(category, slot_index)
	if slot == null or slot.equipped_weapon_instance == null:
		return
	_apply_multipliers_to_weapon(slot.equipped_weapon_instance, category, slot_index)


func _refresh_all_weapon_multipliers() -> void:
	_refresh_slot_weapon_multipliers(WeaponDefinition.Category.MAIN, 0)
	for index in AUX_SLOT_COUNT:
		_refresh_slot_weapon_multipliers(WeaponDefinition.Category.AUXILIARY, index)


func _get_slot(category: WeaponDefinition.Category, slot_index: int) -> WeaponSlotState:
	match category:
		WeaponDefinition.Category.MAIN:
			return _main_slot
		WeaponDefinition.Category.AUXILIARY:
			if _is_valid_aux_index(slot_index):
				return _aux_slots[slot_index]
	return null


func _is_valid_aux_index(slot_index: int) -> bool:
	return slot_index >= 0 and slot_index < AUX_SLOT_COUNT


func _get_aux_mount(slot_index: int) -> Node2D:
	if auxiliary_weapon_mounts == null:
		return null
	var mount_name := "AuxMount%d" % (slot_index + 1)
	return auxiliary_weapon_mounts.get_node_or_null(mount_name) as Node2D
