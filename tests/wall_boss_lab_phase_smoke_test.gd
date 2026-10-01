extends SceneTree
## RECYCLER Lab entry modes: straight to the boss, or the whole phase on the real gameplay assembly
## (main pattern minus its BOSS token → route progress → clear → WARNING → bay intake).
const DRONE_PRESET_PATH := "res://resources/encounters/presets/drone_straight_formation.tres"
var failures: Array[String] = []
var lab: Control


func _initialize() -> void:
	run.call_deferred()


func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)


func wait(seconds: float) -> void:
	await create_timer(seconds).timeout


func run() -> void:
	lab = preload("res://labs/bosses/wall/wall_boss_lab.tscn").instantiate()
	root.add_child(lab)
	current_scene = lab
	await process_frame
	await process_frame
	check(lab.mode == lab.Mode.BOSS_ONLY and is_instance_valid(lab.boss) and lab.director == null, "Lab opens straight on the boss with no encounter director")
	check(lab.bar.visible and lab.world.get_node_or_null("EncounterDirector") == null, "Boss-only mode keeps the light stand-alone world")

	# The Lab phase sequence mirrors the main pattern minus its BOSS token and stops at the end.
	var main := load("res://resources/encounter_sequences/main_encounter_sequence.tres") as EncounterSequence
	var sequence: EncounterSequence = lab.phase_sequence()
	check(sequence.validate(), "Lab phase sequence validates")
	check(sequence.on_complete == EncounterSequence.OnComplete.STOP, "Lab phase sequence stops instead of repeating")
	var main_tokens := main.phases[0].get_tokens()
	var lab_tokens := sequence.phases[0].get_tokens()
	check(lab_tokens.size() == main_tokens.size() - 1 and not lab_tokens.has("d") and lab_tokens.has("c") and lab_tokens.has("b"), "Lab pattern drops only the BOSS token")
	check(sequence.shared_steps == main.shared_steps, "Lab pattern reuses the main token definitions")

	# Full-phase mode: the real gameplay assembly runs inside the Lab viewport.
	lab.set_mode(lab.Mode.FULL_PHASE)
	await process_frame
	await process_frame
	await process_frame
	check(lab.mode == lab.Mode.FULL_PHASE and lab.boss == null and not lab.bar.visible, "Phase mode starts without the boss and hides its bar")
	check(lab.director != null and lab.director.is_running and lab.director.sequence.sequence_id == &"wall_lab_phase", "Phase mode drives the real EncounterDirector with the Lab sequence")
	var generator = lab.world.get_node("EnemyGenerator")
	var progression = lab.world.get_node("AugmentProgressionController")
	check(generator.spawn_timer.is_stopped() and not progression.automatic_elite_milestones, "Director takes over the timer spawner and the elite timer")
	check(lab.world.get_node_or_null("SpaceBackground") == null and lab.approach != null and lab.background != null, "Phase mode swaps in the Lab starfield and the approach route layer")
	check(is_instance_valid(lab.ship) and lab.ship == lab.world.get_node("Ship"), "Phase mode fights with the gameplay ship")
	await wait(0.3)
	check(lab.route_step == 1 and lab.route_step_count == main_tokens.size() - 1 and lab.approach.progress > 0.0, "Route progress follows the sequence step")
	check(lab.phase_label.text.begins_with("APPROACH / OPEN SPACE"), "HUD names the route beat")
	var formations := 0
	for node in lab.world.get_children():
		if node is FormationController: formations += 1
	check(formations >= 1, "The first token spawned a real formation")

	# Route beats and their titles.
	check(lab.Approach.beat_title(0.2) == "APPROACH / OPEN SPACE" and lab.Approach.beat_title(0.4) == "APPROACH / FORTRESS AHEAD", "Approach beats")
	check(lab.Approach.beat_title(0.7) == "INTERIOR / DEFENSES" and lab.Approach.beat_title(1.0) == "INTERIOR / BAY AHEAD", "Interior beats")

	# A short override sequence reaches the bay: clear wait, WARNING, then the boss intake.
	lab.restart()
	await process_frame
	await process_frame
	await process_frame
	var drone := load(DRONE_PRESET_PATH) as EncounterPreset
	var step := EncounterSequenceStep.new()
	step.token = &"a"
	step.encounter_presets = [drone]
	step.post_delay_min = 0.0
	step.post_delay_max = 0.0
	var short_sequence := EncounterSequence.new()
	short_sequence.sequence_id = &"wall_lab_short"
	short_sequence.on_complete = EncounterSequence.OnComplete.STOP
	short_sequence.shared_steps = [step]
	var phase := EncounterSequencePhase.new()
	phase.phase_id = &"short"
	phase.pattern = "a"
	short_sequence.phases = [phase]
	lab.director.stop_sequence()
	await process_frame
	await process_frame
	lab.director.step_warning_duration = 0.0
	check(lab.start_phase(short_sequence), "Lab accepts an override phase sequence")
	await wait(0.5)
	check(lab.boss == null and lab.route_progress >= 1.0 and lab.phase_label.text == "INTERIOR / BAY AHEAD", "Sequence end waits for the corridor to clear before the bay")
	for enemy in get_nodes_in_group("enemies"):
		if is_instance_valid(enemy) and lab.world.is_ancestor_of(enemy): enemy.queue_free()
	await wait(1.4)
	check(is_instance_valid(lab.boss) and lab.boss.phase == -1 and lab.bar.visible, "Clear corridor → WARNING → the bay intake begins")
	check(lab.boss.world == lab.world and lab.boss.target == lab.ship and lab.boss.background == lab.background, "Boss is wired to the gameplay world, ship and Lab starfield")
	await wait(3.0)
	check(lab.boss.phase == 0 and lab.background.speed_scale < 0.05 and lab.approach.speed_scale < 0.05, "Intake halts both the starfield and the route scroll")
	check(lab.hits == 0, "Phase hand-over never hits the ship")

	# Back to boss-only: the gameplay assembly is gone and the boss is immediate again.
	lab.set_mode(lab.Mode.BOSS_ONLY)
	await process_frame
	await process_frame
	await process_frame
	check(lab.director == null and is_instance_valid(lab.boss) and lab.world.get_node_or_null("EncounterDirector") == null, "Boss-only mode returns to the immediate fight")
	check(lab.hits == 0 and lab.elapsed < 0.2, "Mode switch resets stats")

	lab.return_to_hub()
	await process_frame
	await process_frame
	check(current_scene != null and current_scene.scene_file_path == "res://lab_hub.tscn", "Back button returns to hub")
	if failures.is_empty():
		print("PASS: wall_boss_lab_phase_smoke_test")
		quit(0)
	else:
		for failure in failures: print("FAIL: ", failure)
		quit(1)
