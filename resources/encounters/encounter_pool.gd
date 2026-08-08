class_name EncounterPool
extends Resource

@export var entries: Array[EncounterPoolEntry] = []


func choose(
	threat_level: int,
	random_number_generator: RandomNumberGenerator = null,
) -> EncounterPreset:
	if entries.is_empty():
		push_warning("EncounterPool selection skipped because the pool is empty.")
		return null
	var total_weight := 0.0
	for index in entries.size():
		var entry := entries[index]
		if entry == null or entry.preset == null:
			push_warning(
				"EncounterPool selection skipped because entry %d has no preset." % index
			)
			return null
		var weight := entry.get_weight(threat_level)
		if weight < 0.0:
			push_warning(
				"EncounterPool selection skipped because entry %d has negative weight."
				% index
			)
			return null
		total_weight += weight
	if total_weight <= 0.0:
		push_warning(
			"EncounterPool has no encounter with positive weight at Threat %d."
			% threat_level
		)
		return null
	var random_value := (
		random_number_generator.randf()
		if random_number_generator != null
		else randf()
	)
	var roll := random_value * total_weight
	for entry in entries:
		var weight := entry.get_weight(threat_level)
		if weight <= 0.0:
			continue
		roll -= weight
		if roll <= 0.0:
			return entry.preset
	for index in range(entries.size() - 1, -1, -1):
		if entries[index].get_weight(threat_level) > 0.0:
			return entries[index].preset
	return null


func get_total_weight(threat_level: int) -> float:
	var total := 0.0
	for entry in entries:
		if entry != null:
			total += maxf(0.0, entry.get_weight(threat_level))
	return total


func get_eligible_entries(threat_level: int) -> Array[EncounterPoolEntry]:
	var eligible: Array[EncounterPoolEntry] = []
	for entry in entries:
		if entry != null and entry.preset != null and entry.get_weight(threat_level) > 0.0:
			eligible.append(entry)
	return eligible


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if entries.is_empty():
		errors.append("EncounterPool requires at least one entry.")
	var ids: Dictionary = {}
	for index in entries.size():
		var entry := entries[index]
		if entry == null:
			errors.append("EncounterPool entry %d is null." % index)
			continue
		for entry_error in entry.get_validation_errors():
			errors.append("Entry %d: %s" % [index, entry_error])
		if entry.preset != null:
			if ids.has(entry.preset.encounter_id):
				errors.append(
					"EncounterPool duplicates encounter_id '%s'."
					% entry.preset.encounter_id
				)
			else:
				ids[entry.preset.encounter_id] = true
	var maximum_threat := 0
	for entry in entries:
		if entry != null:
			maximum_threat = maxi(maximum_threat, entry.get_max_defined_threat())
	for threat_level in range(1, maximum_threat + 1):
		if is_zero_approx(get_total_weight(threat_level)):
			errors.append(
				"EncounterPool total weight is zero at Threat %d." % threat_level
			)
	return errors


func validate(report_errors := false) -> bool:
	var errors := get_validation_errors()
	if report_errors:
		for error in errors:
			push_error("EncounterPool: %s" % error)
	return errors.is_empty()
