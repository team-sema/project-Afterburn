extends SceneTree

var failures: PackedStringArray = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var gameplay_world := Node2D.new()
	gameplay_world.name = "GameplayWorld"
	gameplay_world.add_to_group("gameplay_world")
	root.add_child(gameplay_world)

	var projectile_source := Node2D.new()
	projectile_source.name = "AutonomousProjectile"
	var autonomous_scene := PackedScene.new()
	_expect(
		autonomous_scene.pack(projectile_source) == OK,
		"autonomous projectile scene can be packed",
	)
	projectile_source.free()

	var enemy_scene := load("res://enemies/enemy.tscn") as PackedScene
	var enemy := enemy_scene.instantiate() as Enemy
	var augment_registry := EnemyAugmentRegistry.new()
	enemy.augment_registry = augment_registry
	enemy.global_position = Vector2(42.0, 24.0)

	var shoot := enemy.get_node("EnemyShootComponent") as EnemyShootComponent
	shoot.projectile_scene = autonomous_scene
	shoot.inject_target_direction = false
	shoot.initial_delay = 0.0
	shoot.fire_interval = 20.0
	shoot.burst_count = 1
	shoot.shot_count = 1
	gameplay_world.add_child(enemy)

	await process_frame
	var projectile := gameplay_world.get_node_or_null("AutonomousProjectile") as Node2D
	_expect(projectile != null, "untargeted shooting spawns a scene without launch()")
	if projectile != null:
		_expect(
			projectile.global_position.is_equal_approx(enemy.global_position),
			"autonomous projectile scene spawns at the enemy position",
		)

	gameplay_world.queue_free()
	await process_frame
	augment_registry.free()

	if failures.is_empty():
		print("enemy shoot autonomous scene smoke test: PASS")
		quit()
		return
	for failure in failures:
		push_error("enemy shoot autonomous scene smoke test: %s" % failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
