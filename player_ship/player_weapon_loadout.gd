class_name PlayerWeaponLoadout
extends Node2D

signal main_weapon_changed(weapon_definition: WeaponDefinition)
signal auxiliary_weapon_changed(slot_index: int, weapon_definition: WeaponDefinition)
signal slot_unlocked(slot_index: int)
signal slot_upgraded(category: WeaponDefinition.Category, slot_index: int, new_level: int)
signal weapon_level_changed(weapon_id: StringName, new_level: int)
signal loadout_changed

const AUX_SLOT_COUNT := 3
const MAX_WEAPON_LEVEL := WeaponSlotState.MAX_LEVEL

@export var default_main_weapon: WeaponDefinition
@export var player_path: NodePath

@onready var main_weapon_mount: Node2D = $MainWeaponMount
@onready var auxiliary_weapon_mounts: Node2D = $AuxiliaryWeaponMounts

var _player: Node2D
var _main_slot: WeaponSlotState = WeaponSlotState.new()
## Standby main-weapon slot: metadata only until swapped into main.
var _reserve_slot: WeaponSlotState = WeaponSlotState.new()
var _aux_slots: Array[WeaponSlotState] = []
var _global_damage_multiplier := 1.0
var _global_fire_rate_multiplier := 1.0
## Ship facility bonuses: weapon room hits main weapons only, hangar hits aux capacity only.
var _facility_main_damage_multiplier := 1.0
var _facility_auxiliary_ammo_bonus := 0
## Per-weapon levels persist across equip swaps for the run.
var _weapon_levels: Dictionary = {}
var _weapon_display_names: Dictionary = {}
## weapon_id -> WeaponDefinition.Category (for owned HUD rows).
var _weapon_categories: Dictionary = {}
## weapon_id -> WeaponDefinition, so HUD rows can reach icons without a live slot.
var _weapon_definitions: Dictionary = {}


func _ready() -> void:
	_player = get_node_or_null(player_path) as Node2D
	if _player == null:
		_player = get_parent() as Node2D

	_main_slot.slot_type = WeaponDefinition.Category.MAIN
	_main_slot.slot_index = 0
	_main_slot.unlocked = true
	_main_slot.level = 1

	_reserve_slot.slot_type = WeaponDefinition.Category.MAIN
	_reserve_slot.slot_index = 1
	_reserve_slot.unlocked = true
	_reserve_slot.level = 1

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


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key_event := event as InputEventKey
		if key_event.keycode == KEY_Z or key_event.physical_keycode == KEY_Z:
			if swap_main_and_reserve():
				get_viewport().set_input_as_handled()


func set_global_stat_multipliers(damage_multiplier: float, fire_rate_multiplier: float) -> void:
	_global_damage_multiplier = maxf(0.01, damage_multiplier)
	_global_fire_rate_multiplier = maxf(0.01, fire_rate_multiplier)
	_refresh_all_weapon_multipliers()


## Weapon room bonus. Applies to whichever main weapon is equipped, never to its behaviour.
func set_facility_main_damage_multiplier(multiplier: float) -> void:
	_facility_main_damage_multiplier = maxf(0.01, multiplier)
	_refresh_all_weapon_multipliers()


## Hangar bonus. Newly equipped aux weapons start at the raised maximum.
func set_facility_auxiliary_ammo_bonus(bonus: int) -> void:
	_facility_auxiliary_ammo_bonus = maxi(0, bonus)
	for index in AUX_SLOT_COUNT:
		_refresh_slot_weapon_multipliers(WeaponDefinition.Category.AUXILIARY, index)


func get_facility_main_damage_multiplier() -> float:
	return _facility_main_damage_multiplier


func get_facility_auxiliary_ammo_bonus() -> int:
	return _facility_auxiliary_ammo_bonus


func get_all_weapon_systems() -> Array[WeaponSystem]:
	var systems: Array[WeaponSystem] = []
	if _main_slot.equipped_weapon_instance != null and is_instance_valid(_main_slot.equipped_weapon_instance):
		systems.append(_main_slot.equipped_weapon_instance)
	for slot in _aux_slots:
		if slot.equipped_weapon_instance != null and is_instance_valid(slot.equipped_weapon_instance):
			systems.append(slot.equipped_weapon_instance)
	return systems


func get_weapon_level(weapon_id: StringName) -> int:
	if weapon_id == &"":
		return 1
	return int(_weapon_levels.get(weapon_id, 1))


