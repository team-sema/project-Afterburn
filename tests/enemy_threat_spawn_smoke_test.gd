extends SceneTree

const DRONE_REINFORCEMENT := preload(
	"res://resources/enemy_augments/enemy_drone_formation_reinforcement.tres"
)
const BOMB_FAST_FUSE := preload("res://resources/enemy_augments/enemy_bomb_fast_fuse.tres")

## difficulty + min_threat for live MainEncounterPool entries.
const EXPECTED_ROSTER := {
	&"drone_formation": {"difficulty": 5.0, "min_threat": 1},
	&"striker_drone_diamond_5": {"difficulty": 7.0, "min_threat": 1},
	&"bomb_single": {"difficulty": 6.0, "min_threat": 1},
	&"awl_formation": {"difficulty": 12.0, "min_threat": 1},
	&"striker_drone_diamond_13": {"difficulty": 15.0, "min_threat": 2},
	&"tanker_guard_sniper": {"difficulty": 10.0, "min_threat": 2},
	&"interceptor_pair": {"difficulty": 12.0, "min_threat": 2},
	&"caster_single": {"difficulty": 7.0, "min_threat": 3},
	&"x9_drone_down": {"difficulty": 9.0, "min_threat": 3},
	&"x9_caster_drone_orbit": {"difficulty": 15.0, "min_threat": 3},
	&"v7_drone_down": {"difficulty": 7.0, "min_threat": 3},
	&"interceptor_trio": {"difficulty": 18.0, "min_threat": 3},
}

var failures := PackedStringArray()
var gameplay: Node
var generator: Node
var progression: AugmentProgressionController
var augment_registry: EnemyAugmentRegistry
var pool: EncounterPool


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var gameplay_scene := load("res://gameplay.tscn") as PackedScene
	gameplay = gameplay_scene.instantiate()
	root.add_child(gameplay)
	progression = gameplay.get_node("AugmentProgressionController") as AugmentProgressionController
	generator = gameplay.get_node("EnemyGenerator")
	augment_registry = gameplay.get_node("EnemyAugmentRegistry") as EnemyAugmentRegistry
	pool = generator.encounter_pool as EncounterPool
	progression.set_process(false)
	generator.spawn_timer.stop()

	_test_generator_and_pool_shape()
	_test_threat_rosters_and_weights()
	_test_deterministic_weighted_selection()
	await _test_single_encounters()
	_test_formation_encounters()
	await _test_spawn_scoped_augments()
	_test_threat_progression()
	_test_invalid_weight_safety()

	for enemy in get_nodes_in_group("enemies"):
		enemy.queue_free()
	gameplay.queue_free()
	await process_frame
	if failures.is_empty():
		print("enemy threat spawn smoke test: PASS")
		quit(0)
		return
	for failure in failures:
		push_error("enemy threat spawn smoke test: %s" % failure)
	quit(1)


func _test_generator_and_pool_shape() -> void:
	_expect(progression.get_threat_level() == 1, "run starts at Threat 1")
	_expect(generator.current_threat_level == 1, "generator reads the initial Threat level")
	_expect(pool != null and pool.validate(), "EnemyGenerator references one valid MainEncounterPool")
	_expect(pool.entries.size() == 12, "MainEncounterPool contains all twelve live encounters")
	_expect(not _has_property(generator, &"spawn_sets"), "EnemyGenerator no longer exposes spawn_sets")
	_expect(
		not _has_property(generator.enemy_spawner, &"enemy_scene"),
		"EnemySpawner has no live direct-enemy scene selection",
	)
	var ids: Dictionary = {}
	for entry in pool.entries:
		_expect(entry != null and entry.preset != null, "every MainEncounterPool entry has a preset")
		if entry == null or entry.preset == null:
			continue
		_expect(not ids.has(entry.preset.encounter_id), "live encounter ids are unique")
		ids[entry.preset.encounter_id] = true
	_expect(ids.size() == EXPECTED_ROSTER.size(), "MainEncounterPool roster matches difficulty plan")


func _expected_weight(difficulty: float, min_threat: int, threat_level: int) -> float:
	if threat_level < min_threat:
		return 0.0
	return EncounterPoolEntry.WEIGHT_SCALE / difficulty


