extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func expect(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func sample_scene(path: String) -> Array:
	var world := Node2D.new()
	world.add_to_group("gameplay_world")
	root.add_child(world)
	var registry := EnemyAugmentRegistry.new()
	world.add_child(registry)
	var enemy := load(path).instantiate() as Enemy
	enemy.augment_registry = registry
	enemy.position = Vector2(320, 100)
	var attack = enemy.get_node("EnemyShootComponent")
	attack.shot_random_seed = 1701
	world.add_child(enemy)
	enemy.movement_controller.stop()
	attack.set_process(false)
	attack.apply_fire_volume_boost(2, 18)
	attack.apply_action_rate_multiplier(2)
	attack.phase = attack.Phase.DASH
	attack.use_spine = false
	attack.dash_direction = Vector2.DOWN
	attack._process(0.17)
	await process_frame
	var bullets := get_nodes_in_group("enemy_projectiles")
	expect(bullets.size() == 12, "two boosted fountain bursts at action-rate minimum interval")
	var result: Array = []
	for bullet in bullets:
		expect(bullet is CurvedLaser, "fountain uses trail lasers")
		if not bullet is CurvedLaser:
			continue
		var velocity: Vector2 = bullet.behavior_state.velocity_at(0.0)
		expect(is_equal_approx(bullet.lifetime, 5.0), "fountain laser lifetime")
		expect(is_equal_approx(bullet.trail_duration, 0.5), "fountain laser keeps a short body")
		expect(velocity.y < 0.0, "fountain lasers rise from the tail")
		expect(velocity.length() >= 150 and velocity.length() <= 180, "random speed bounded")
		result.append([velocity, bullet._origin])
		bullet.set_process(false)
		bullet.set_physics_process(false)
	if not bullets.is_empty() and bullets[0] is CurvedLaser:
		bullets[0]._physics_process(5.01)
		expect(bullets[0].is_queued_for_deletion(), "fountain laser expires")
	world.queue_free()
	await process_frame
	return result

func run() -> void:
	var baseline := await sample_scene("res://enemies/elite_awl.tscn")
	var modern := await sample_scene("res://enemies/elite_awl.tscn")
	expect(baseline.size() == modern.size(), "same shot count")
	for i in mini(baseline.size(), modern.size()):
		expect(baseline[i][0].is_equal_approx(modern[i][0]), "same seeded velocity %d" % i)
		expect(baseline[i][1].is_equal_approx(modern[i][1]), "same substep emission position %d" % i)
	var lab := preload("res://labs/enemy_attack/enemy_attack_lab.tscn").instantiate()
	root.add_child(lab)
	await process_frame
	expect(lab.world != null and lab.mode == 0, "lab starts with Awl")
	lab.restart(1)
	await process_frame
	await process_frame
	expect(lab.mode == 1 and get_nodes_in_group("gameplay_world").size() == 1, "lab switches without stale worlds")
	for index in [2, 3, 4]:
		lab.restart(index)
		await process_frame
		await process_frame
		expect(lab.mode == index and get_nodes_in_group("gameplay_world").size() == 1, "lab switches to %s" % lab.TITLES[index])
	lab.queue_free()
	await process_frame
	for failure in failures: push_error(failure)
	print("elite awl barrage smoke test: ", "PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