func get_weapon_display_name(weapon_id: StringName) -> String:
	if weapon_id == &"":
		return ""
	if not _weapon_display_names.has(weapon_id):
		return String(weapon_id)
	return str(_weapon_display_names[weapon_id])


func get_weapon_definition(weapon_id: StringName) -> WeaponDefinition:
	if weapon_id == &"":
		return null
	return _weapon_definitions.get(weapon_id) as WeaponDefinition


func get_weapon_icon(weapon_id: StringName) -> Texture2D:
	var definition := get_weapon_definition(weapon_id)
	if definition == null:
		return null
	return definition.icon


func has_weapon_progress(weapon_id: StringName) -> bool:
	return _weapon_levels.has(weapon_id)


func get_tracked_weapon_ids() -> Array[StringName]:
	return _sorted_tracked_ids()


func get_tracked_weapon_ids_by_category(category: WeaponDefinition.Category) -> Array[StringName]:
	var ids: Array[StringName] = []
	for weapon_id in _sorted_tracked_ids():
		if get_weapon_category(weapon_id) == category:
			ids.append(weapon_id)
	return ids


func get_weapon_category(weapon_id: StringName) -> WeaponDefinition.Category:
	if weapon_id == &"" or not _weapon_categories.has(weapon_id):
		return WeaponDefinition.Category.MAIN
	return int(_weapon_categories[weapon_id]) as WeaponDefinition.Category


## First MAIN pickup registers Lv.1; later MAIN pickups raise level. Returns true if level increased.
## Auxiliary pickups must not call this — use refill_auxiliary_weapon / equip instead.
func note_weapon_pickup(
	weapon_id: StringName,
	display_name: String = "",
	category: WeaponDefinition.Category = WeaponDefinition.Category.MAIN
) -> bool:
	if weapon_id == &"":
		return false
	if category == WeaponDefinition.Category.AUXILIARY:
		push_warning("note_weapon_pickup ignored for auxiliary '%s' (consumables have no weapon level)." % String(weapon_id))
		return false
	_weapon_categories[weapon_id] = category
	if display_name != "":
		_weapon_display_names[weapon_id] = display_name
	if not _weapon_levels.has(weapon_id):
		_weapon_levels[weapon_id] = 1
		weapon_level_changed.emit(weapon_id, 1)
		_refresh_equipped_weapon_by_id(weapon_id)
		loadout_changed.emit()
		return false
	return upgrade_weapon_level(weapon_id)


func upgrade_weapon_level(weapon_id: StringName) -> bool:
	if weapon_id == &"":
		return false
	var level := get_weapon_level(weapon_id)
	if level >= MAX_WEAPON_LEVEL:
		return false
	level += 1
	_weapon_levels[weapon_id] = level
	weapon_level_changed.emit(weapon_id, level)
	_refresh_equipped_weapon_by_id(weapon_id)
	loadout_changed.emit()
	return true


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

	_register_main_definition(weapon_definition)
	_clear_slot_equipment(_main_slot)
	_assign_slot_weapon(_main_slot, weapon_definition)
	var instance := _instantiate_weapon(weapon_definition, WeaponDefinition.Category.MAIN, 0, main_weapon_mount)
	if instance == null:
		_clear_slot_equipment(_main_slot)
		return

	_main_slot.equipped_weapon_instance = instance
	_apply_multipliers_to_weapon(instance, WeaponDefinition.Category.MAIN, 0)
	main_weapon_changed.emit(weapon_definition)
	loadout_changed.emit()


## Stow a main weapon in the reserve slot (no active instance until swapped).
func equip_reserve_weapon(weapon_definition: WeaponDefinition) -> void:
	if weapon_definition == null:
		push_error("PlayerWeaponLoadout.equip_reserve_weapon: weapon_definition is null.")
		return
	if weapon_definition.category != WeaponDefinition.Category.MAIN:
		push_error("PlayerWeaponLoadout.equip_reserve_weapon: '%s' is not a MAIN weapon." % String(weapon_definition.id))
		return
	if weapon_definition.weapon_scene == null:
		push_error("PlayerWeaponLoadout.equip_reserve_weapon: '%s' has no weapon_scene." % String(weapon_definition.id))
		return

	_register_main_definition(weapon_definition)
	_clear_slot_equipment(_reserve_slot)
	_assign_slot_weapon(_reserve_slot, weapon_definition)
	loadout_changed.emit()


