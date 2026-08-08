class_name EncounterPoolEntry
extends Resource

@export var preset: EncounterPreset
@export var threat_weights: Array[ThreatWeight] = []


func get_weight(threat_level: int) -> float:
	if threat_weights.is_empty():
		return 0.0
	var effective_threat := maxi(1, threat_level)
	var selected_weight := 0.0
	for threat_weight in threat_weights:
		if threat_weight == null:
			continue
		if threat_weight.threat_level > effective_threat:
			break
		selected_weight = threat_weight.weight
	return selected_weight


func get_max_defined_threat() -> int:
	var maximum := 0
	for threat_weight in threat_weights:
		if threat_weight != null:
			maximum = maxi(maximum, threat_weight.threat_level)
	return maximum


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if preset == null:
		errors.append("EncounterPoolEntry requires an EncounterPreset.")
	elif not preset.validate():
		errors.append("EncounterPoolEntry preset '%s' is invalid." % preset.encounter_id)
	if threat_weights.is_empty():
		errors.append("EncounterPoolEntry requires ThreatWeight data.")
	for index in threat_weights.size():
		var threat_weight := threat_weights[index]
		if threat_weight == null:
			errors.append("ThreatWeight %d is null." % index)
			continue
		for threat_error in threat_weight.get_validation_errors():
			errors.append("ThreatWeight %d: %s" % [index, threat_error])
		var expected_level := index + 1
		if threat_weight.threat_level != expected_level:
			errors.append(
				"ThreatWeight %d must define Threat %d, got Threat %d."
				% [index, expected_level, threat_weight.threat_level]
			)
	return errors
