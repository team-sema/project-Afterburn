class_name PlayerWeaponLoadout
extends Node2D

## Unified weapon bays. Growth is keyed by weapon_id; all equipped weapons fire together.

signal weapon_equipped(weapon_id: StringName, slot_index: int)
signal weapon_unequipped(weapon_id: StringName, slot_index: int)
signal weapon_replaced(removed_weapon_id: StringName, new_weapon_id: StringName, slot_index: int)
signal weapon_level_changed(weapon_id: StringName, new_level: int)
signal weapon_trait_changed(weapon_id: StringName, trait_id: StringName, new_rank: int)
signal weapon_slots_changed
signal loadout_changed

const MAX_WEAPON_LEVEL := 3

@export var default_weapon: WeaponDefinition
@export var player_path: NodePath
@export_range(1, 8, 1) var max_equipped_weapon_count := 3

@onready var weapon_mounts_root: Node2D = $WeaponMounts

var _player: Node2D
var _bays: Array[WeaponSlotState] = []
var _mounts: Array[Node2D] = []
## weapon_id -> WeaponProgressState
var _progress: Dictionary = {}
var _global_damage_multiplier := 1.0
var _global_fire_rate_multiplier := 1.0
var _facility_damage_multiplier := 1.0


func _ready() -> void:
	_player = get_node_or_null(player_path) as Node2D
	if _player == null:
		_player = get_parent() as Node2D
	_ensure_bays_and_mounts()
	if default_weapon != null:
		equip_weapon(default_weapon)


func _ensure_bays_and_mounts() -> void:
	assert(weapon_mounts_root != null, "PlayerWeaponLoadout requires WeaponMounts.")
	var count := maxi(1, max_equipped_weapon_count)
	while _mounts.size() < count:
		var mount := Node2D.new()
		mount.name = "WeaponMount%d" % (_mounts.size() + 1)
		weapon_mounts_root.add_child(mount)
		_mounts.append(mount)
	while _bays.size() < count:
		var slot := WeaponSlotState.new()
		slot.slot_index = _bays.size()
		_bays.append(slot)
	# Shrink only empty trailing bays if count lowered at runtime (rare).
	while _bays.size() > count:
		var last: WeaponSlotState = _bays[_bays.size() - 1]
		if not last.is_empty():
			break
		_bays.pop_back()


func get_max_equipped_weapon_count() -> int:
	return maxi(1, max_equipped_weapon_count)


func get_equipped_weapons() -> Array[WeaponDefinition]:
	var result: Array[WeaponDefinition] = []
	for bay in _bays:
		if bay.is_empty() or bay.equipped_weapon_definition == null:
			continue
		result.append(bay.equipped_weapon_definition)
	return result


func get_equipped_weapon_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for bay in _bays:
		if bay.is_empty():
			continue
		ids.append(bay.equipped_weapon_id)
	return ids


func get_bay(slot_index: int) -> WeaponSlotState:
	if slot_index < 0 or slot_index >= _bays.size():
		return null
	return _bays[slot_index]


func get_first_empty_bay() -> int:
	for index in _bays.size():
		if _bays[index].is_empty():
			return index
	return -1


func is_weapon_equipped(weapon_id: StringName) -> bool:
	return find_equipped_slot(weapon_id) >= 0


func find_equipped_slot(weapon_id: StringName) -> int:
	if weapon_id == &"":
		return -1
	for index in _bays.size():
		if _bays[index].equipped_weapon_id == weapon_id:
			return index
	return -1


func has_empty_bay() -> bool:
	return get_first_empty_bay() >= 0


func is_bays_full() -> bool:
	return get_first_empty_bay() < 0


func get_weapon_state(weapon_id: StringName) -> WeaponProgressState:
	if weapon_id == &"":
		return null
	return _progress.get(weapon_id) as WeaponProgressState


func get_weapon_level(weapon_id: StringName) -> int:
	var state := get_weapon_state(weapon_id)
	if state == null:
		return 1
	return clampi(state.level, 1, MAX_WEAPON_LEVEL)


