class_name EncounterSequenceStep
extends Resource

## One token of an EncounterSequencePhase pattern. What to spawn and how long
## to wait before the next token starts.

enum Kind {
	NORMAL,
	WAVE,
	ELITE,
	BOSS,
}

## Name used inside EncounterSequencePhase.pattern. No whitespace.
@export var token: StringName
@export var kind := Kind.NORMAL

@export_group("Timing")
## Delay before the next step starts, rolled uniformly in [min, max].
## NORMAL/WAVE measure from the (last) spawn; ELITE/BOSS from gate close.
@export_range(0.0, 120.0, 0.05, "suffix:s") var post_delay_min := 2.8
@export_range(0.0, 120.0, 0.05, "suffix:s") var post_delay_max := 3.1

@export_group("Normal")
## Explicit candidates. One entry spawns that formation; several pick uniformly.
## Explicit presets ignore Threat gating on purpose.
@export var encounter_presets: Array[EncounterPreset] = []
## Used only when encounter_presets is empty. Threat-weighted like timer spawning.
@export var encounter_pool: EncounterPool

@export_group("Wave")
@export var wave: EncounterWave

@export_group("Gate")
## ELITE: null falls back to the ThreatEliteController alternation rule.
@export var elite_preset: EncounterPreset
## BOSS: null skips the step with a warning (no boss content yet).
@export var boss_preset: EncounterPreset
## Wait until every tracked encounter is cleared before opening the gate.
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
