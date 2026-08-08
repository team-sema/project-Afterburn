extends SceneTree

const DRONE_REINFORCEMENT := preload(
	"res://resources/enemy_augments/enemy_drone_formation_reinforcement.tres"
)
const BOMB_FAST_FUSE := preload("res://resources/enemy_augments/enemy_bomb_fast_fuse.tres")

const EXPECTED_WEIGHTS := {
	&"drone_formation": [6.0, 6.0, 6.0],
	&"striker_drone_diamond": [6.0, 6.0, 6.0],
	&"awl_formation": [0.0, 6.0, 6.0],
	&"bomb_single": [0.0, 6.0, 6.0],
	&"caster_single": [0.0, 0.0, 4.0],
	&"tanker_guard_sniper": [0.0, 1.0, 4.0],
	&"x9_drone_down": [0.0, 0.0, 3.0],
	&"x9_caster_drone_orbit": [0.0, 0.0, 1.0],
	&"v7_drone_down": [0.0, 0.0, 2.0],
	&"interceptor_pair": [0.0, 2.0, 2.0],
	&"interceptor_trio": [0.0, 0.0, 1.0],
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
	_expect(pool.entries.size() == 11, "MainEncounterPool contains all eleven live encounters")
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
	_expect(ids.size() == EXPECTED_WEIGHTS.size(), "MainEncounterPool roster matches migration plan")


func _test_threat_rosters_and_weights() -> void:
	_expect_ids(
		pool.get_eligible_entries(1),
		[&"drone_formation", &"striker_drone_diamond"],
		"Threat 1",
	)
	_expect_ids(
		pool.get_eligible_entries(2),
		[
			&"drone_formation",
			&"striker_drone_diamond",
			&"awl_formation",
			&"bomb_single",
			&"tanker_guard_sniper",
			&"interceptor_pair",
		],
		"Threat 2",
	)
	_expect_ids(
		pool.get_eligible_entries(3),
		[
			&"drone_formation",
			&"striker_drone_diamond",
			&"awl_formation",
			&"bomb_single",
			&"caster_single",
			&"tanker_guard_sniper",
			&"x9_drone_down",
			&"x9_caster_drone_orbit",
			&"v7_drone_down",
			&"interceptor_pair",
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
	for entry in pool.entries:
		var expected := EXPECTED_WEIGHTS.get(entry.preset.encounter_id, []) as Array
		for threat_level in range(1, 4):
			_expect(
				is_equal_approx(entry.get_weight(threat_level), float(expected[threat_level - 1])),
				"%s Threat %d weight is %.1f"
				% [entry.preset.encounter_id, threat_level, float(expected[threat_level - 1])],
			)
		_expect(
			is_equal_approx(entry.get_weight(99), float(expected[2])),
			"%s reuses its final weight above Threat 3" % entry.preset.encounter_id,
		)
	_expect(is_equal_approx(pool.get_total_weight(1), 12.0), "Threat 1 total weight is 12")
	_expect(is_equal_approx(pool.get_total_weight(2), 27.0), "Threat 2 total weight is 27")
	_expect(is_equal_approx(pool.get_total_weight(3), 41.0), "Threat 3 total weight is 41")


func _test_deterministic_weighted_selection() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260808
	var counts: Dictionary = {}
	for _index in 36000:
		var preset := pool.choose(3, rng)
		_expect(preset != null, "Threat 3 weighted selection always returns a preset")
		if preset != null:
			counts[preset.encounter_id] = int(counts.get(preset.encounter_id, 0)) + 1
	for encounter_id in EXPECTED_WEIGHTS:
		var expected_count := 36000.0 * float(EXPECTED_WEIGHTS[encounter_id][2]) / 41.0
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
		&"striker_drone_diamond": 4,
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

	var diamond := generator._spawn(_find_preset(&"striker_drone_diamond")) as FormationController
	_expect(diamond != null, "striker_drone_diamond spawns for slot composition check")
	if diamond != null:
		var by_slot: Dictionary = {}
		for member in diamond.get_members():
			var slot := member.get_formation_slot()
			_expect(slot != null, "diamond member has a formation slot")
			if slot != null:
				by_slot[slot.slot_index] = member
		_expect(
			by_slot.has(0)
			and (by_slot[0] as Enemy).scene_file_path == "res://enemies/moving_enemy.tscn",
			"diamond rear slot is a Striker",
		)
		for slot_index in [1, 2, 3]:
			_expect(
				by_slot.has(slot_index)
				and (by_slot[slot_index] as Enemy).scene_file_path
				== "res://enemies/normal_enemy.tscn",
				"diamond front slot %d is a Drone" % slot_index,
			)
		_expect(not by_slot.has(4), "diamond tip slot stays empty")
		_expect(
			diamond.center_movement_controller.sequence.resource_path
			== "res://resources/enemy_movement/sequences/formation_entry_third_patrol.tres",
			"diamond uses one-third entry then patrol",
		)
		diamond.queue_free()


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

	var no_data_entry := EncounterPoolEntry.new()
	no_data_entry.preset = preset
	_expect(not no_data_entry.get_validation_errors().is_empty(), "missing ThreatWeight data is rejected")

	var negative := ThreatWeight.new()
	negative.threat_level = 1
	negative.weight = -1.0
	var negative_entry := EncounterPoolEntry.new()
	negative_entry.preset = preset
	negative_entry.threat_weights = [negative]
	_expect(not negative_entry.get_validation_errors().is_empty(), "negative weight is rejected")

	var zero := ThreatWeight.new()
	zero.threat_level = 1
	zero.weight = 0.0
	var zero_entry := EncounterPoolEntry.new()
	zero_entry.preset = preset
	zero_entry.threat_weights = [zero]
	var zero_pool := EncounterPool.new()
	zero_pool.entries = [zero_entry]
	_expect(not zero_pool.validate(), "all-zero candidate pool is invalid")
	_expect(zero_pool.choose(1) == null, "all-zero candidate pool returns null safely")

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