func get_base_weapon_level(weapon_id: StringName) -> int:
	return get_weapon_level(weapon_id)


func get_weapon_traits(weapon_id: StringName) -> Dictionary:
	var state := get_weapon_state(weapon_id)
	if state == null:
		return {}
	return state.trait_ranks.duplicate()


func get_weapon_definition(weapon_id: StringName) -> WeaponDefinition:
	var state := get_weapon_state(weapon_id)
	if state != null and state.definition != null:
		return state.definition
	for bay in _bays:
		if bay.equipped_weapon_id == weapon_id:
			return bay.equipped_weapon_definition
	return null


func get_weapon_display_name(weapon_id: StringName) -> String:
	var definition := get_weapon_definition(weapon_id)
	if definition != null:
		return definition.display_name
	return String(weapon_id)


func get_weapon_description(weapon_id: StringName) -> String:
	var definition := get_weapon_definition(weapon_id)
	if definition != null:
		return definition.description
	return ""


func get_trait_definition(trait_id: StringName) -> WeaponTraitDefinition:
	if trait_id == &"":
		return null
	var path := "res://resources/weapons/traits/%s.tres" % String(trait_id)
	if ResourceLoader.exists(path):
		return load(path) as WeaponTraitDefinition
	# Common id aliases used by augment resources (e.g. blaster_pierce).
	var dir := DirAccess.open("res://resources/weapons/traits")
	if dir == null:
		return null
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var candidate := load("res://resources/weapons/traits/%s" % file_name) as WeaponTraitDefinition
			if candidate != null and candidate.trait_id == trait_id:
				return candidate
		file_name = dir.get_next()
	return null


func get_trait_display_name(trait_id: StringName) -> String:
	var definition := get_trait_definition(trait_id)
	if definition != null and definition.display_name != "":
		return definition.display_name
	return String(trait_id)


func get_trait_description(trait_id: StringName) -> String:
	var definition := get_trait_definition(trait_id)
	if definition != null:
		return definition.description
	return ""


func get_trait_icon(trait_id: StringName) -> Texture2D:
	var definition := get_trait_definition(trait_id)
	if definition == null:
		return null
	if definition.icon != null:
		return definition.icon
	# Trait SVGs are optional — fall back to the target weapon icon so STATUS isn't blank.
	return get_weapon_icon(definition.target_weapon_id)


func get_weapon_icon(weapon_id: StringName) -> Texture2D:
	var definition := get_weapon_definition(weapon_id)
	if definition == null:
		return null
	return definition.icon


func has_weapon_progress(weapon_id: StringName) -> bool:
	return _progress.has(weapon_id)


func get_recorded_weapons() -> Array[WeaponProgressState]:
	## Deprecated: growth is not preserved for unequipped weapons.
	return []


func clear_weapon_progress(weapon_id: StringName) -> void:
	if weapon_id == &"" or not _progress.has(weapon_id):
		return
	_progress.erase(weapon_id)
	loadout_changed.emit()


func _reset_weapon_progress(weapon_definition: WeaponDefinition, starting_level: int) -> WeaponProgressState:
	assert(weapon_definition != null)
	clear_weapon_progress(weapon_definition.id)
	var state := WeaponProgressState.new()
	state.weapon_id = weapon_definition.id
	state.level = clampi(starting_level, 1, MAX_WEAPON_LEVEL)
	state.definition = weapon_definition
	state.trait_ranks = {}
	_progress[weapon_definition.id] = state
	weapon_level_changed.emit(weapon_definition.id, state.level)
	return state


func get_tracked_weapon_ids() -> Array[StringName]:
	return _sorted_tracked_ids()


func can_upgrade_weapon(weapon_id: StringName) -> bool:
	return weapon_id != &"" and get_weapon_level(weapon_id) < MAX_WEAPON_LEVEL


func set_global_stat_multipliers(damage_multiplier: float, fire_rate_multiplier: float) -> void:
	_global_damage_multiplier = maxf(0.01, damage_multiplier)
	_global_fire_rate_multiplier = maxf(0.01, fire_rate_multiplier)
	_refresh_all_weapon_multipliers()


