class_name EncounterSequenceStep
extends Resource

## pattern 안의 토큰 하나(예: "a")의 의미.
## “무엇을 할지” + “끝난 뒤 다음 토큰까지 얼마나 쉴지”.

enum Kind {
	## 편대 1개 스폰. presets가 있으면 그중 랜덤, 없으면 pool(Threat 가중).
	NORMAL,
	## EncounterWave: 여러 편대를 interval 간격으로 연속 스폰.
	WAVE,
	## 엘리트 관문 (처치 → 탄소거 보상 → Threat+1 → 적 오그먼트 오퍼).
	ELITE,
	## 보스 관문. boss_preset 없으면 스킵. is_boss 플래그만 부여.
	BOSS,
}

## pattern에 적는 이름. 공백 불가.
@export var token: StringName
@export var kind := Kind.NORMAL

@export_group("Timing")
## 다음 스텝까지 대기(초). 매번 [min, max] 균등 랜덤.
## 기준 시각: NORMAL/WAVE = (마지막) 스폰 직후 · ELITE/BOSS = 관문 종료 후.
@export_range(0.0, 120.0, 0.05, "suffix:s") var post_delay_min := 2.8
@export_range(0.0, 120.0, 0.05, "suffix:s") var post_delay_max := 3.1

@export_group("Normal")
## 고정 후보. 1개면 그것만, 여러 개면 균등 랜덤. Threat min 무시.
@export var encounter_presets: Array[EncounterPreset] = []
## presets가 비었을 때만 사용. 예전 타이머 스폰과 같은 Threat 가중 풀.
@export var encounter_pool: EncounterPool

@export_group("Wave")
@export var wave: EncounterWave

@export_group("Gate")
## ELITE: 비우면 ThreatEliteController의 사격/돌격 교대 규칙.
@export var elite_preset: EncounterPreset
## BOSS: 비우면 경고 후 이 스텝 스킵 (보스 콘텐츠 미구현).
@export var boss_preset: EncounterPreset
## true면 추적 중인 이전 편대가 다 사라진 뒤에야 관문을 연다.
@export var wait_for_clear := true


func roll_post_delay(random_number_generator: RandomNumberGenerator = null) -> float:
	if post_delay_max <= post_delay_min:
		return post_delay_min
	if random_number_generator != null:
		return random_number_generator.randf_range(post_delay_min, post_delay_max)
	return randf_range(post_delay_min, post_delay_max)


func get_gate_preset() -> EncounterPreset:
	return boss_preset if kind == Kind.BOSS else elite_preset


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if token.is_empty():
		errors.append("EncounterSequenceStep requires a non-empty token.")
	elif String(token).strip_edges() != String(token) or String(token).contains(" "):
		errors.append("EncounterSequenceStep token '%s' must not contain whitespace." % token)
	if post_delay_min < 0.0:
		errors.append("post_delay_min cannot be negative.")
	if post_delay_max < post_delay_min:
		errors.append("post_delay_max must be >= post_delay_min.")
	match kind:
		Kind.NORMAL:
			if encounter_presets.is_empty() and encounter_pool == null:
				errors.append("NORMAL step requires encounter_presets or an encounter_pool.")
			for index in encounter_presets.size():
				var preset := encounter_presets[index]
				if preset == null:
					errors.append("NORMAL encounter_presets[%d] is null." % index)
				elif not preset.validate():
					errors.append("NORMAL encounter_presets[%d] is invalid." % index)
			if encounter_presets.is_empty() and encounter_pool != null and not encounter_pool.validate():
				errors.append("NORMAL encounter_pool is invalid.")
		Kind.WAVE:
			if wave == null:
				errors.append("WAVE step requires an EncounterWave.")
			elif not wave.validate():
				errors.append("WAVE step EncounterWave is invalid.")
		Kind.ELITE:
			_append_gate_preset_errors(errors, elite_preset, "ELITE elite_preset")
		Kind.BOSS:
			_append_gate_preset_errors(errors, boss_preset, "BOSS boss_preset")
		_:
			errors.append("EncounterSequenceStep kind is invalid.")
	return errors


func _append_gate_preset_errors(
	errors: PackedStringArray,
	preset: EncounterPreset,
	label: String,
) -> void:
	if preset == null:
		return
	if not preset.validate():
		errors.append("%s is invalid." % label)
	elif preset.members.size() != 1:
		errors.append("%s must contain exactly one member." % label)


func validate(report_errors := false) -> bool:
	var errors := get_validation_errors()
	if report_errors:
		for error in errors:
			push_error("EncounterSequenceStep '%s': %s" % [token, error])
	return errors.is_empty()
