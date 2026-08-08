class_name EncounterPoolEntry
extends Resource

## Scales inverse-difficulty into selection weights (weight = SCALE / difficulty).
const WEIGHT_SCALE := 60.0

@export var preset: EncounterPreset
## Encounter is ineligible below this Threat. At/above it, weight is SCALE/difficulty.
@export_range(1, 100, 1) var min_threat := 1


func get_weight(threat_level: int) -> float:
	if preset == null:
		return 0.0
	if maxi(1, threat_level) < min_threat:
		return 0.0
	var difficulty := maxf(preset.difficulty, 0.01)
	return WEIGHT_SCALE / difficulty


func get_max_defined_threat() -> int:
	return maxi(1, min_threat)


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if preset == null:
		errors.append("EncounterPoolEntry requires an EncounterPreset.")
	elif not preset.validate():
		errors.append("EncounterPoolEntry preset '%s' is invalid." % preset.encounter_id)
	if min_threat < 1:
		errors.append("EncounterPoolEntry min_threat must be 1 or greater.")
	return errors
