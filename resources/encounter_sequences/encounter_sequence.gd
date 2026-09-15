class_name EncounterSequence
extends Resource

## Authored spawn scenario: shared token definitions plus ordered phases.

enum OnComplete {
	REPEAT_LAST_PHASE,
	STOP,
}

@export var sequence_id: StringName
## Token definitions every phase can use (a / b / c / d ...).
@export var shared_steps: Array[EncounterSequenceStep] = []
@export var phases: Array[EncounterSequencePhase] = []
@export var on_complete := OnComplete.REPEAT_LAST_PHASE


func resolve_step(phase: EncounterSequencePhase, token: StringName) -> EncounterSequenceStep:
	if phase == null:
		return null
	return phase.resolve_step(token, shared_steps)


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if sequence_id.is_empty():
		errors.append("EncounterSequence requires a non-empty sequence_id.")
	var seen_tokens := {}
	for index in shared_steps.size():
		var step := shared_steps[index]
		if step == null:
			errors.append("shared_steps[%d] is null." % index)
			continue
		if not step.validate():
			errors.append("shared_steps[%d] ('%s') is invalid." % [index, step.token])
		if seen_tokens.has(step.token):
			errors.append("Shared token '%s' is defined twice." % step.token)
		seen_tokens[step.token] = true
	if phases.is_empty():
		errors.append("EncounterSequence requires at least one phase.")
	for index in phases.size():
		var phase := phases[index]
		if phase == null:
			errors.append("phases[%d] is null." % index)
		elif not phase.validate(false, shared_steps):
			errors.append("phases[%d] ('%s') is invalid." % [index, phase.phase_id])
	return errors


func validate(report_errors := false) -> bool:
	var errors := get_validation_errors()
	if report_errors:
		for error in errors:
			push_error("EncounterSequence '%s': %s" % [sequence_id, error])
		for phase in phases:
			if phase != null:
				phase.validate(true, shared_steps)
	return errors.is_empty()
