extends SceneTree

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
		var before_count := get_nodes_in_group("enemies").size()
		generator._spawn(spawn_set)
		var spawned_count := get_nodes_in_group("enemies").size() - before_count
		_expect(
			spawned_count == expected_spawn_counts[spawn_set.spawn_id],
			"%s spawns %d enemies" % [spawn_set.spawn_id, expected_spawn_counts[spawn_set.spawn_id]],
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


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
