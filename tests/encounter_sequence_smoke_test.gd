extends SceneTree

## Covers EncounterSequence resources, EncounterDirector step flow with fakes,
## and the real gameplay.tscn wiring.

const DRONE_PRESET_PATH := "res://resources/encounters/presets/drone_straight_formation.tres"
const ZIGZAG_PRESET_PATH := "res://resources/encounters/presets/drone_zigzag_mirrored.tres"
const AWL_ELITE_PRESET_PATH := "res://resources/encounters/presets/threat_elite_awl.tres"
const MAIN_SEQUENCE_PATH := "res://resources/encounter_sequences/main_encounter_sequence.tres"
const MAIN_POOL_PATH := "res://resources/encounters/pools/main_encounter_pool.tres"

var failures := PackedStringArray()


class FakeGenerator:
	extends Node
	var automatic_spawning_enabled := true
	var spawned_ids: Array[StringName] = []
	var runs: Array[EncounterRun] = []
	var pool_picks := 0

	func set_automatic_spawning_enabled(is_enabled: bool) -> void:
		automatic_spawning_enabled = is_enabled

	func pick_from_pool(pool: EncounterPool, rng: RandomNumberGenerator) -> EncounterPreset:
		pool_picks += 1
		return pool.choose(1, rng, [])

	func spawn_preset_tracked(preset: EncounterPreset) -> EncounterRun:
		spawned_ids.append(preset.encounter_id)
		var run := EncounterRun.new()
		runs.append(run)
		return run

	func complete_all_runs() -> void:
		for run in runs:
			run.set("_member_spawns_finished", true)
			run.call("_try_complete")


class FakeProgression:
	extends Node
	signal elite_gate_changed(is_active: bool, threat_level: int)
	var automatic_elite_milestones := true
	var elite_gate_active := false
	var requests := 0

	func request_elite_milestone() -> bool:
		if elite_gate_active:
			return false
		elite_gate_active = true
		requests += 1
		elite_gate_changed.emit(true, 2)
		return true

	func close_gate() -> void:
		elite_gate_active = false
		elite_gate_changed.emit(false, 2)


class FakeEliteController:
	extends Node
	var gate_presets: Array = []
	var gate_boss_flags: Array[bool] = []

	func set_next_gate(preset: EncounterPreset, is_boss := false) -> void:
		gate_presets.append(preset)
		gate_boss_flags.append(is_boss)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await _test_resources()
	await _test_director_flow()
	await _test_wave_waits_for_clear()
	await _test_delay_and_boss_skip()
	await _test_gameplay_wiring()

	if failures.is_empty():
		print("encounter sequence smoke test: PASS")
		quit(0)
		return
	for failure in failures:
		push_error("encounter sequence smoke test: %s" % failure)
	quit(1)


