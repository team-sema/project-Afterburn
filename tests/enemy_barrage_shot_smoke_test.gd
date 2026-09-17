extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func expect(value: bool, message: String) -> void:
	if not value: failures.append(message)

func run() -> void:
	var world := Node2D.new()
	world.position = Vector2(17, 13)
	world.add_to_group("gameplay_world")
	root.add_child(world)
	var target := Node2D.new()
	world.add_child(target)
	target.global_position = Vector2(240, 220)
	var registry := EnemyAugmentRegistry.new()
	var enemy := load("res://enemies/normal_enemy.tscn").instantiate() as Enemy
	enemy.augment_registry = registry
	enemy.position = Vector2(90, 40)
	var shoot := enemy.get_node("EnemyShootComponent") as EnemyShootComponent
	shoot.pattern_script = null # This test covers the legacy-timer/new-shot bridge.
	shoot.barrage_shot = load("res://resources/projectiles/round_straight_shot.tres")
	world.add_child(enemy)
	shoot.fire_timer.stop()
	shoot.targeting_component.change_target(target)
	enemy.set_process(false)
	var origin := enemy.global_position
	var direction := origin.direction_to(target.global_position)
	expect(shoot.barrage_shot != null and shoot.fire_interval == 4.5 and shoot.projectile_speed == 105 and shoot.initial_delay == 1.5, "Drone recipe and existing timing")
	shoot.fire()
	await process_frame
	var bullets := get_nodes_in_group("enemy_projectiles")
	expect(bullets.size() == 1 and bullets[0] is FoundationBullet, "Drone fires new body")
	if bullets.size() == 1 and bullets[0] is FoundationBullet:
		var bullet := bullets[0] as FoundationBullet
		expect(bullet._origin.is_equal_approx(origin) and bullet._direction.is_equal_approx(direction), "world origin and aim preserved under translated parent")
		expect(bullet.get_threat_velocity().is_equal_approx(direction * 105), "speed preserved")
		expect(bullet.use_batched_rendering, "new body uses batched renderer")
	shoot.apply_action_rate_multiplier(2)
	expect(shoot.fire_interval == 2.25 and shoot.projectile_speed == 105, "modifier changes cadence only")
	enemy.global_position.y = enemy.get_viewport_rect().size.y * 0.9
	shoot.fire()
	expect(shoot.get_volleys_fired() == 1, "threshold still gates new recipe")
	enemy.global_position = origin
	shoot.shot_count = 3
	shoot.spread_degrees = 40
	shoot.fire()
	await process_frame
	expect(get_nodes_in_group("enemy_projectiles").size() == 4, "fan count preserved")
	shoot.fire()
	enemy.queue_free()
	await process_frame
	expect(get_nodes_in_group("enemy_projectiles").size() == 4, "queued emitter does not spawn more; existing bullets survive")
	var interceptor := load("res://enemies/interceptor_enemy.tscn").instantiate() as Enemy
	expect(interceptor.get_node("EnemyShootComponent").barrage_shot == null, "Interceptor retains legacy recipe")
	interceptor.free()
	world.queue_free()
	await process_frame
	registry.free()
	for failure in failures: push_error(failure)
	print("enemy barrage shot smoke test: ", "PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