func _test_threat_rosters_and_weights() -> void:
	_expect_ids(
		pool.get_eligible_entries(1),
		[&"drone_formation", &"striker_drone_diamond_5", &"bomb_single", &"awl_formation"],
		"Threat 1",
	)
	_expect_ids(
		pool.get_eligible_entries(2),
		[
			&"drone_formation",
			&"striker_drone_diamond_5",
			&"bomb_single",
			&"awl_formation",
			&"striker_drone_diamond_13",
			&"tanker_guard_sniper",
			&"interceptor_pair",
		],
		"Threat 2",
	)
	_expect_ids(
		pool.get_eligible_entries(3),
		[
			&"drone_formation",
			&"striker_drone_diamond_5",
			&"bomb_single",
			&"awl_formation",
			&"striker_drone_diamond_13",
			&"tanker_guard_sniper",
			&"interceptor_pair",
			&"caster_single",
			&"x9_drone_down",
			&"x9_caster_drone_orbit",
			&"v7_drone_down",
			&"interceptor_trio",
		],
		"Threat 3",
	)
	var threat_three_ids: Array[StringName] = []
	for entry in pool.get_eligible_entries(3):
		threat_three_ids.append(entry.preset.encounter_id)
	_expect_ids(
		pool.get_eligible_entries(99),
		threat_three_ids,
		"Threat above authored maximum",
	)
	var total_by_threat := {1: 0.0, 2: 0.0, 3: 0.0}
	for entry in pool.entries:
		var expected := EXPECTED_ROSTER.get(entry.preset.encounter_id, {}) as Dictionary
		_expect(not expected.is_empty(), "%s is in the difficulty roster" % entry.preset.encounter_id)
		if expected.is_empty():
			continue
		_expect(
			is_equal_approx(entry.preset.difficulty, float(expected["difficulty"])),
			"%s difficulty is authored" % entry.preset.encounter_id,
		)
		_expect(
			entry.min_threat == int(expected["min_threat"]),
			"%s min_threat is authored" % entry.preset.encounter_id,
		)
		for threat_level in range(1, 4):
			var want := _expected_weight(
				float(expected["difficulty"]),
				int(expected["min_threat"]),
				threat_level,
			)
			_expect(
				is_equal_approx(entry.get_weight(threat_level), want),
				"%s Threat %d weight is %.3f"
				% [entry.preset.encounter_id, threat_level, want],
			)
			total_by_threat[threat_level] = float(total_by_threat[threat_level]) + want
		_expect(
			is_equal_approx(
				entry.get_weight(99),
				_expected_weight(float(expected["difficulty"]), int(expected["min_threat"]), 99),
			),
			"%s keeps inverse-difficulty weight above Threat 3" % entry.preset.encounter_id,
		)
	_expect(is_equal_approx(pool.get_total_weight(1), float(total_by_threat[1])), "Threat 1 total matches roster")
	_expect(is_equal_approx(pool.get_total_weight(2), float(total_by_threat[2])), "Threat 2 total matches roster")
	_expect(is_equal_approx(pool.get_total_weight(3), float(total_by_threat[3])), "Threat 3 total matches roster")


func _test_deterministic_weighted_selection() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260808
	var counts: Dictionary = {}
	var total_weight := pool.get_total_weight(3)
	for _index in 36000:
		var preset := pool.choose(3, rng)
		_expect(preset != null, "Threat 3 weighted selection always returns a preset")
		if preset != null:
			counts[preset.encounter_id] = int(counts.get(preset.encounter_id, 0)) + 1
	for entry in pool.entries:
		var encounter_id := entry.preset.encounter_id
		var expected_count := 36000.0 * entry.get_weight(3) / total_weight
		var actual_count := float(counts.get(encounter_id, 0))
		var tolerance := maxf(80.0, expected_count * 0.08)
		_expect(
			absf(actual_count - expected_count) <= tolerance,
			"%s deterministic sample reflects weight (actual %d, expected %.0f)"
			% [encounter_id, int(actual_count), expected_count],
		)


func _test_single_encounters() -> void:
	await _test_single_encounter(
		&"bomb_single",
		"res://enemies/bomb_enemy.tscn",
		"res://resources/enemy_movement/sequences/bomb_straight_down.tres",
	)
	await _test_single_encounter(
		&"caster_single",
		"res://enemies/shooting_enemy.tscn",
		"res://resources/enemy_movement/sequences/caster_entry_patrol.tres",
	)


