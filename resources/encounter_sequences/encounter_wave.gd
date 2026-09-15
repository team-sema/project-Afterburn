class_name EncounterWave
extends Resource

## WAVE 스텝이 참조하는 “연속 편대 묶음”.
## encounter_presets를 앞에서부터 스폰하고, 편대 사이마다 interval을 쉰다.
## (스텝의 post_delay와 다름: interval=웨이브 안, post_delay=웨이브 끝난 뒤 다음 토큰)

@export var wave_id: StringName
## 스폰 순서 고정.
@export var encounter_presets: Array[EncounterPreset] = []
## 편대와 편대 사이 대기(초), [min, max] 랜덤.
@export_range(0.0, 30.0, 0.05, "suffix:s") var interval_min := 1.0
@export_range(0.0, 30.0, 0.05, "suffix:s") var interval_max := 1.0


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
	if encounter_presets.is_empty():
		errors.append("EncounterWave requires at least one EncounterPreset.")
	for index in encounter_presets.size():
		var preset := encounter_presets[index]
		if preset == null:
			errors.append("encounter_presets[%d] is null." % index)
		elif not preset.validate():
			errors.append("encounter_presets[%d] is invalid." % index)
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