func _test_resources() -> void:
	var main_sequence := load(MAIN_SEQUENCE_PATH) as EncounterSequence
	_expect(main_sequence != null and main_sequence.validate(), "main_encounter_sequence.tres validates")
	if main_sequence != null:
		_expect(main_sequence.shared_steps.size() == 4, "main sequence defines a/b/c/d")
		_expect(main_sequence.phases.size() == 1, "main sequence has one repeating phase")
		var main_phase := main_sequence.phases[0]
		var tokens := main_phase.get_tokens()
		_expect(tokens.size() == 23, "main pattern matches the authored a/b/c/d mix")
		_expect(tokens.has("b") and tokens.has("c") and tokens.has("d"), "main pattern includes wave, elite, and boss tokens")
		var step_c := main_sequence.resolve_step(main_phase, &"c")
		_expect(
			step_c != null and step_c.kind == EncounterSequenceStep.Kind.ELITE and step_c.wait_for_clear,
			"token c is an ELITE gate that waits for clear",
		)
		var step_a := main_sequence.resolve_step(main_phase, &"a")
		_expect(
			step_a != null and is_equal_approx(step_a.post_delay_min, 2.8) and is_equal_approx(step_a.post_delay_max, 3.1),
			"token a keeps the 2.8~3.1s timer feel",
		)
		var step_b := main_sequence.resolve_step(main_phase, &"b")
		_expect(
			step_b != null and step_b.wave != null and step_b.wave.encounter_preset_paths.size() == 3,
			"token b is a three-formation drone swarm wave",
		)
		_expect(
			step_b != null
			and step_b.wait_for_clear
			and is_equal_approx(step_b.clear_timeout, 6.0)
			and is_equal_approx(step_b.clear_min_wait, 2.5)
			and is_equal_approx(step_b.post_delay_min, 5.0)
			and is_equal_approx(step_b.post_delay_max, 5.5),
			"token b waits for clear with timeout/min breath, then a longer post_delay before the next a",
		)
		_expect(
			step_b != null
			and step_b.wave != null
			and is_equal_approx(step_b.wave.interval_min, 0.55)
			and is_equal_approx(step_b.wave.interval_max, 0.7),
			"drone swarm formations use the tighter 0.55~0.7s interval",
		)

	var phase := EncounterSequencePhase.new()
	phase.phase_id = &"tokens"
	phase.pattern = "a  a\n\tb   a"
	_expect(phase.get_tokens() == PackedStringArray(["a", "a", "b", "a"]), "pattern splits on any whitespace")

	var bad_step := EncounterSequenceStep.new()
	bad_step.token = &"x"
	bad_step.post_delay_min = 2.0
	bad_step.post_delay_max = 1.0
	_expect(not bad_step.validate(), "NORMAL step without candidates or with max < min is invalid")

	var wave_step := EncounterSequenceStep.new()
	wave_step.token = &"w"
	wave_step.kind = EncounterSequenceStep.Kind.WAVE
	_expect(not wave_step.validate(), "WAVE step without a wave is invalid")

	var sequence := EncounterSequence.new()
	sequence.sequence_id = &"undefined_token"
	var good_step := EncounterSequenceStep.new()
	good_step.token = &"a"
	good_step.encounter_pool = load(MAIN_POOL_PATH)
	sequence.shared_steps.append(good_step)
	var undefined_phase := EncounterSequencePhase.new()
	undefined_phase.phase_id = &"p"
	undefined_phase.pattern = "a z"
	sequence.phases.append(undefined_phase)
	_expect(not sequence.validate(), "pattern token without a step definition is invalid")
	undefined_phase.pattern = "a a"
	_expect(sequence.validate(), "sequence validates once every token is defined")

	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var rolled := EncounterSequenceStep.new()
	rolled.post_delay_min = 1.0
	rolled.post_delay_max = 2.0
	var in_range := true
	for _i in 32:
		var value := rolled.roll_post_delay(rng)
		if value < 1.0 or value > 2.0:
			in_range = false
	_expect(in_range, "roll_post_delay stays inside [min, max]")

	var warning_host := Node2D.new()
	root.add_child(warning_host)
	var warning := EncounterStepWarning.present(warning_host, EncounterSequenceStep.Kind.WAVE, 0.05)
	_expect(warning.get_parent() == warning_host, "step warning attaches under the gameplay host")
	await warning.finished
	await process_frame
	_expect(not is_instance_valid(warning), "step warning frees itself after the blink")
	warning_host.queue_free()
	await process_frame


func _make_director(
	sequence: EncounterSequence,
) -> Array:
	var host := Node.new()
	root.add_child(host)
	var generator := FakeGenerator.new()
	var progression := FakeProgression.new()
	var elite := FakeEliteController.new()
	host.add_child(generator)
	host.add_child(progression)
	host.add_child(elite)
	var director := EncounterDirector.new()
	director.enemy_generator = generator
	director.progression = progression
	director.threat_elite_controller = elite
	director.sequence = sequence
	director.autostart = false
	director.random_seed = 42
	director.step_warning_duration = 0.0
	host.add_child(director)
	return [host, director, generator, progression, elite]


func _normal_step(token: StringName, presets: Array[EncounterPreset], delay := 0.0) -> EncounterSequenceStep:
	var step := EncounterSequenceStep.new()
	step.token = token
	step.encounter_presets = presets
	step.post_delay_min = delay
	step.post_delay_max = delay
	return step


