class_name EncounterWave
extends Resource

## WAVE 스텝이 참조하는 “연속 편대 묶음”.
## 편대 목록의 정본은 `encounter_presets`(Resource 참조)다. 열려 있는 에디터가
## 외부에서 바뀐 .tres를 다시 저장할 때 `PackedStringArray` export를 비워 버리는
## 일이 있어(2026-10-07, lesson_*.tres 16개), 경로 문자열 목록은 옛 데이터 호환용
## 폴백으로만 남긴다. 둘 다 있으면 `encounter_presets`를 쓴다.

@export var wave_id: StringName
## 스폰 순서 고정. 정본.
@export var encounter_presets: Array[EncounterPreset] = []
## 호환용 폴백. `encounter_presets`가 비었을 때만 경로를 읽는다.
@export var encounter_preset_paths: PackedStringArray = []
## 편대와 편대 사이 대기(초). `handoff_remaining` 0이면 [min, max] 랜덤,
## 1 이상이면 min = 바닥 · max = 천장인 인계 규칙 (run-pacing.md 「등장 시퀀스」).
@export_range(0.0, 30.0, 0.05, "suffix:s") var interval_min := 1.0
@export_range(0.0, 30.0, 0.05, "suffix:s") var interval_max := 1.0
## 1 이상이면 이 wave가 지금까지 낸 편대의 살아 있는 적 합계가 이 수 이하로
## 줄어든 순간(단, interval_min 이후) 다음 편대를 낸다. 0이면 인계 없음.
@export_range(0, 32, 1) var handoff_remaining := 0


func uses_handoff() -> bool:
	return handoff_remaining > 0


func get_encounter_presets() -> Array[EncounterPreset]:
	var presets: Array[EncounterPreset] = []
	if not encounter_presets.is_empty():
		for preset in encounter_presets:
			if preset != null:
				presets.append(preset)
		return presets
	for path in encounter_preset_paths:
		if path.is_empty():
			continue
		var preset := load(path) as EncounterPreset
		assert(
			preset != null,
			"EncounterWave '%s' could not load EncounterPreset at '%s'." % [wave_id, path],
		)
		presets.append(preset)
	return presets


func roll_interval(random_number_generator: RandomNumberGenerator = null) -> float:
	if interval_max <= interval_min:
		return interval_min
	if random_number_generator != null:
		return random_number_generator.randf_range(interval_min, interval_max)
	return randf_range(interval_min, interval_max)


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if wave_id.is_empty():
		errors.append("EncounterWave requires a non-empty wave_id.")
	if encounter_presets.is_empty() and encounter_preset_paths.is_empty():
		errors.append("EncounterWave requires encounter_presets (or legacy encounter_preset_paths).")
	for index in encounter_presets.size():
		var preset := encounter_presets[index]
		if preset == null:
			errors.append("encounter_presets[%d] is null." % index)
		elif not preset.validate():
			errors.append("encounter_presets[%d] ('%s') is invalid." % [index, preset.encounter_id])
	for index in encounter_preset_paths.size():
		var path := encounter_preset_paths[index]
		if path.is_empty():
			errors.append("encounter_preset_paths[%d] is empty." % index)
			continue
		if not ResourceLoader.exists(path):
			errors.append("encounter_preset_paths[%d] does not exist: %s" % [index, path])
			continue
		var preset := load(path) as EncounterPreset
		if preset == null:
			errors.append("encounter_preset_paths[%d] is not an EncounterPreset: %s" % [index, path])
		elif not preset.validate():
			errors.append("encounter_preset_paths[%d] is invalid: %s" % [index, path])
	if interval_min < 0.0:
		errors.append("interval_min cannot be negative.")
	if interval_max < interval_min:
		errors.append("interval_max must be >= interval_min.")
	if handoff_remaining < 0:
		errors.append("handoff_remaining cannot be negative.")
	return errors


func validate(report_errors := false) -> bool:
	var errors := get_validation_errors()
	if report_errors:
		for error in errors:
			push_error("EncounterWave '%s': %s" % [wave_id, error])
	return errors.is_empty()
