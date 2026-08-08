class_name EncounterMember
extends Resource

@export var enemy_scene: PackedScene
@export var slot_index := 0
## Negative uses the FormationSlot's authored spawn_delay.
@export_range(-1.0, 60.0, 0.05) var spawn_delay_override := -1.0
@export var individual_movement_override: MovementSequence
## Optional release direction. Zero derives an outward direction from the slot.
@export var initial_direction := Vector2.ZERO


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if enemy_scene == null:
		errors.append("EncounterMember requires an enemy_scene.")
	if slot_index < 0:
		errors.append("EncounterMember slot_index must be zero or greater.")
	if spawn_delay_override < -1.0:
		errors.append("EncounterMember spawn_delay_override must be -1 or greater.")
	return errors
