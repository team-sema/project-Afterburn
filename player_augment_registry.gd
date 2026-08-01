class_name PlayerAugmentRegistry
extends Node

signal augments_changed
signal facility_slots_changed(facility_id: StringName)

const DEFAULT_SLOT_CAPACITY := 1
const MAX_SLOT_CAPACITY := 3

@export var facilities: Array[ShipFacilityDefinition] = []


var _slot_capacities: Dictionary = {}
var _module_slots: Dictionary = {}


func _ready() -> void:
	for definition in get_facility_definitions():
		_slot_capacities[definition.id] = DEFAULT_SLOT_CAPACITY
		_module_slots[definition.id] = [null]


func get_facility_definitions() -> Array[ShipFacilityDefinition]:
	var definitions: Array[ShipFacilityDefinition] = []
	for definition in facilities:
		if definition == null:
			continue
		if definition.id == &"":
			push_error("PlayerAugmentRegistry: facility definition without an id.")
			continue
		definitions.append(definition)
	return definitions


func get_facility_definition(facility_id: StringName) -> ShipFacilityDefinition:
	for definition in facilities:
		if definition != null and definition.id == facility_id:
			return definition
	return null


func has_facility(facility_id: StringName) -> bool:
	return _module_slots.has(facility_id)


func get_slot_capacity(facility_id: StringName) -> int:
	return int(_slot_capacities.get(facility_id, 0))


func can_expand_slots(facility_id: StringName) -> bool:
	return has_facility(facility_id) and get_slot_capacity(facility_id) < MAX_SLOT_CAPACITY


func expand_slots(facility_id: StringName) -> bool:
	if not can_expand_slots(facility_id):
		return false
	_slot_capacities[facility_id] = get_slot_capacity(facility_id) + 1
	var slots := _module_slots[facility_id] as Array
	slots.append(null)
	facility_slots_changed.emit(facility_id)
	augments_changed.emit()
	return true


func get_facility_slots(facility_id: StringName) -> Array:
	if not has_facility(facility_id):
		return []
	return (_module_slots[facility_id] as Array).duplicate()


func get_installed_count(facility_id: StringName) -> int:
	var count := 0
	for module in get_facility_slots(facility_id):
		if module != null:
			count += 1
	return count


func has_empty_slot(facility_id: StringName) -> bool:
	return get_installed_count(facility_id) < get_slot_capacity(facility_id)


func install_augment(
	augment: PlayerAugment,
	target_weapon_id: StringName = &"",
	replace_index: int = -1,
) -> int:
	assert(augment != null, "Cannot install a null PlayerAugment.")
	if not has_facility(augment.facility_id):
		push_error("Unknown augment facility '%s'." % augment.facility_id)
		return -1
	var slots := _module_slots[augment.facility_id] as Array
	var slot_index := slots.find(null)
	if slot_index < 0:
		if replace_index < 0 or replace_index >= slots.size():
			return -1
		slot_index = replace_index
	slots[slot_index] = PlayerAugmentModuleState.new(augment, target_weapon_id)
	facility_slots_changed.emit(augment.facility_id)
	augments_changed.emit()
	return slot_index


func get_installed_modules() -> Array[PlayerAugmentModuleState]:
	var modules: Array[PlayerAugmentModuleState] = []
	for definition in get_facility_definitions():
		for module in get_facility_slots(definition.id):
			if module != null:
				modules.append(module as PlayerAugmentModuleState)
	return modules


func get_active_augments() -> Array[PlayerAugment]:
	var augments: Array[PlayerAugment] = []
	for module in get_installed_modules():
		augments.append(module.augment)
	return augments


func get_stack_count(augment_id: StringName) -> int:
	var stack_count := 0

	for augment in get_active_augments():
		if augment.augment_id == augment_id:
			stack_count += 1

	return stack_count


func clear_augments() -> void:
	for definition in get_facility_definitions():
		_slot_capacities[definition.id] = DEFAULT_SLOT_CAPACITY
		_module_slots[definition.id] = [null]
		facility_slots_changed.emit(definition.id)
	augments_changed.emit()


func get_effect_total(effect: ShipFacilityDefinition.Effect) -> float:
	var total := ShipFacilityDefinition.get_neutral_value_for(effect)
	for definition in get_facility_definitions():
		if definition.effect != effect:
			continue
		var module_count := 0
		for module in get_facility_slots(definition.id):
			if module == null:
				continue
			var state := module as PlayerAugmentModuleState
			if state.augment.augment_type == PlayerAugmentKind.Kind.FACILITY_EFFECT:
				module_count += 1
		var value := definition.get_value_for_module_count(module_count)
		if ShipFacilityDefinition.is_multiplier_effect(effect):
			total *= value
		else:
			total += value
	return total
