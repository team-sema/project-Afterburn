class_name MaintainFormationBehavior
extends FormationBehavior

## Identity behavior: authored slot offsets remain unchanged.


func transform_slot(
	original_slot_offset: Vector2,
	_slot: FormationSlot,
	_runtime_context: Dictionary,
) -> Vector2:
	return original_slot_offset
