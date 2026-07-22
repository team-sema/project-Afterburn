class_name PlayerAugmentRegistry
extends Node

signal augment_added(augment: PlayerAugment)
signal augments_cleared

@export var active_augments: Array[PlayerAugment] = []


func add_augment(augment: PlayerAugment) -> void:
	assert(augment != null, "Cannot add a null PlayerAugment.")
	active_augments.append(augment)
	augment_added.emit(augment)


func get_active_augments() -> Array[PlayerAugment]:
	return active_augments.duplicate()


func get_stack_count(augment_id: StringName) -> int:
	var stack_count := 0

	for augment in active_augments:
		if augment.augment_id == augment_id:
			stack_count += 1

	return stack_count


func clear_augments() -> void:
	if active_augments.is_empty():
		return

	active_augments.clear()
	augments_cleared.emit()