func _test_director_flow() -> void:
	var drone := load(DRONE_PRESET_PATH) as EncounterPreset
	var zigzag := load(ZIGZAG_PRESET_PATH) as EncounterPreset
	var awl_elite := load(AWL_ELITE_PRESET_PATH) as EncounterPreset

	var wave := EncounterWave.new()
	wave.wave_id = &"pair"
	wave.encounter_preset_paths = PackedStringArray([DRONE_PRESET_PATH, ZIGZAG_PRESET_PATH])
	wave.interval_min = 0.0
	wave.interval_max = 0.0
	var step_b := EncounterSequenceStep.new()
	step_b.token = &"b"
	step_b.kind = EncounterSequenceStep.Kind.WAVE
	step_b.wave = wave
	step_b.post_delay_min = 0.0
	step_b.post_delay_max = 0.0
	step_b.wait_for_clear = false
	var step_c := EncounterSequenceStep.new()
	step_c.token = &"c"
	step_c.kind = EncounterSequenceStep.Kind.ELITE
	step_c.elite_preset = awl_elite
	step_c.post_delay_min = 0.0
	step_c.post_delay_max = 0.0

	var sequence := EncounterSequence.new()
	sequence.sequence_id = &"flow"
	sequence.on_complete = EncounterSequence.OnComplete.STOP
	sequence.shared_steps = [_normal_step(&"a", [drone]), step_b, step_c]
	var phase := EncounterSequencePhase.new()
	phase.phase_id = &"flow"
	phase.pattern = "a b c a"
	sequence.phases = [phase]
	_expect(sequence.validate(), "flow test sequence validates")

	var parts := _make_director(sequence)
	var host: Node = parts[0]
	var director: EncounterDirector = parts[1]
	var generator: FakeGenerator = parts[2]
	var progression: FakeProgression = parts[3]
	var elite: FakeEliteController = parts[4]
	var completed := [false]
	director.sequence_completed.connect(func(_id: StringName) -> void: completed[0] = true)
	var tokens: Array[StringName] = []
	director.step_started.connect(func(token: StringName, _kind: int) -> void: tokens.append(token))

	_expect(director.start_sequence(), "director starts a valid sequence")
	_expect(not generator.automatic_spawning_enabled, "start disables timer spawning")
	_expect(not progression.automatic_elite_milestones, "start disables automatic elite milestones")
	await process_frame
	var expected_ids: Array[StringName] = [&"drone_formation", &"drone_formation", &"drone_zigzag_mirrored"]
	_expect(generator.spawned_ids == expected_ids, "a spawns one formation, b spawns its wave in order")
	_expect(director.current_step_index == 3, "progress tracks the elite step index")
	_expect(director.current_step_count == 4, "progress uses the phase token count")
	_expect(director.current_stage == 1, "first pattern pass is stage 1")
	_expect(director.get_active_encounter_count() == 3, "director tracks the three spawned runs")
	_expect(progression.requests == 0, "elite gate waits while encounters are alive")
	var expected_tokens: Array[StringName] = [&"a", &"b", &"c"]
	_expect(tokens == expected_tokens, "step_started fires per token")

	generator.complete_all_runs()
	await process_frame
	await process_frame
	await process_frame
	_expect(director.get_active_encounter_count() == 0, "completed runs leave the active list")
	_expect(progression.requests == 1, "clearing the field opens the elite gate")
	_expect(
		elite.gate_presets.size() == 1 and elite.gate_presets[0] == awl_elite and not elite.gate_boss_flags[0],
		"elite step hands its preset to ThreatEliteController",
	)
	_expect(generator.spawned_ids.size() == 3, "no normal spawn while the gate is open")

	progression.close_gate()
	await process_frame
	await process_frame
	await process_frame
	_expect(generator.spawned_ids.size() == 4, "gate close resumes with the final a")
	_expect(completed[0], "STOP sequence emits sequence_completed")
	_expect(not director.is_running, "director stops after STOP completion")

	host.queue_free()
	await process_frame


func _test_wave_waits_for_clear() -> void:
	var drone := load(DRONE_PRESET_PATH) as EncounterPreset
	var zigzag := load(ZIGZAG_PRESET_PATH) as EncounterPreset
	var wave := EncounterWave.new()
	wave.wave_id = &"pair"
	wave.encounter_preset_paths = PackedStringArray([DRONE_PRESET_PATH, ZIGZAG_PRESET_PATH])
	wave.interval_min = 0.0
	wave.interval_max = 0.0
	var step_b := EncounterSequenceStep.new()
	step_b.token = &"b"
	step_b.kind = EncounterSequenceStep.Kind.WAVE
	step_b.wave = wave
	step_b.post_delay_min = 0.0
	step_b.post_delay_max = 0.0
	step_b.wait_for_clear = true
	step_b.clear_timeout = 0.4
	step_b.clear_min_wait = 0.05
	var sequence := EncounterSequence.new()
	sequence.sequence_id = &"wave_clear"
	sequence.on_complete = EncounterSequence.OnComplete.STOP
	sequence.shared_steps = [_normal_step(&"a", [drone]), step_b]
	var phase := EncounterSequencePhase.new()
	phase.phase_id = &"wave_clear"
	phase.pattern = "a b"
	sequence.phases = [phase]

	var parts := _make_director(sequence)
	var host: Node = parts[0]
	var director: EncounterDirector = parts[1]
	var generator: FakeGenerator = parts[2]
	director.start_sequence()
	await process_frame
	await process_frame
	_expect(generator.spawned_ids == [&"drone_formation"], "WAVE holds until the prior NORMAL run clears or times out")
	generator.complete_all_runs()
	await create_timer(0.12).timeout
	_expect(
		generator.spawned_ids == [&"drone_formation", &"drone_formation", &"drone_zigzag_mirrored"],
		"WAVE starts after clear and clear_min_wait",
	)
	_expect(not director.is_running, "wave-clear sequence finishes after WAVE")

	host.queue_free()
	await process_frame


