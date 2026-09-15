class_name EncounterDirector
extends Node

## Plays an EncounterSequence: walks each phase's token pattern and drives
## EnemyGenerator / AugmentProgressionController / ThreatEliteController
## instead of their timers. Timers stay untouched until start_sequence().

signal sequence_started(sequence_id: StringName)
signal phase_started(phase_id: StringName, repetition: int, repeat_count: int)
## step_index is 1-based within the current stage pattern pass.
## stage increments each time a phase pattern pass begins (including repeats).
signal sequence_progress_changed(
	stage: int,
	step_index: int,
	step_count: int,
	token: StringName,
	kind: EncounterSequenceStep.Kind,
)
signal step_started(token: StringName, kind: EncounterSequenceStep.Kind)
signal encounter_spawned(run: EncounterRun, token: StringName)
signal gate_requested(token: StringName, kind: EncounterSequenceStep.Kind)
signal sequence_completed(sequence_id: StringName)

@export var enemy_generator: Node
@export var progression: Node
@export var threat_elite_controller: Node
@export var sequence: EncounterSequence
## Start on _ready when this node lives under the running scene. Scenes added
## for tests (no current_scene) stay idle so timer behavior is unchanged.
@export var autostart := true
## 0 randomizes; any other value makes delays and picks reproducible.
@export var random_seed := 0
## Center-screen blink before WAVE / ELITE / BOSS. 0 skips (tests).
@export_range(0.0, 3.0, 0.05, "suffix:s") var step_warning_duration := 0.8

var is_running := false
var current_phase_id: StringName
var current_token: StringName
## 1-based stage: each full pattern pass (including REPEAT_LAST_PHASE) bumps this.
var current_stage := 0
## 1-based index inside the current stage pattern pass (0 before the first step).
var current_step_index := 0
var current_step_count := 0
var _random_number_generator := RandomNumberGenerator.new()
var _active_runs: Array[EncounterRun] = []
var _last_normal_encounter_id: StringName
var _stop_requested := false
var _wait_timer: Timer


func _ready() -> void:
	assert(enemy_generator != null, "EncounterDirector requires an EnemyGenerator.")
	assert(progression != null, "EncounterDirector requires an AugmentProgressionController.")
	assert(threat_elite_controller != null, "EncounterDirector requires a ThreatEliteController.")
	_wait_timer = Timer.new()
	_wait_timer.one_shot = true
	add_child(_wait_timer)
	if random_seed != 0:
		_random_number_generator.seed = random_seed
	else:
		_random_number_generator.randomize()
	if autostart and sequence != null and get_tree().current_scene != null:
		start_sequence.call_deferred()


func start_sequence(sequence_override: EncounterSequence = null) -> bool:
	if is_running:
		return false
	if sequence_override != null:
		sequence = sequence_override
	if sequence == null or not sequence.validate(true):
		push_error("EncounterDirector: no valid EncounterSequence to run.")
		return false
	is_running = true
	_stop_requested = false
	current_stage = 0
	current_step_index = 0
	current_step_count = 0
	enemy_generator.call("set_automatic_spawning_enabled", false)
	progression.set("automatic_elite_milestones", false)
	sequence_started.emit(sequence.sequence_id)
	_run_sequence()
	return true


func stop_sequence() -> void:
	_stop_requested = true
	if _wait_timer != null and not _wait_timer.is_stopped():
		_wait_timer.stop()
		# Resume the suspended coroutine so it can observe the stop request.
		_wait_timer.timeout.emit()


func get_active_encounter_count() -> int:
	return _active_runs.size()


func _run_sequence() -> void:
	var phases := sequence.phases
	var phase_index := 0
	while phase_index < phases.size() and _can_continue():
		var phase := phases[phase_index]
		for repetition in phase.repeat_count:
			if not _can_continue():
				break
			current_phase_id = phase.phase_id
			current_stage += 1
			phase_started.emit(phase.phase_id, repetition, phase.repeat_count)
			var tokens := phase.get_tokens()
			current_step_count = tokens.size()
			for token_index in tokens.size():
				if not _can_continue():
					break
				current_step_index = token_index + 1
				var step := sequence.resolve_step(phase, StringName(tokens[token_index]))
				sequence_progress_changed.emit(
					current_stage,
					current_step_index,
					current_step_count,
					step.token,
					step.kind,
				)
				await _run_step(step)
			# Guard against zero-delay patterns spinning inside one frame.
			await get_tree().process_frame
		phase_index += 1
		if (
			phase_index >= phases.size()
			and sequence.on_complete == EncounterSequence.OnComplete.REPEAT_LAST_PHASE
		):
			phase_index = phases.size() - 1
	is_running = false
	current_token = &""
	current_step_index = 0
	current_step_count = 0
	if not _stop_requested and is_inside_tree():
		sequence_completed.emit(sequence.sequence_id)