func _test_single_encounter(
	encounter_id: StringName,
	enemy_scene_path: String,
	movement_path: String,
) -> void:
	var preset := _find_preset(encounter_id)
	var controller := generator._spawn(preset) as FormationController
	_expect(controller != null, "%s creates a FormationController" % encounter_id)
	if controller == null:
		return
	var members := controller.get_members()
	_expect(members.size() == 1, "%s spawns exactly one member" % encounter_id)
	if members.is_empty():
		controller.queue_free()
		await process_frame
		return
	var enemy := members[0]
	var viewport_rect := enemy.get_viewport_rect()
	_expect(enemy.scene_file_path == enemy_scene_path, "%s uses its original Enemy scene" % encounter_id)
	_expect(enemy.is_formation_member(), "%s enters the common formation lifecycle" % encounter_id)
	_expect(
		is_equal_approx(enemy.global_position.y, viewport_rect.position.y - 16.0),
		"%s preserves the legacy top -16 spawn Y" % encounter_id,
	)
	_expect(
		enemy.global_position.x >= viewport_rect.position.x + 8.0
		and enemy.global_position.x <= viewport_rect.end.x - 8.0,
		"%s preserves the legacy random-X edge margin" % encounter_id,
	)
	_expect(enemy.get_node_or_null("HurtboxComponent") != null, "%s keeps its hurtbox" % encounter_id)
	_expect(enemy.get_node_or_null("HitboxComponent") != null, "%s keeps its hitbox" % encounter_id)
	_expect(
		enemy.get_node_or_null("VisibleOnScreenNotifier2D") is FreeOffscreenComponent,
		"%s keeps offscreen cleanup" % encounter_id,
	)
	await process_frame
	await process_frame
	_expect(not is_instance_valid(controller), "%s single formation cleans up after release" % encounter_id)
	_expect(is_instance_valid(enemy), "%s Enemy survives formation release" % encounter_id)
	if is_instance_valid(enemy):
		_expect(not enemy.is_formation_member(), "%s continues in individual mode" % encounter_id)
		_expect(enemy.movement_controller.is_running(), "%s starts its original movement" % encounter_id)
		_expect(
			enemy.movement_controller.sequence.resource_path == movement_path,
			"%s retains the original MovementSequence" % encounter_id,
		)
		enemy.queue_free()
		await process_frame


func _test_formation_encounters() -> void:
	var expected_counts := {
		&"drone_formation": 5,
		&"striker_drone_diamond_5": 5,
		&"striker_drone_diamond_13": 13,
		&"awl_formation": 3,
		&"x9_drone_down": 9,
		&"x9_caster_drone_orbit": 9,
		&"v7_drone_down": 7,
		&"tanker_guard_sniper": 2,
		&"interceptor_pair": 2,
		&"interceptor_trio": 3,
	}
	for encounter_id in expected_counts:
		var controller := generator._spawn(_find_preset(encounter_id)) as FormationController
		_expect(controller != null, "%s spawns through EnemySpawner" % encounter_id)
		if controller != null:
			_expect(
				controller.get_members().size() == int(expected_counts[encounter_id]),
				"%s spawns %d members" % [encounter_id, int(expected_counts[encounter_id])],
			)
			controller.queue_free()

	var diamond := generator._spawn(_find_preset(&"striker_drone_diamond_5")) as FormationController
	_expect(diamond != null, "striker_drone_diamond_5 spawns for slot composition check")
	if diamond != null:
		var by_slot: Dictionary = {}
		for member in diamond.get_members():
			var slot := member.get_formation_slot()
			_expect(slot != null, "diamond_5 member has a formation slot")
			if slot != null:
				by_slot[slot.slot_index] = member
		_expect(
			by_slot.has(0)
			and (by_slot[0] as Enemy).scene_file_path == "res://enemies/moving_enemy.tscn",
			"diamond_5 rear slot is a Striker",
		)
		for slot_index in [1, 2, 3, 4]:
			_expect(
				by_slot.has(slot_index)
				and (by_slot[slot_index] as Enemy).scene_file_path
				== "res://enemies/normal_enemy.tscn",
				"diamond_5 slot %d is a Drone" % slot_index,
			)
		_expect(
			diamond.center_movement_controller.sequence.resource_path
			== "res://resources/enemy_movement/sequences/formation_entry_third.tres",
			"diamond_5 uses one-third entry then scatter release",
		)
		var diamond_preset := _find_preset(&"striker_drone_diamond_5")
		_expect(
			diamond_preset.formation_break_condition
			== EncounterPreset.FormationBreakCondition.SEQUENCE_FINISHED,
			"diamond_5 breaks after entry sequence",
		)
		_expect(
			diamond_preset.individual_movement_sequence.resource_path
			== "res://resources/enemy_movement/sequences/individual_scatter_2_5.tres",
			"diamond_5 drones scatter at 2.5x entry speed",
		)
		_expect(
			diamond_preset.members[0].individual_movement_override.resource_path
			== "res://resources/enemy_movement/sequences/individual_striker_charge_2_5.tres",
			"diamond_5 Striker charges the player at 2.5x entry speed",
		)
		diamond.queue_free()

	var diamond13 := generator._spawn(_find_preset(&"striker_drone_diamond_13")) as FormationController
	_expect(diamond13 != null, "striker_drone_diamond_13 spawns for slot composition check")
	if diamond13 != null:
		var by_slot13: Dictionary = {}
		for member in diamond13.get_members():
			var slot := member.get_formation_slot()
			_expect(slot != null, "diamond_13 member has a formation slot")
			if slot != null:
				by_slot13[slot.slot_index] = member
		_expect(
			by_slot13.has(0)
			and (by_slot13[0] as Enemy).scene_file_path == "res://enemies/moving_enemy.tscn",
			"diamond_13 tip slot is a Striker",
		)
		for slot_index in range(1, 13):
			_expect(
				by_slot13.has(slot_index)
				and (by_slot13[slot_index] as Enemy).scene_file_path
				== "res://enemies/normal_enemy.tscn",
				"diamond_13 slot %d is a Drone" % slot_index,
			)
		var diamond13_preset := _find_preset(&"striker_drone_diamond_13")
		_expect(
			diamond13_preset.formation_break_condition
			== EncounterPreset.FormationBreakCondition.SEQUENCE_FINISHED,
			"diamond_13 breaks after entry sequence",
		)
		_expect(
			diamond13_preset.individual_movement_sequence.resource_path
			== "res://resources/enemy_movement/sequences/individual_scatter_2_5.tres",
			"diamond_13 drones use the same 2.5x scatter",
		)
		_expect(
			diamond13_preset.members[0].individual_movement_override.resource_path
			== "res://resources/enemy_movement/sequences/individual_striker_charge_2_5.tres",
			"diamond_13 Striker charges the player on scatter",
		)
		diamond13.queue_free()


