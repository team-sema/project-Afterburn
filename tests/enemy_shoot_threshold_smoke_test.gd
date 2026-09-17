extends SceneTree

var failures := PackedStringArray()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var gameplay_world := Node2D.new()
	gameplay_world.add_to_group("gameplay_world")
	root.add_child(gameplay_world)
	var augment_registry := EnemyAugmentRegistry.new()
	_expect(
		is_equal_approx(augment_registry.shot_threshold_y_ratio, 0.7),
		"Enemy registry allows fire in the upper 70 percent of the playfield",
	)

	var projectile_source := Node2D.new()
	var projectile_scene := PackedScene.new()
	_expect(projectile_scene.pack(projectile_source) == OK, "test projectile scene packs")
	projectile_source.free()

	var normal := _instantiate_enemy("res://enemies/normal_enemy.tscn", augment_registry)
	var shoot := normal.get_node("EnemyShootComponent") as EnemyShootComponent
	shoot.pattern_script = null # Exercise the legacy threshold adapter separately.
	_expect(shoot.apply_shot_threshold, "Drone enables the shot threshold")
	shoot.projectile_scene = projectile_scene
	shoot.inject_target_direction = false
	shoot.initial_delay = 20.0
	gameplay_world.add_child(normal)
	await process_frame

	var visible_rect := normal.get_viewport_rect()
	var threshold_y: float = (
		visible_rect.position.y
		+ visible_rect.size.y * augment_registry.shot_threshold_y_ratio
	)
	normal.global_position = Vector2(visible_rect.get_center().x, threshold_y - 1.0)
	shoot.fire()
	_expect(shoot.get_volleys_fired() == 1, "Drone fires above the threshold")

	normal.global_position.y = threshold_y + 1.0
	shoot.fire()
	_expect(shoot.get_volleys_fired() == 1, "Drone does not fire below the threshold")

	augment_registry.shot_threshold_y_ratio = 0.8
	shoot.fire()
	_expect(
		shoot.get_volleys_fired() == 2,
		"Changing the shared threshold immediately affects an active Drone",
	)

	normal.global_position.y = visible_rect.position.y + visible_rect.size.y * 0.9
	shoot.apply_shot_threshold = false
	shoot.fire()
	_expect(shoot.get_volleys_fired() == 3, "Threshold opt-out preserves special attacks")

	var moving := _instantiate_enemy("res://enemies/moving_enemy.tscn", augment_registry)
	_expect(
		(moving.get_node("EnemyShootComponent") as EnemyShootComponent).apply_shot_threshold,
		"Striker enables the shot threshold",
	)
	moving.free()

	var interceptor := _instantiate_enemy("res://enemies/interceptor_enemy.tscn", augment_registry)
	_expect(
		(interceptor.get_node("EnemyShootComponent") as EnemyShootComponent).apply_shot_threshold,
		"Interceptor inherits the Drone shot threshold",
	)
	interceptor.free()

	var elite := _instantiate_enemy("res://enemies/elite_fighter.tscn", augment_registry)
	_expect(
		not (elite.get_node("EnemyShootComponent") as EnemyShootComponent).apply_shot_threshold,
		"Elite forward fire opts out of the ordinary-enemy threshold",
	)
	# EliteBarrageShootComponent was removed from the scene. Check every
	# remaining standard shooter rather than dereferencing that old node.
	for child in elite.get_children():
		if child is EnemyShootComponent:
			_expect(not child.apply_shot_threshold, "Elite shooters opt out of the ordinary-enemy threshold")
	elite.free()

	gameplay_world.queue_free()
	await process_frame
	augment_registry.free()

	if failures.is_empty():
		print("enemy shoot threshold smoke test: PASS")
		quit(0)
		return
	for failure in failures:
		push_error("enemy shoot threshold smoke test: %s" % failure)
	quit(1)


func _instantiate_enemy(path: String, augment_registry: EnemyAugmentRegistry) -> Enemy:
	var enemy := (load(path) as PackedScene).instantiate() as Enemy
	enemy.augment_registry = augment_registry
	return enemy


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
