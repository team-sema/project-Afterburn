class_name ThreatWeight
extends Resource

## Explicit Inspector label for one Threat tier. EncounterPoolEntry requires
## consecutive levels starting at Threat 1 so no array index is ambiguous.
@export_range(1, 100, 1) var threat_level := 1
@export_range(0.0, 1000.0, 0.001, "or_greater") var weight := 0.0


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if threat_level < 1:
		errors.append("ThreatWeight threat_level must be 1 or greater.")
	if weight < 0.0:
		errors.append("ThreatWeight weight cannot be negative.")
	return errors