func _test_spawn_scoped_augments() -> void:
	augment_registry.add_augment(DRONE_REINFORCEMENT)
	var drone_controller := generator._spawn(_find_preset(&"drone_formation")) as FormationController
	_expect(drone_controller.get_members().size() == 6, "drone reinforcement expands 5 members to 6")
	drone_controller.queue_free()

	augment_registry.add_augment(BOMB_FAST_FUSE)
	var bomb_controller := generator._spawn(_find_preset(&"bomb_single")) as FormationController
	var bomb := bomb_controller.get_members()[0] as Enemy
	await process_frame
	_expect(is_instance_valid(bomb), "Bomb single Encounter survives release")
	if is_instance_valid(bomb):
		_expect(bomb.spawn_id == &"bomb_single", "Bomb receives its EncounterPreset id")
		var bomb_fuse := bomb.get_node("BombProximityFuseComponent")
		var actual_arm_duration := float(bomb_fuse.get("arm_duration"))
		_expect(
			is_equal_approx(actual_arm_duration, 2.0 / 1.5),
			"Bomb fast fuse remains scoped to bomb_single",
		)
		bomb.queue_free()
	await process_frame


func _test_threat_progression() -> void:
	progression._process(60.0)
	_expect(generator.current_threat_level == 2, "generator follows Threat 2")
	progression._process(60.0)
	_expect(generator.current_threat_level == 3, "generator follows Threat 3")


func _test_invalid_weight_safety() -> void:
	var preset := _find_preset(&"drone_formation")
	var null_entry := EncounterPoolEntry.new()
	_expect(not null_entry.get_validation_errors().is_empty(), "null EncounterPreset is rejected")

	var bad_difficulty := preset.duplicate() as EncounterPreset
	bad_difficulty.difficulty = 0.0
	var bad_entry := EncounterPoolEntry.new()
	bad_entry.preset = bad_difficulty
	_expect(not bad_entry.get_validation_errors().is_empty(), "non-positive difficulty is rejected")

	var locked_entry := EncounterPoolEntry.new()
	locked_entry.preset = preset
	locked_entry.min_threat = 3
	_expect(is_equal_approx(locked_entry.get_weight(1), 0.0), "below min_threat weight is zero")
	_expect(
		is_equal_approx(locked_entry.get_weight(3), EncounterPoolEntry.WEIGHT_SCALE / preset.difficulty),
		"at min_threat weight is inverse difficulty",
	)

	var zero_pool := EncounterPool.new()
	zero_pool.entries = [locked_entry]
	_expect(not zero_pool.validate(), "pool with no Threat 1 candidates is invalid")
	_expect(zero_pool.choose(1) == null, "empty Threat 1 candidate pool returns null safely")

	var duplicate_pool := EncounterPool.new()
	duplicate_pool.entries = [pool.entries[0], pool.entries[0]]
	_expect(not duplicate_pool.validate(), "duplicate EncounterPreset entries are rejected")


func _find_preset(encounter_id: StringName) -> EncounterPreset:
	for entry in pool.entries:
		if entry.preset.encounter_id == encounter_id:
			return entry.preset
	return null


func _expect_ids(
	entries: Array[EncounterPoolEntry],
	expected_ids: Array,
	label: String,
) -> void:
	var actual: Array[StringName] = []
	for entry in entries:
		actual.append(entry.preset.encounter_id)
	var expected: Array[StringName] = []
	for encounter_id in expected_ids:
		expected.append(StringName(encounter_id))
	actual.sort()
	expected.sort()
	_expect(actual == expected, "%s eligible encounters are %s, expected %s" % [label, actual, expected])


func _has_property(object: Object, property_name: StringName) -> bool:
	for property in object.get_property_list():
		if StringName(property["name"]) == property_name:
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
