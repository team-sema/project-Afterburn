extends SceneTree
## The main sequence is composed as lesson phrases: each phase introduces one
## skill with two alternative waves, Threat-gated so phase 1 only uses
## Threat-1 content. See docs/design/run-pacing.md 「구절 작곡」.

const SEQUENCE := "res://resources/encounter_sequences/main_encounter_sequence.tres"
const POOL := "res://resources/encounters/pools/main_encounter_pool.tres"
## Phase index -> Threat the player has reached when that phase starts.
const PHASE_THREAT := [1, 2, 3, 4]
## Lesson tokens expected per phase (order matters).
const PHASE_LESSONS := [["L", "H", "W"], ["S", "B", "G"], ["F", "D"], ["S", "F", "B", "G", "D"]]

var failures := PackedStringArray()


func _initialize() -> void:
	_run.call_deferred()


func _expect(value: bool, message: String) -> void:
	if not value:
		failures.append(message)


func _min_threat_of(pool: EncounterPool, preset: EncounterPreset) -> int:
	for entry in pool.entries:
		if entry.preset == preset or entry.preset.encounter_id == preset.encounter_id:
			return entry.min_threat
	return 1  # out-of-pool lesson content (drone triangle/zigzag) is Threat-1 drone material


func _run() -> void:
	var sequence := load(SEQUENCE) as EncounterSequence
	var pool := load(POOL) as EncounterPool
	_expect(sequence != null and sequence.validate(true), "main sequence validates")
	_expect(sequence.phases.size() == 4, "four phases: three lessons and a mix")
	var seen_waves := {}
	for phase_index in sequence.phases.size():
		var phase := sequence.phases[phase_index]
		var tokens := phase.get_tokens()
		var lessons_in_order := PackedStringArray()
		for token in tokens:
			var step := sequence.resolve_step(phase, StringName(token))
			_expect(step != null, "%s: token %s resolves" % [phase.phase_id, token])
			if step == null:
				continue
			if step.kind != EncounterSequenceStep.Kind.WAVE:
				continue
			lessons_in_order.append(token)
			var waves := step.get_waves()
			_expect(waves.size() == 2, "%s: lesson %s offers two alternative waves" % [phase.phase_id, token])
			for wave in waves:
				seen_waves[wave.wave_id] = true
				_expect(wave.validate(), "wave %s validates" % wave.wave_id)
				var presets := wave.get_encounter_presets()
				_expect(presets.size() == 3, "wave %s is a three-formation phrase" % wave.wave_id)
				for preset in presets:
					var needed := _min_threat_of(pool, preset)
					_expect(
						needed <= PHASE_THREAT[phase_index],
						"%s uses %s (Threat %d) but %s starts at Threat %d" % [wave.wave_id, preset.encounter_id, needed, phase.phase_id, PHASE_THREAT[phase_index]],
					)
		var expected: Array = PHASE_LESSONS[phase_index]
		_expect(
			lessons_in_order == PackedStringArray(expected),
			"%s lesson order is %s (got %s)" % [phase.phase_id, expected, lessons_in_order],
		)
		# Every lesson phase ends with an elite gate; the last two also reach the boss.
		_expect(tokens[tokens.size() - 1] == ("d" if phase_index >= 2 else "c"), "%s ends at its gate" % phase.phase_id)
		# Phrases are separated by at least one pool filler so the lesson can breathe.
		for index in range(1, tokens.size()):
			var prev := sequence.resolve_step(phase, StringName(tokens[index - 1]))
			var cur := sequence.resolve_step(phase, StringName(tokens[index]))
			if prev != null and cur != null and prev.kind == EncounterSequenceStep.Kind.WAVE and cur.kind == EncounterSequenceStep.Kind.WAVE:
				failures.append("%s plays two phrases back to back (%s %s)" % [phase.phase_id, tokens[index - 1], tokens[index]])
	_expect(seen_waves.size() == 16, "sixteen lesson waves are reachable from the sequence (got %d)" % seen_waves.size())
	# Phase 1 must introduce the three drone variants' lessons before Threat 2 content.
	var phase1_ids := {}
	for token in ["L", "H", "W"]:
		for wave in sequence.resolve_step(sequence.phases[0], StringName(token)).get_waves():
			for preset in wave.get_encounter_presets():
				phase1_ids[preset.encounter_id] = true
	_expect(phase1_ids.has(&"drone_spread_formation"), "phase 1 teaches fan width with the spread drone")
	_expect(not phase1_ids.has(&"drone_slow_zigzag") and not phase1_ids.has(&"drone_halt_formation"), "slow and halt drones wait for phase 2")
	_expect(sequence.on_complete == EncounterSequence.OnComplete.REPEAT_LAST_PHASE, "the mix phase repeats forever")

	if failures.is_empty():
		print("PASS run_phrase_sequence_test")
		quit(0)
		return
	for failure in failures:
		printerr("FAIL: ", failure)
	quit(1)
