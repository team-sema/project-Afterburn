class_name EncounterSequenceStep
extends Resource

## pattern 안의 토큰 하나(예: "a")의 의미.
## “무엇을 할지” + “끝난 뒤 다음 토큰까지 얼마나 쉴지”.

enum Kind {
	## 편대 1개 스폰. presets가 있으면 그중 랜덤, 없으면 pool(Threat 가중).
	NORMAL,
	## EncounterWave: `encounter_preset_paths` 순서대로 interval 간격 연속 스폰.
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
## 다음 스텝까지 대기(초). `handoff_remaining` 0이면 매번 [min, max] 균등 랜덤.
## 1 이상이면 min = 바닥 · max = 천장인 인계 규칙 (run-pacing.md 「등장 시퀀스」).
## 기준 시각: NORMAL/WAVE = (마지막) 스폰 직후 · ELITE/BOSS = 관문 종료 후.
@export_range(0.0, 120.0, 0.05, "suffix:s") var post_delay_min := 2.8
@export_range(0.0, 120.0, 0.05, "suffix:s") var post_delay_max := 3.1
## 인계: 1 이상이면 이 스텝이 낸 편대들의 살아 있는 적 합계가 이 수 이하로
## 줄면 post_delay_min만 채우고 바로 다음 스텝. WAVE/관문의 `wait_for_clear`
## 판정에도 같은 값을 쓴다 (잔존 ≤ 이 수 = 클리어). 0이면 인계 없음 · 전원 클리어.
@export_range(0, 32, 1) var handoff_remaining := 0

@export_group("Normal")
## 고정 후보. 1개면 그것만, 여러 개면 균등 랜덤. Threat min 무시.
@export var encounter_presets: Array[EncounterPreset] = []
## presets가 비었을 때만 사용. 예전 타이머 스폰과 같은 Threat 가중 풀.
@export var encounter_pool: EncounterPool
## 한 스텝에서 내는 편대 수. 2 이상이면 `encounter_gap` 간격으로 겹쳐 낸다.
@export_range(1, 4, 1) var encounter_count := 1
@export_range(0.0, 30.0, 0.05, "suffix:s") var encounter_gap := 1.2

@export_group("Wave")
@export var wave: EncounterWave
## 대안 구절. 비어 있지 않으면 `wave` 대신 이 중 하나를 균등 랜덤으로 고른다
## (직전에 재생한 wave_id 회피). 같은 교훈을 다른 편대로 가르칠 때 쓴다.
@export var waves: Array[EncounterWave] = []

@export_group("Gate")
## ELITE: 비우면 ThreatEliteController의 사격/돌격 교대 규칙.
@export var elite_preset: EncounterPreset
## BOSS: 비우면 경고 후 이 스텝 스킵 (보스 콘텐츠 미구현).
@export var boss_preset: EncounterPreset
## true면 WAVE WARNING / 관문 전에 추적 중인 이전 편대가 비울 때까지 기다린다.
@export var wait_for_clear := true
## >0이면 클리어와 이 초 중 먼저 온 쪽으로 진행. 0이면 클리어만 본다(무한).
@export_range(0.0, 120.0, 0.05, "suffix:s") var clear_timeout := 0.0
## wait_for_clear 대기 시작부터 최소 이 초는 쉰 뒤 WARNING/관문으로 간다 (빨리 클리어해도 호흡 유지).
@export_range(0.0, 120.0, 0.05, "suffix:s") var clear_min_wait := 0.0


func uses_handoff() -> bool:
	return handoff_remaining > 0


func roll_post_delay(random_number_generator: RandomNumberGenerator = null) -> float:
	if post_delay_max <= post_delay_min:
		return post_delay_min
	if random_number_generator != null:
		return random_number_generator.randf_range(post_delay_min, post_delay_max)
	return randf_range(post_delay_min, post_delay_max)


## WAVE 후보 전체 (`waves`가 있으면 그것, 없으면 `wave` 하나).
func get_waves() -> Array[EncounterWave]:
	var out: Array[EncounterWave] = []
	if not waves.is_empty():
		for candidate in waves:
			if candidate != null:
				out.append(candidate)
	elif wave != null:
		out.append(wave)
	return out


## 이번에 재생할 wave. 후보가 여럿이면 `avoid_wave_id`를 뺀 나머지에서 균등 랜덤.
func pick_wave(
	random_number_generator: RandomNumberGenerator = null,
	avoid_wave_id: StringName = &"",
) -> EncounterWave:
	var candidates := get_waves()
	if candidates.is_empty():
		return null
	if candidates.size() > 1 and avoid_wave_id != &"":
		var filtered: Array[EncounterWave] = []
		for candidate in candidates:
			if candidate.wave_id != avoid_wave_id:
				filtered.append(candidate)
		if not filtered.is_empty():
			candidates = filtered
	if candidates.size() == 1:
		return candidates[0]
	var index := (
		random_number_generator.randi_range(0, candidates.size() - 1)
		if random_number_generator != null
		else randi_range(0, candidates.size() - 1)
	)
	return candidates[index]


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
	if clear_timeout < 0.0:
		errors.append("clear_timeout cannot be negative.")
	if clear_min_wait < 0.0:
		errors.append("clear_min_wait cannot be negative.")
	if handoff_remaining < 0:
		errors.append("handoff_remaining cannot be negative.")
	match kind:
		Kind.NORMAL:
			if encounter_presets.is_empty() and encounter_pool == null:
				errors.append("NORMAL step requires encounter_presets or an encounter_pool.")
			if encounter_count < 1:
				errors.append("NORMAL encounter_count must be at least 1.")
			if encounter_gap < 0.0:
				errors.append("NORMAL encounter_gap cannot be negative.")
			for index in encounter_presets.size():
				var preset := encounter_presets[index]
				if preset == null:
					errors.append("NORMAL encounter_presets[%d] is null." % index)
				elif not preset.validate():
					errors.append("NORMAL encounter_presets[%d] is invalid." % index)
			if encounter_presets.is_empty() and encounter_pool != null and not encounter_pool.validate():
				errors.append("NORMAL encounter_pool is invalid.")
		Kind.WAVE:
			if wave == null and waves.is_empty():
				errors.append("WAVE step requires an EncounterWave (wave or waves).")
			if wave != null and not wave.validate():
				errors.append("WAVE step EncounterWave is invalid.")
			for index in waves.size():
				var candidate := waves[index]
				if candidate == null:
					errors.append("WAVE waves[%d] is null." % index)
				elif not candidate.validate():
					errors.append("WAVE waves[%d] ('%s') is invalid." % [index, candidate.wave_id])
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
