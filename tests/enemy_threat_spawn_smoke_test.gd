extends SceneTree

const DRONE_REINFORCEMENT := preload(
	"res://resources/enemy_augments/enemy_drone_formation_reinforcement.tres"
)
const BOMB_FAST_FUSE := preload("res://resources/enemy_augments/enemy_bomb_fast_fuse.tres")

var failures: PackedStringArray = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var gameplay_scene := load("res://gameplay.tscn") as PackedScene
	var gameplay := gameplay_scene.instantiate()
	root.add_child(gameplay)

	var progression := gameplay.get_node("AugmentProgressionController") as AugmentProgressionController
	var generator := gameplay.get_node("EnemyGenerator")
	progression.set_process(false)
	generator.spawn_timer.stop()

	_expect(progression.get_threat_level() == 1, "run starts at Threat 1")
	_expect(generator.current_threat_level == 1, "generator reads the initial Threat level")
	_expect(
		not _has_property(generator, &"drone_forward_speed"),
		"generator has no Drone-specific tuning fields",
	)
	_expect(
		not _has_property(generator, &"awl_descend_duration"),
		"generator has no Awl-specific tuning fields",
	)
	_expect_ids(generator.get_eligible_spawn_sets(1), [&"drone_formation", &"striker"])

	for _index in 20:
		var selected := generator.pick_spawn_set(1) as EnemySpawnSet
		_expect(selected != null, "Threat 1 always has a spawn candidate")
		if selected != null:
			_expect(selected.minimum_threat_level <= 1, "Threat 1 never selects a locked spawn set")

	var expected_spawn_counts := {
		&"drone_formation": 5,
		&"striker": 1,
		&"awl_formation": 3,
		&"bomb": 1,
		&"caster": 1,
	}
	for spawn_set in generator.spawn_sets:
		_expect(spawn_set.spawn_pattern != null, "%s has a spawn pattern" % spawn_set.spawn_id)
		var before_count := get_nodes_in_group("enemies").size()
		generator._spawn(spawn_set)
		var spawned_count := get_nodes_in_group("enemies").size() - before_count
		_expect(
			spawned_count == expected_spawn_counts[spawn_set.spawn_id],
			"%s spawns %d enemies" % [spawn_set.spawn_id, expected_spawn_counts[spawn_set.spawn_id]],
		)

	var augment_registry := gameplay.get_node("EnemyAugmentRegistry") as EnemyAugmentRegistry
	augment_registry.add_augment(DRONE_REINFORCEMENT)
	var drone_spawn_set := _find_spawn_set(generator.spawn_sets, &"drone_formation")
	var before_reinforced_count := get_nodes_in_group("enemies").size()
	generator._spawn(drone_spawn_set)
	var reinforced_count := get_nodes_in_group("enemies").size() - before_reinforced_count
	_expect(reinforced_count == 6, "drone reinforcement increases formation from 5 to 6")

	augment_registry.add_augment(BOMB_FAST_FUSE)
	var bomb_spawn_set := _find_spawn_set(generator.spawn_sets, &"bomb")
	var existing_enemy_ids := _get_enemy_ids()
	generator._spawn(bomb_spawn_set)
	var augmented_bomb := _find_new_enemy(existing_enemy_ids)
	await process_frame
	_expect(is_instance_valid(augmented_bomb), "bomb augment test spawns a Bomb enemy")
	if is_instance_valid(augmented_bomb):
		_expect(augmented_bomb.spawn_id == &"bomb", "generator injects the Bomb spawn id")
		var bomb_fuse := augmented_bomb.get_node("BombProximityFuseComponent")
		var actual_arm_duration := float(bomb_fuse.get("arm_duration"))
		_expect(
			is_equal_approx(actual_arm_duration, 2.0 / 1.5),
			"bomb fast fuse reduces arming from 2.0s to about 1.33s (got %.3f)"
			% actual_arm_duration,
		)

	progression._process(60.0)
	_expect(generator.current_threat_level == 2, "generator follows Threat 2")
	_expect_ids(
		generator.get_eligible_spawn_sets(2),
		[&"drone_formation", &"striker", &"awl_formation", &"bomb"],
	)

	progression._process(60.0)
	_expect(generator.current_threat_level == 3, "generator follows Threat 3")
	_expect_ids(
		generator.get_eligible_spawn_sets(3),
		[&"drone_formation", &"striker", &"awl_formation", &"bomb", &"caster"],
	)

	paused = false
	for enemy in get_nodes_in_group("enemies"):
		enemy.queue_free()
	gameplay.queue_free()
	await process_frame
	if failures.is_empty():
		print("enemy threat spawn smoke test: PASS")
		quit()
		return
	for failure in failures:
		push_error("enemy threat spawn smoke test: %s" % failure)
	quit(1)


func _expect_ids(spawn_sets: Array[EnemySpawnSet], expected: Array[StringName]) -> void:
	var actual: Array[StringName] = []
	for spawn_set in spawn_sets:
		actual.append(spawn_set.spawn_id)
	actual.sort()
	expected.sort()
	_expect(actual == expected, "eligible spawn sets are %s, expected %s" % [actual, expected])


func _find_spawn_set(spawn_sets: Array[EnemySpawnSet], spawn_id: StringName) -> EnemySpawnSet:
	for spawn_set in spawn_sets:
		if spawn_set.spawn_id == spawn_id:
			return spawn_set
	return null


func _get_enemy_ids() -> Dictionary:
	var ids := {}
	for enemy in get_nodes_in_group("enemies"):
		ids[enemy.get_instance_id()] = true
	return ids


func _find_new_enemy(existing_ids: Dictionary) -> Enemy:
	for enemy in get_nodes_in_group("enemies"):
		if not existing_ids.has(enemy.get_instance_id()):
			return enemy as Enemy
	return null


func _has_property(object: Object, property_name: StringName) -> bool:
	for property in object.get_property_list():
		if StringName(property["name"]) == property_name:
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
