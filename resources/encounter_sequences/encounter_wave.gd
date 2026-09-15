class_name EncounterWave
extends Resource

## WAVE 스텝이 참조하는 “연속 편대 묶음”.
## 편대 목록은 Resource 배열이 아니라 **경로 문자열**로 적어 .tres에서 한 줄에 하나씩 읽히게 한다.
## (Array[EncounterPreset]는 Godot이 ExtResource를 가로로 이어 붙여 20개면 한 줄이 수천 자가 된다.)

@export var wave_id: StringName
## 스폰 순서 고정. 예: res://resources/encounters/presets/drone_straight_formation.tres
@export var encounter_preset_paths: PackedStringArray = []
## 편대와 편대 사이 대기(초), [min, max] 랜덤.
@export_range(0.0, 30.0, 0.05, "suffix:s") var interval_min := 1.0
@export_range(0.0, 30.0, 0.05, "suffix:s") var interval_max := 1.0


func get_encounter_presets() -> Array[EncounterPreset]:
	var presets: Array[EncounterPreset] = []
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
	if encounter_preset_paths.is_empty():
		errors.append("EncounterWave requires at least one encounter_preset_paths entry.")
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
	return errors


func validate(report_errors := false) -> bool:
	var errors := get_validation_errors()
	if report_errors:
		for error in errors:
			push_error("EncounterWave '%s': %s" % [wave_id, error])
	return errors.is_empty()