## Swap firing main with reserve. No-op if reserve is empty.
func swap_main_and_reserve() -> bool:
	if _reserve_slot.is_empty():
		return false
	var main_def: WeaponDefinition = _main_slot.equipped_weapon_definition
	var reserve_def: WeaponDefinition = _reserve_slot.equipped_weapon_definition
	if reserve_def == null:
		return false

	_clear_slot_equipment(_main_slot)
	_clear_slot_equipment(_reserve_slot)

	_assign_slot_weapon(_main_slot, reserve_def)
	var instance := _instantiate_weapon(reserve_def, WeaponDefinition.Category.MAIN, 0, main_weapon_mount)
	if instance == null:
		_clear_slot_equipment(_main_slot)
		if main_def != null:
			_assign_slot_weapon(_reserve_slot, main_def)
		loadout_changed.emit()
		return false
	_main_slot.equipped_weapon_instance = instance
	_apply_multipliers_to_weapon(instance, WeaponDefinition.Category.MAIN, 0)
	main_weapon_changed.emit(reserve_def)

	if main_def != null:
		_assign_slot_weapon(_reserve_slot, main_def)

	loadout_changed.emit()
	return true


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

	# Aux weapons are consumables: no per-weapon level, only slot overclock.
	_weapon_display_names[weapon_definition.id] = weapon_definition.display_name
	_weapon_categories[weapon_definition.id] = WeaponDefinition.Category.AUXILIARY
	_weapon_definitions[weapon_definition.id] = weapon_definition
	_weapon_levels.erase(weapon_definition.id)

	_clear_slot_equipment(slot)
	var instance := _instantiate_weapon(weapon_definition, WeaponDefinition.Category.AUXILIARY, slot_index, mount)
	if instance == null:
		return

	slot.equipped_weapon_id = weapon_definition.id
	slot.equipped_weapon_display_name = weapon_definition.display_name
	slot.equipped_weapon_definition = weapon_definition
	slot.equipped_weapon_instance = instance
	if not instance.depleted.is_connected(_on_auxiliary_weapon_depleted.bind(slot_index)):
		instance.depleted.connect(_on_auxiliary_weapon_depleted.bind(slot_index))
	_apply_multipliers_to_weapon(instance, WeaponDefinition.Category.AUXILIARY, slot_index)
	auxiliary_weapon_changed.emit(slot_index, weapon_definition)
	loadout_changed.emit()


## Same aux pickup restores remaining uses instead of raising a weapon level.
func refill_auxiliary_weapon(weapon_id: StringName) -> bool:
	if weapon_id == &"":
		return false
	for index in AUX_SLOT_COUNT:
		var slot := _aux_slots[index]
		if slot.equipped_weapon_id != weapon_id:
			continue
		var instance := slot.equipped_weapon_instance
		if instance == null or not is_instance_valid(instance):
			return false
		instance.refill_consumable()
		loadout_changed.emit()
		return true
	return false


func notify_consumable_changed() -> void:
	loadout_changed.emit()


func clear_auxiliary_slot(slot_index: int) -> void:
	if not _is_valid_aux_index(slot_index):
		return
	var slot := _aux_slots[slot_index]
	if slot.is_empty():
		return
	_clear_slot_equipment(slot)
	loadout_changed.emit()


func _on_auxiliary_weapon_depleted(slot_index: int) -> void:
	if not _is_valid_aux_index(slot_index):
		return
	call_deferred("clear_auxiliary_slot", slot_index)


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
	# Shared overclock for the main-weapon line (firing + reserve).
	_reserve_slot.level = _main_slot.level
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


func get_reserve_slot() -> WeaponSlotState:
	return _reserve_slot


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


func has_auxiliary_weapon(weapon_id: StringName) -> bool:
	for slot in _aux_slots:
		if slot.equipped_weapon_id == weapon_id:
			return true
	return false


func get_main_weapon_id() -> StringName:
	return _main_slot.equipped_weapon_id


func get_reserve_weapon_id() -> StringName:
	return _reserve_slot.equipped_weapon_id


## True if the weapon is in the firing main slot or the reserve slot.
func has_carried_main_weapon(weapon_id: StringName) -> bool:
	if weapon_id == &"":
		return false
	return (
		_main_slot.equipped_weapon_id == weapon_id
		or _reserve_slot.equipped_weapon_id == weapon_id
	)


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


func get_weapon_damage_multiplier(weapon_id: StringName) -> float:
	# Aux consumables have no weapon level — slot overclock only.
	if get_weapon_category(weapon_id) == WeaponDefinition.Category.AUXILIARY:
		return 1.0
	return _level_damage_multiplier(get_weapon_level(weapon_id))


