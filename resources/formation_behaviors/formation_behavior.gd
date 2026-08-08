class_name FormationBehavior
extends Resource

## Stateless slot-offset transformation shared by a whole formation.
## Per-formation time and phase belong in the runtime_context supplied by the
## FormationController, so one Resource can be reused by simultaneous encounters.


func transform_slot(
	original_slot_offset: Vector2,
	_slot: FormationSlot,
	_runtime_context: Dictionary,
) -> Vector2:
	return original_slot_offset


func get_validation_errors() -> PackedStringArray:
	return PackedStringArray()


func validate(report_errors := false) -> bool:
	var errors := get_validation_errors()
	if report_errors:
		for error in errors:
			push_error("FormationBehavior: %s" % error)
	return errors.is_empty()