## Weapon room: applies to every equipped weapon.
func set_facility_damage_multiplier(multiplier: float) -> void:
	_facility_damage_multiplier = maxf(0.01, multiplier)
	_refresh_all_weapon_multipliers()


## Compatibility alias used by older facility applier call sites during migration.
func set_facility_main_damage_multiplier(multiplier: float) -> void:
	set_facility_damage_multiplier(multiplier)


func get_facility_damage_multiplier() -> float:
	return _facility_damage_multiplier


func get_facility_main_damage_multiplier() -> float:
	return get_facility_damage_multiplier()


func get_all_weapon_systems() -> Array[WeaponSystem]:
	var systems: Array[WeaponSystem] = []
	for bay in _bays:
		if bay.equipped_weapon_instance != null and is_instance_valid(bay.equipped_weapon_instance):
			systems.append(bay.equipped_weapon_instance)
	return systems


func upgrade_weapon_level(weapon_id: StringName) -> bool:
	if weapon_id == &"" or not _progress.has(weapon_id):
		return false
	var state := get_weapon_state(weapon_id)
	if state.level >= MAX_WEAPON_LEVEL:
		return false
	state.level += 1
	weapon_level_changed.emit(weapon_id, state.level)
	_refresh_equipped_weapon_by_id(weapon_id)
	loadout_changed.emit()
	return true


func add_or_upgrade_weapon_trait(weapon_id: StringName, trait_id: StringName, rank_increase: int = 1) -> int:
	if weapon_id == &"" or trait_id == &"" or rank_increase == 0:
		return -1
	var state := _ensure_progress(weapon_id, null)
	var new_rank := state.get_trait_rank(trait_id) + rank_increase
	state.set_trait_rank(trait_id, new_rank)
	weapon_trait_changed.emit(weapon_id, trait_id, new_rank)
	loadout_changed.emit()
	return new_rank


## Augment offer: equip into an empty bay at starting_level with no traits.
## Re-acquiring after replace always starts fresh (no restore).
func offer_equip_weapon(weapon_definition: WeaponDefinition, starting_level: int = 1) -> bool:
	if weapon_definition == null or weapon_definition.id == &"":
		return false
	if is_weapon_equipped(weapon_definition.id):
		return true
	var empty := get_first_empty_bay()
	if empty < 0:
		return false
	_reset_weapon_progress(weapon_definition, starting_level)
	return equip_weapon(weapon_definition, empty)


## Replace an equipped bay. Deletes the removed weapon's level and traits permanently.
func request_replace_equipped(slot_index: int, weapon_definition: WeaponDefinition, starting_level: int = 1) -> bool:
	if weapon_definition == null:
		return false
	if slot_index < 0 or slot_index >= _bays.size():
		return false
	if is_weapon_equipped(weapon_definition.id) and find_equipped_slot(weapon_definition.id) != slot_index:
		return false
	var bay := _bays[slot_index]
	var removed_id := bay.equipped_weapon_id
	unequip_weapon_at(slot_index)
	# unequip already cleared removed progress
	_reset_weapon_progress(weapon_definition, starting_level)
	if not equip_weapon(weapon_definition, slot_index):
		return false
	weapon_replaced.emit(removed_id, weapon_definition.id, slot_index)
	return true


## Legacy field-pickup API — field drops are disabled; always fails.
func try_acquire_weapon(_weapon_definition: WeaponDefinition) -> bool:
	return false


