class_name OrbitFormationBehavior
extends FormationBehavior

## Degrees per second. Positive visual rotation follows Godot's 2D coordinate
## system; clockwise reverses the sign only when disabled.
@export_range(0.0, 720.0, 1.0, "or_greater", "suffix:deg/s") var angular_speed := 45.0
@export var clockwise := true
@export var excluded_slot_indices: Array[int] = []


func transform_slot(
	original_slot_offset: Vector2,
	slot: FormationSlot,
	runtime_context: Dictionary,
) -> Vector2:
	if slot != null and excluded_slot_indices.has(slot.slot_index):
		return original_slot_offset
	var elapsed_time := float(runtime_context.get("elapsed_time", 0.0))
	var direction := 1.0 if clockwise else -1.0
	return original_slot_offset.rotated(deg_to_rad(angular_speed) * elapsed_time * direction)


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	var seen: Dictionary = {}
	for slot_index in excluded_slot_indices:
		if slot_index < 0:
			errors.append("excluded_slot_indices cannot contain negative indices.")
		elif seen.has(slot_index):
			errors.append("excluded_slot_indices cannot contain duplicate index %d." % slot_index)
		seen[slot_index] = true
	return errors