func _can_continue() -> bool:
	return not _stop_requested and is_inside_tree()


func _run_step(step: EncounterSequenceStep) -> void:
	current_token = step.token
	step_started.emit(step.token, step.kind)
	match step.kind:
		EncounterSequenceStep.Kind.NORMAL:
			_spawn_normal(step)
		EncounterSequenceStep.Kind.WAVE:
			await _play_step_warning(step.kind)
			if not _can_continue():
				return
			await _spawn_wave(step)
		EncounterSequenceStep.Kind.ELITE, EncounterSequenceStep.Kind.BOSS:
			var opened := await _run_gate(step)
			if not opened:
				return
	if not _can_continue():
		return
	await _wait_seconds(step.roll_post_delay(_random_number_generator))


func _play_step_warning(kind: EncounterSequenceStep.Kind) -> void:
	if step_warning_duration <= 0.0:
		return
	var host := get_parent()
	if host == null:
		return
	var warning := EncounterStepWarning.present(host, kind, step_warning_duration)
	await warning.finished


func _spawn_normal(step: EncounterSequenceStep) -> void:
	var preset := _pick_normal_preset(step)
	if preset == null:
		push_warning("EncounterDirector: step '%s' found no eligible encounter." % step.token)
		return
	_spawn_preset(preset, step.token)


func _pick_normal_preset(step: EncounterSequenceStep) -> EncounterPreset:
	if step.encounter_presets.is_empty():
		return enemy_generator.call("pick_from_pool", step.encounter_pool, _random_number_generator)
	var candidates: Array[EncounterPreset] = []
	for preset in step.encounter_presets:
		if preset != null and preset.encounter_id != _last_normal_encounter_id:
			candidates.append(preset)
	if candidates.is_empty():
		candidates = step.encounter_presets.duplicate()
	return candidates[_random_number_generator.randi_range(0, candidates.size() - 1)]


func _spawn_wave(step: EncounterSequenceStep) -> void:
	var wave := step.wave
	for index in wave.encounter_presets.size():
		if not _can_continue():
			return
		if index > 0:
			await _wait_seconds(wave.roll_interval(_random_number_generator))
			if not _can_continue():
				return
		_spawn_preset(wave.encounter_presets[index], step.token)


func _spawn_preset(preset: EncounterPreset, token: StringName) -> void:
	var run := enemy_generator.call("spawn_preset_tracked", preset) as EncounterRun
	if run == null:
		push_warning("EncounterDirector: '%s' failed to spawn %s." % [token, preset.encounter_id])
		return
	_last_normal_encounter_id = preset.encounter_id
	_track_run(run)
	encounter_spawned.emit(run, token)


func _track_run(run: EncounterRun) -> void:
	if run.is_completed():
		return
	_active_runs.append(run)
	run.completed.connect(_on_run_completed.bind(run), CONNECT_ONE_SHOT)


func _on_run_completed(run: EncounterRun) -> void:
	_active_runs.erase(run)


func _run_gate(step: EncounterSequenceStep) -> bool:
	var preset := step.get_gate_preset()
	var is_boss := step.kind == EncounterSequenceStep.Kind.BOSS
	if is_boss and preset == null:
		push_warning("EncounterDirector: BOSS step '%s' has no boss_preset; skipping." % step.token)
		return false
	if step.wait_for_clear:
		await _wait_for_clear()
		if not _can_continue():
			return false
	await _play_step_warning(step.kind)
	if not _can_continue():
		return false
	threat_elite_controller.call("set_next_gate", preset, is_boss)
	gate_requested.emit(step.token, step.kind)
	var opened: bool = progression.call("request_elite_milestone")
	if not opened:
		threat_elite_controller.call("set_next_gate", null, false)
		push_warning("EncounterDirector: gate '%s' could not open (gate already active)." % step.token)
		return false
	while _can_continue() and bool(progression.get("elite_gate_active")):
		await progression.elite_gate_changed
	return _can_continue()


func _wait_for_clear() -> void:
	while _can_continue() and not _active_runs.is_empty():
		var pending := _active_runs.duplicate()
		for run in pending:
			if not run.is_completed():
				await run.completed
				break
		await get_tree().process_frame


func _wait_seconds(duration: float) -> void:
	if duration <= 0.0 or not _can_continue():
		return
	_wait_timer.start(duration)
	await _wait_timer.timeout
