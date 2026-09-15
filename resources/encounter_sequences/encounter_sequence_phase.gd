class_name EncounterSequencePhase
extends Resource

## A whitespace-separated token pattern such as "a a a b a a c". Tokens resolve
## to this phase's steps first, then to EncounterSequence.shared_steps.

@export var phase_id: StringName
@export_multiline var pattern := ""
@export_range(1, 99, 1) var repeat_count := 1
## Phase-local token definitions. Same token here overrides shared_steps.
@export var steps: Array[EncounterSequenceStep] = []


func get_tokens() -> PackedStringArray:
	var normalized := pattern.replace("\n", " ").replace("\t", " ").replace("\r", " ")
	return normalized.split(" ", false)


func find_local_step(token: StringName) -> EncounterSequenceStep:
	for step in steps:
		if step != null and step.token == token:
			return step
	return null


func resolve_step(
	token: StringName,
	shared_steps: Array[EncounterSequenceStep],
) -> EncounterSequenceStep:
	var local := find_local_step(token)
	if local != null:
		return local
	for step in shared_steps:
		if step != null and step.token == token:
			return step
	return null


func get_validation_errors(
	shared_steps: Array[EncounterSequenceStep] = [],
) -> PackedStringArray:
	var errors := PackedStringArray()
	if phase_id.is_empty():
		errors.append("EncounterSequencePhase requires a non-empty phase_id.")
	if repeat_count < 1:
		errors.append("repeat_count must be at least 1.")
	var seen_tokens := {}
	for index in steps.size():
		var step := steps[index]
		if step == null:
			errors.append("steps[%d] is null." % index)
			continue
		if not step.validate():
			errors.append("steps[%d] ('%s') is invalid." % [index, step.token])
		if seen_tokens.has(step.token):
			errors.append("Token '%s' is defined twice in this phase." % step.token)
		seen_tokens[step.token] = true
	var tokens := get_tokens()
	if tokens.is_empty():
		errors.append("pattern must contain at least one token.")
	for token in tokens:
		if resolve_step(StringName(token), shared_steps) == null:
			errors.append("Token '%s' in pattern is not defined in phase steps or shared_steps." % token)
	return errors


func validate(
	report_errors := false,
	shared_steps: Array[EncounterSequenceStep] = [],
) -> bool:
	var errors := get_validation_errors(shared_steps)
	if report_errors:
		for error in errors:
			push_error("EncounterSequencePhase '%s': %s" % [phase_id, error])
	return errors.is_empty()
