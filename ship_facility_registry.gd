class_name ShipFacilityRegistry
extends Node

## 함선 시설의 런타임 상태(레벨) 보관소.
## 스탯 적용은 ShipFacilityApplier, 표시는 ShipPanel이 맡고 여기서는 레벨만 관리한다.

signal facility_level_changed(facility_id: StringName, new_level: int)

@export var facilities: Array[ShipFacilityDefinition] = []

var _levels: Dictionary = {}


func _ready() -> void:
	for definition in get_facility_definitions():
		_levels[definition.id] = 1


func get_facility_definitions() -> Array[ShipFacilityDefinition]:
	var definitions: Array[ShipFacilityDefinition] = []
	for definition in facilities:
		if definition == null:
			continue
		if definition.id == &"":
			push_error("ShipFacilityRegistry: facility definition without an id.")
			continue
		definitions.append(definition)
	return definitions


func get_facility_definition(facility_id: StringName) -> ShipFacilityDefinition:
	for definition in facilities:
		if definition != null and definition.id == facility_id:
			return definition
	return null


func has_facility(facility_id: StringName) -> bool:
	return _levels.has(facility_id)


## 미등록 시설은 0을 돌려준다 (등록된 시설의 최소 레벨은 1).
func get_facility_level(facility_id: StringName) -> int:
	return int(_levels.get(facility_id, 0))


func get_max_facility_level(facility_id: StringName) -> int:
	var definition := get_facility_definition(facility_id)
	if definition == null:
		return 0
	return definition.get_max_level()


func can_upgrade_facility(facility_id: StringName) -> bool:
	if not has_facility(facility_id):
		return false
	return get_facility_level(facility_id) < get_max_facility_level(facility_id)


## 외부(강화 선택 흐름 등)에서 호출하는 유일한 레벨 변경 경로.
func upgrade_facility(facility_id: StringName) -> bool:
	if not can_upgrade_facility(facility_id):
		return false
	var level := get_facility_level(facility_id) + 1
	_levels[facility_id] = level
	facility_level_changed.emit(facility_id, level)
	return true


## 현재 레벨의 효과값 (배율형은 배율, 가산형은 가산치).
func get_facility_effect(facility_id: StringName) -> float:
	var definition := get_facility_definition(facility_id)
	if definition == null:
		return 1.0
	return definition.get_value_for_level(get_facility_level(facility_id))


func get_facility_effect_at_level(facility_id: StringName, level: int) -> float:
	var definition := get_facility_definition(facility_id)
	if definition == null:
		return 1.0
	return definition.get_value_for_level(level)


## 상한이면 현재 레벨 효과와 동일한 값을 돌려준다.
func get_next_facility_effect(facility_id: StringName) -> float:
	var next_level := get_facility_level(facility_id)
	if can_upgrade_facility(facility_id):
		next_level += 1
	return get_facility_effect_at_level(facility_id, next_level)


## 같은 효과 종류를 가진 시설을 합산한다 (배율형은 곱, 가산형은 합).
func get_effect_total(effect: ShipFacilityDefinition.Effect) -> float:
	var is_multiplier := ShipFacilityDefinition.is_multiplier_effect(effect)
	var total := ShipFacilityDefinition.get_neutral_value_for(effect)
	for definition in get_facility_definitions():
		if definition.effect != effect:
			continue
		var value := definition.get_value_for_level(get_facility_level(definition.id))
		if is_multiplier:
			total *= value
		else:
			total += value
	return total