func _test_delay_and_boss_skip() -> void:
	var drone := load(DRONE_PRESET_PATH) as EncounterPreset
	var step_d := EncounterSequenceStep.new()
	step_d.token = &"d"
	step_d.kind = EncounterSequenceStep.Kind.BOSS
	step_d.post_delay_min = 5.0
	step_d.post_delay_max = 5.0
	var sequence := EncounterSequence.new()
	sequence.sequence_id = &"delay"
	sequence.on_complete = EncounterSequence.OnComplete.STOP
	sequence.shared_steps = [_normal_step(&"a", [drone], 0.15), step_d]
	var phase := EncounterSequencePhase.new()
	phase.phase_id = &"delay"
	phase.pattern = "d a a"
	sequence.phases = [phase]
	_expect(sequence.validate(), "delay test sequence validates")

	var parts := _make_director(sequence)
	var host: Node = parts[0]
	var director: EncounterDirector = parts[1]
	var generator: FakeGenerator = parts[2]
	var progression: FakeProgression = parts[3]
	director.start_sequence()
	await process_frame
	_expect(progression.requests == 0, "BOSS without a preset never opens a gate")
	_expect(generator.spawned_ids.size() == 1, "skipped BOSS adds no delay before the first a")
	await create_timer(0.05).timeout
	_expect(generator.spawned_ids.size() == 1, "post_delay holds the second a")
	await create_timer(0.3).timeout
	_expect(generator.spawned_ids.size() == 2, "second a spawns after the rolled post_delay")

	host.queue_free()
	await process_frame


func _test_gameplay_wiring() -> void:
	var gameplay := (load("res://gameplay.tscn") as PackedScene).instantiate()
	root.add_child(gameplay)
	var director := gameplay.get_node("EncounterDirector") as EncounterDirector
	var generator := gameplay.get_node("EnemyGenerator")
	var progression := gameplay.get_node("AugmentProgressionController") as AugmentProgressionController
	_expect(director != null, "gameplay.tscn has an EncounterDirector")
	if director == null:
		gameplay.queue_free()
		return
	_expect(director.sequence != null and director.sequence.sequence_id == &"main_encounter_sequence", "director uses main_encounter_sequence")
	await process_frame
	_expect(not director.is_running, "director stays idle when the scene is not current_scene")
	_expect(generator.automatic_spawning_enabled and progression.automatic_elite_milestones, "timers stay on until the director starts")

	var drone := load(DRONE_PRESET_PATH) as EncounterPreset
	var zigzag := load(ZIGZAG_PRESET_PATH) as EncounterPreset
	var wave := EncounterWave.new()
	wave.wave_id = &"pair"
	wave.encounter_preset_paths = PackedStringArray([DRONE_PRESET_PATH, ZIGZAG_PRESET_PATH])
	wave.interval_min = 0.0
	wave.interval_max = 0.0
	var step_b := EncounterSequenceStep.new()
	step_b.token = &"b"
	step_b.kind = EncounterSequenceStep.Kind.WAVE
	step_b.wave = wave
	step_b.post_delay_min = 0.0
	step_b.post_delay_max = 0.0
	step_b.wait_for_clear = false
	var sequence := EncounterSequence.new()
	sequence.sequence_id = &"wiring"
	sequence.on_complete = EncounterSequence.OnComplete.STOP
	sequence.shared_steps = [_normal_step(&"a", [drone]), step_b]
	var phase := EncounterSequencePhase.new()
	phase.phase_id = &"wiring"
	phase.pattern = "a b"
	sequence.phases = [phase]

	var spawned: Array[EncounterRun] = []
	director.encounter_spawned.connect(func(run: EncounterRun, _token: StringName) -> void: spawned.append(run))
	director.step_warning_duration = 0.0
	_expect(director.start_sequence(sequence), "director starts an override sequence on the real scene")
	_expect(generator.spawn_timer.is_stopped(), "real EnemyGenerator timer stops when the director takes over")
	_expect(not progression.automatic_elite_milestones, "real progression stops its 60s elite timer")
	await process_frame
	await process_frame
	_expect(spawned.size() == 3, "real spawner produced one normal + two wave formations")
	var formations := 0
	for node in gameplay.get_children():
		if node is FormationController:
			formations += 1
	_expect(formations == 3, "three FormationControllers exist under gameplay")
	if spawned.size() == 3:
		var run := spawned[0]
		_expect(run.controller != null and is_instance_valid(run.controller), "run keeps its FormationController")
		_expect(not run.is_completed(), "run with live members is not complete")
	_expect(not director.is_running, "STOP sequence on real scene finishes after b")

	progression._process(60.0)
	_expect(not progression.elite_gate_active, "manual mode ignores the elapsed elite timer")

	gameplay.queue_free()
	await process_frame


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
