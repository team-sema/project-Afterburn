extends SceneTree

## Shared-clock drone formation: straight diagonal dive, locked offsets.


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var failures: PackedStringArray = []
	var normal_script: Script = load("res://enemies/normal_enemy.gd")
	var diagonal_script: Script = load("res://components/formation_diagonal_move_component.gd")
	var scene: PackedScene = load("res://enemies/normal_enemy.tscn")

	var origin := Vector2(80, -16)
	var start_time := Time.get_ticks_msec() * 0.001
	var offsets: Array[Vector2] = [
		Vector2(-48, 0),
		Vector2(-24, 0),
		Vector2(0, 0),
		Vector2(24, 0),
		Vector2(48, 0),
	]
	var settings := {
		"forward_speed": 72.0,
		"dive_angle_degrees": 50.0,
		"half_span": 48.0,
		"edge_margin": 8.0,
	}

	var members: Array[Node2D] = []
	for offset in offsets:
		var enemy: Node2D = scene.instantiate() as Node2D
		if enemy == null or enemy.get_script() != normal_script:
			failures.append("instantiate NormalEnemy failed")
			break
		enemy.set("augment_registry", EnemyAugmentRegistry.new())
		# Mirrors Spawner configure_before_add: setup may run before add_child.
		enemy.call("setup_formation", origin, offset, start_time, settings)
		root.add_child(enemy)
		var diagonal: Node = enemy.get_node_or_null("FormationDiagonalMoveComponent")
		if diagonal == null or diagonal.get_script() != diagonal_script:
			failures.append("missing FormationDiagonalMoveComponent")
		members.append(enemy)

	await process_frame
	await create_timer(0.4).timeout

	if members.size() == 5:
		var center: Vector2 = members[2].global_position
		for index in members.size():
			var expected_dx: float = offsets[index].x - offsets[2].x
			var actual_dx: float = members[index].global_position.x - center.x
			if absf(actual_dx - expected_dx) > 0.5:
				failures.append(
					"relative lock broken idx=%d expected=%.2f got=%.2f"
					% [index, expected_dx, actual_dx]
				)
			if members[index].global_position.y <= origin.y + 1.0:
				failures.append("member %d did not descend" % index)
			if members[index].global_position.x <= origin.x + offsets[index].x:
				failures.append("member %d did not move right (+X)" % index)

		members[1].queue_free()
		await process_frame
		await create_timer(0.2).timeout
		var survivors := 0
		for member in members:
			if is_instance_valid(member):
				survivors += 1
		if survivors != 4:
			failures.append("expected 4 survivors after one death")

	for member in members:
		if is_instance_valid(member):
			member.queue_free()

	if failures.is_empty():
		print("drone_diagonal_formation_smoke_test: OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("drone_diagonal_formation_smoke_test: FAIL")
		quit(1)