func equip_weapon(weapon_definition: WeaponDefinition, slot_index: int = -1) -> bool:
	if weapon_definition == null or weapon_definition.weapon_scene == null:
		push_error("PlayerWeaponLoadout.equip_weapon: invalid definition.")
		return false
	_ensure_bays_and_mounts()
	var target := slot_index
	if target < 0:
		target = get_first_empty_bay()
	if target < 0 or target >= _bays.size():
		push_error("PlayerWeaponLoadout.equip_weapon: no empty bay.")
		return false
	if is_weapon_equipped(weapon_definition.id):
		push_error("PlayerWeaponLoadout.equip_weapon: '%s' already equipped." % String(weapon_definition.id))
		return false

	var bay := _bays[target]
	if not bay.is_empty():
		unequip_weapon_at(target)

	_ensure_progress(weapon_definition.id, weapon_definition)
	var mount := _mounts[target]
	var instance := _instantiate_weapon(weapon_definition, target, mount)
	if instance == null:
		return false

	bay.equipped_weapon_id = weapon_definition.id
	bay.equipped_weapon_display_name = weapon_definition.display_name
	bay.equipped_weapon_definition = weapon_definition
	bay.equipped_weapon_instance = instance
	_apply_multipliers_to_weapon(instance, weapon_definition.id)
	weapon_equipped.emit(weapon_definition.id, target)
	weapon_slots_changed.emit()
	loadout_changed.emit()
	return true


func unequip_weapon(weapon_id: StringName) -> bool:
	var index := find_equipped_slot(weapon_id)
	if index < 0:
		return false
	return unequip_weapon_at(index)


func unequip_weapon_at(slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= _bays.size():
		return false
	var bay := _bays[slot_index]
	if bay.is_empty():
		return false
	var weapon_id := bay.equipped_weapon_id
	_clear_bay(bay)
	clear_weapon_progress(weapon_id)
	weapon_unequipped.emit(weapon_id, slot_index)
	weapon_slots_changed.emit()
	loadout_changed.emit()
	return true


func get_weapon_damage_multiplier(weapon_id: StringName) -> float:
	return _level_damage_multiplier(get_weapon_level(weapon_id))


func get_weapon_attack_rate_multiplier(weapon_id: StringName) -> float:
	return _level_attack_rate_multiplier(get_weapon_level(weapon_id))


func _ensure_progress(weapon_id: StringName, definition: WeaponDefinition) -> WeaponProgressState:
	var state := get_weapon_state(weapon_id)
	if state == null:
		state = WeaponProgressState.new()
		state.weapon_id = weapon_id
		state.level = 1
		_progress[weapon_id] = state
		weapon_level_changed.emit(weapon_id, 1)
	if definition != null:
		state.definition = definition
	return state


func _instantiate_weapon(
	weapon_definition: WeaponDefinition,
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
	weapon.setup_weapon(_player, self, slot_index)
	return weapon


func _clear_bay(bay: WeaponSlotState) -> void:
	if bay.equipped_weapon_instance != null and is_instance_valid(bay.equipped_weapon_instance):
		var instance := bay.equipped_weapon_instance
		instance.shutdown_weapon()
		instance.queue_free()
	bay.equipped_weapon_instance = null
	bay.equipped_weapon_id = &""
	bay.equipped_weapon_display_name = ""
	bay.equipped_weapon_definition = null


func _apply_multipliers_to_weapon(weapon: WeaponSystem, weapon_id: StringName) -> void:
	if weapon == null or not is_instance_valid(weapon):
		return
	weapon.set_global_damage_multiplier(_global_damage_multiplier)
	weapon.set_global_fire_rate_multiplier(_global_fire_rate_multiplier)
	weapon.set_local_damage_multiplier(get_weapon_damage_multiplier(weapon_id))
	weapon.set_local_fire_rate_multiplier(get_weapon_attack_rate_multiplier(weapon_id))
	weapon.set_facility_damage_multiplier(_facility_damage_multiplier)
	weapon.set_consumable_capacity_bonus(0)


func _refresh_equipped_weapon_by_id(weapon_id: StringName) -> void:
	var index := find_equipped_slot(weapon_id)
	if index < 0:
		return
	var bay := _bays[index]
	_apply_multipliers_to_weapon(bay.equipped_weapon_instance, weapon_id)


func _refresh_all_weapon_multipliers() -> void:
	for bay in _bays:
		if bay.is_empty():
			continue
		_apply_multipliers_to_weapon(bay.equipped_weapon_instance, bay.equipped_weapon_id)


func _sorted_tracked_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for key in _progress.keys():
		ids.append(key as StringName)
	ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return ids


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
