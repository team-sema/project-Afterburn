extends SceneTree

## The carrier is the main-game BOSS gate (docs/design/bosses/carrier.md 「본 게임 연결」):
## the gate spawns BossCarrierEnemy, the carrier fights in playfield coordinates,
## part damage mirrors into the shell's StatsComponent and the top HP bar, HP 0
## starts the sinking without pausing, and the finished sinking runs the usual
## boss settlement (bullet-cancel pause → Threat +1 → enemy offer).

var failures := PackedStringArray()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var sequence := load("res://resources/encounter_sequences/main_encounter_sequence.tres") as EncounterSequence
	var boss_step: EncounterSequenceStep = null
	for step in sequence.shared_steps:
		if step.token == &"d":
			boss_step = step
	_expect(boss_step != null and boss_step.kind == EncounterSequenceStep.Kind.BOSS, "token d is BOSS")
	_expect(
		boss_step != null and boss_step.boss_preset != null and boss_step.boss_preset.encounter_id == &"boss_carrier",
		"token d spawns the carrier",
	)

	var gameplay := (load("res://gameplay.tscn") as PackedScene).instantiate()
	root.add_child(gameplay)
	var progression := gameplay.get_node("AugmentProgressionController") as AugmentProgressionController
	var offer_controller := gameplay.get_node("AugmentOfferController") as AugmentOfferController
	var generator := gameplay.get_node("EnemyGenerator")
	var elite_controller := gameplay.get_node("ThreatEliteController") as ThreatEliteController
	progression.set_process(false)
	generator.spawn_timer.stop()
	# Deterministic HP numbers: the test ship must not auto-fire at the carrier.
	var ship := gameplay.get_node("Ship") as Node2D
	ship.get_node("PlayerWeaponLoadout").process_mode = Node.PROCESS_MODE_DISABLED
	var viewport_centre_x := ship.get_viewport_rect().get_center().x
	var preset := load("res://resources/encounters/presets/boss_carrier.tres") as EncounterPreset
	_expect(preset != null and preset.validate(), "boss_carrier preset validates")

	elite_controller.set_next_gate(preset, true)
	progression.request_elite_milestone()
	await process_frame
	await process_frame
	var shell := elite_controller.active_elite as BossCarrierEnemy
	_expect(shell != null and is_instance_valid(shell), "boss gate spawns the carrier shell")
	if shell == null:
		gameplay.queue_free()
		_finish()
		return
	_expect(shell.is_boss and shell.is_in_group("bosses") and not shell.is_elite, "shell is a boss, not an elite")
	_expect(generator.normal_spawns_paused, "boss gate pauses normal encounters")
	var carrier := shell.carrier
	_expect(carrier != null and is_instance_valid(carrier) and carrier.is_inside_tree(), "shell spawns the carrier")
	_expect(carrier.top_level and carrier.get_parent() == shell, "carrier is a top-level child of the shell")
	_expect(carrier.world == gameplay and carrier.target != null and carrier.target.is_in_group("player"), "carrier fights in the gameplay world against the player")
	_expect(is_equal_approx(carrier.global_position.x, 150.0) and carrier.global_position.y < 0.0, "carrier starts above the playfield centre line")
	_expect(shell.stats_component.health == carrier.maximum and carrier.maximum == 1920, "shell HP mirrors the carrier's 1920 required HP")
	_expect(not shell.hurtbox_component.monitorable and not shell.hurtbox_component.monitoring, "shell has no hurtbox of its own")
	var bar := shell.get_node("EnemyHealthBar") as EnemyHealthBarComponent
	_expect(bar.pinned_to_top and bar.visible and is_equal_approx(bar.modulate.a, 1.0), "boss HP bar is pinned to the top and visible")
	_expect(is_equal_approx(bar.global_position.x, viewport_centre_x) and bar.global_position.y < 20.0, "pinned bar sits at the top centre of the viewport (%s)" % bar.global_position)
	_expect(bar.bar_size.x > 200.0, "boss bar spans the playfield")

	# Let the hull finish its 2.2s approach so the aft section is live.
	await create_timer(2.5).timeout
	_expect(not carrier.transitioning and carrier.phase == 0, "carrier arrives at the aft section")

	# Part damage flows into the shell HP and the bar.
	var turret: Node2D = carrier.parts[0]
	_expect(turret.active, "aft turrets are active after arrival")
	turret.take_damage(10)
	await process_frame
	_expect(carrier.health == 1910, "turret damage reduces the carrier HP (%d)" % carrier.health)
	_expect(shell.stats_component.health == 1910, "shell HP follows the carrier (%d)" % shell.stats_component.health)
	_expect(bar.get_health_ratio() < 1.0, "top bar drains with the carrier")

	# Destroy the last section: HP 0 starts the sinking but does not pause yet.
	carrier.phase = 2
	carrier.advance_section()
	await process_frame
	_expect(carrier.defeated, "clearing the bridge section defeats the carrier")
	_expect(not paused and shell.stats_component.health >= 1, "sinking plays out without the reward pause")
	_expect(is_instance_valid(shell) and shell.global_position.y > 0.0 and shell.global_position.y < 360.0, "shell parks on screen for its death effect (%s)" % shell.global_position)

	# Fast-forward the 8.2s sinking: the shell dies and the gate settles.
	var defeated := [false]
	elite_controller.elite_defeated.connect(func(_threat: int) -> void: defeated[0] = true)
	carrier._physics_process(8.3)
	await process_frame
	_expect(paused or defeated[0], "finished sinking starts the bullet-cancel settlement")
	if not defeated[0]:
		await elite_controller.elite_defeated
	_expect(progression.get_threat_level() == 2, "boss defeat advances Threat")
	_expect(progression.current_experience >= 3, "boss guaranteed XP is vacuumed before the offer (%d)" % progression.current_experience)
	_expect(offer_controller.is_offer_active and offer_controller.active_offer_type == AugmentOfferController.OfferType.ENEMY, "boss defeat opens the enemy augment offer")
	await process_frame
	_expect(not is_instance_valid(shell) or shell.is_queued_for_deletion(), "shell frees itself after the settlement")
	offer_controller.call("_complete_offer", AugmentOfferController.OfferType.ENEMY)
	_expect(not progression.elite_gate_active and not generator.normal_spawns_paused, "offer completion closes the boss gate")
	paused = false

	gameplay.queue_free()
	await process_frame
	_finish()


func _finish() -> void:
	if failures.is_empty():
		print("boss_carrier_gate_test: PASS")
		quit(0)
		return
	for failure in failures:
		push_error("boss_carrier_gate_test: %s" % failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
