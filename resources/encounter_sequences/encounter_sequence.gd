class_name EncounterSequence
extends Resource

## 한 판의 적 등장 시나리오(최상위 Resource).
##
## 계층:
##   Sequence
##     · shared_steps = 토큰 사전 (a→NORMAL, b→WAVE …)
##     · phases[]     = 재생 구간들 (각 Phase에 pattern 문자열)
##     · on_complete  = 마지막 Phase가 끝나면 반복할지 / 멈출지
##
## 에디터에서 고치는 진입점: `main_encounter_sequence.tres`
## 런타임 재생: `EncounterDirector`

enum OnComplete {
	## 마지막 Phase의 pattern을 처음부터 다시 돈다 (한 판이 끝나지 않음).
	REPEAT_LAST_PHASE,
	## 시퀀스 종료. Director가 idle.
	STOP,
}

@export var sequence_id: StringName
## 모든 Phase가 공유하는 토큰 정의. pattern의 글자 → Step 매핑.
@export var shared_steps: Array[EncounterSequenceStep] = []
## 위에서 아래로 순서 재생. 지금은 보통 Phase 1개.
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