func get_weapon_attack_rate_multiplier(weapon_id: StringName) -> float:
	if get_weapon_category(weapon_id) == WeaponDefinition.Category.AUXILIARY:
		return 1.0
	return _level_attack_rate_multiplier(get_weapon_level(weapon_id))


func _register_main_definition(weapon_definition: WeaponDefinition) -> void:
	if not _weapon_levels.has(weapon_definition.id):
		_weapon_levels[weapon_definition.id] = 1
	_weapon_display_names[weapon_definition.id] = weapon_definition.display_name
	_weapon_categories[weapon_definition.id] = WeaponDefinition.Category.MAIN
	_weapon_definitions[weapon_definition.id] = weapon_definition


func _assign_slot_weapon(slot: WeaponSlotState, weapon_definition: WeaponDefinition) -> void:
	slot.equipped_weapon_id = weapon_definition.id
	slot.equipped_weapon_display_name = weapon_definition.display_name
	slot.equipped_weapon_definition = weapon_definition
	slot.equipped_weapon_instance = null


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


func _clear_slot_equipment(slot: WeaponSlotState) -> void:
	if slot.equipped_weapon_instance != null and is_instance_valid(slot.equipped_weapon_instance):
		var instance := slot.equipped_weapon_instance
		instance.shutdown_weapon()
		instance.queue_free()
	slot.equipped_weapon_instance = null
	slot.equipped_weapon_id = &""
	slot.equipped_weapon_display_name = ""
	slot.equipped_weapon_definition = null


func _apply_multipliers_to_weapon(weapon: WeaponSystem, category: WeaponDefinition.Category, slot_index: int) -> void:
	if weapon == null or not is_instance_valid(weapon):
		return
	var slot := _get_slot(category, slot_index)
	var weapon_id := slot.equipped_weapon_id if slot != null else &""
	var local_damage := get_slot_damage_multiplier(category, slot_index)
	var local_rate := get_slot_attack_rate_multiplier(category, slot_index)
	var facility_damage := 1.0
	var facility_ammo_bonus := 0
	if category == WeaponDefinition.Category.MAIN:
		local_damage *= get_weapon_damage_multiplier(weapon_id)
		local_rate *= get_weapon_attack_rate_multiplier(weapon_id)
		facility_damage = _facility_main_damage_multiplier
	else:
		facility_ammo_bonus = _facility_auxiliary_ammo_bonus
	weapon.set_global_damage_multiplier(_global_damage_multiplier)
	weapon.set_global_fire_rate_multiplier(_global_fire_rate_multiplier)
	weapon.set_local_damage_multiplier(local_damage)
	weapon.set_local_fire_rate_multiplier(local_rate)
	weapon.set_facility_damage_multiplier(facility_damage)
	weapon.set_consumable_capacity_bonus(facility_ammo_bonus)


func _refresh_slot_weapon_multipliers(category: WeaponDefinition.Category, slot_index: int) -> void:
	var slot := _get_slot(category, slot_index)
	if slot == null or slot.equipped_weapon_instance == null:
		return
	_apply_multipliers_to_weapon(slot.equipped_weapon_instance, category, slot_index)


func _sorted_tracked_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for key in _weapon_levels.keys():
		ids.append(key as StringName)
	ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return ids


func _refresh_equipped_weapon_by_id(weapon_id: StringName) -> void:
	if _main_slot.equipped_weapon_id == weapon_id:
		_refresh_slot_weapon_multipliers(WeaponDefinition.Category.MAIN, 0)
	for index in AUX_SLOT_COUNT:
		if _aux_slots[index].equipped_weapon_id == weapon_id:
			_refresh_slot_weapon_multipliers(WeaponDefinition.Category.AUXILIARY, index)


func _refresh_all_weapon_multipliers() -> void:
	_refresh_slot_weapon_multipliers(WeaponDefinition.Category.MAIN, 0)
	for index in AUX_SLOT_COUNT:
		_refresh_slot_weapon_multipliers(WeaponDefinition.Category.AUXILIARY, index)


func _level_damage_multiplier(level: int) -> float:
	match clampi(level, 1, MAX_WEAPON_LEVEL):
		1:
			return 1.0
		2, 3:
			return 1.2
		_:
			return 1.0


func _level_attack_rate_multiplier(level: int) -> float:
	match clampi(level, 1, MAX_WEAPON_LEVEL):
		1, 2:
			return 1.0
		3:
			return 1.2
		_:
			return 1.0


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
