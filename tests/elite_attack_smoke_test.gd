extends SceneTree

var failures := PackedStringArray()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var world := Node2D.new()
	root.add_child(world)
	current_scene = world
	var player := Node2D.new()
	player.add_to_group("player")
	player.position = Vector2(160, 260)
	world.add_child(player)
	var registry := EnemyAugmentRegistry.new()
	world.add_child(registry)
	var elite := (load("res://enemies/elite_fighter.tscn") as PackedScene).instantiate() as Enemy
	elite.augment_registry = registry
	elite.position = Vector2(160, -30)
	world.add_child(elite)
	await process_frame
	var attack = elite.get_node("EnemyShootComponent")
	attack.set_process(false)
	attack._process(0.1)
	_expect(attack.get_volleys_fired() == 0, "entry does not shoot")
	elite.position.y = 72
	elite.movement_controller.update_movement(0.1)
	attack._process(0.01)
	_expect(attack.phase == attack.Phase.FAN, "patrol begins the fan cycle")
	for i in 4:
		attack._process(0.5)
	await process_frame
	_expect(attack.get_volleys_fired() == 4, "normal fan fires four volleys")
	_expect(get_nodes_in_group("enemy_projectiles").size() == 20, "normal fan creates twenty bullets")
	_expect(attack.phase == attack.Phase.AIM, "fan transitions into aiming")
	_expect(elite.get_node("EliteAimCone").visible, "aim telegraph is visible")
	_expect(not elite.movement_controller.is_processing(), "aim stops patrol")
	var locked: Vector2 = attack._locked_direction
	player.position.x += 120
	attack._process(0.9)
	_expect(attack.get_volleys_fired() == 4, "telegraph does not fire early")
	attack._process(0.11)
	_expect(attack._locked_direction == locked, "aim stays locked after target moves")
	_expect(not elite.get_node("EliteAimCone").visible, "firing hides telegraph")
	for i in 9:
		attack._process(0.14)
	await process_frame
	var bullets := get_nodes_in_group("enemy_projectiles")
	_expect(bullets.size() == 50, "full-health burst adds thirty bullets")
	for i in 3:
		var move := bullets[bullets.size() - 3 + i].get_node("MoveComponent") as MoveComponent
		var expected := locked.rotated(deg_to_rad(-6.0 + 6.0 * i))
		_expect(move.velocity.normalized().is_equal_approx(expected), "three bullet lanes match the warning")
	_expect(attack.phase == attack.Phase.RECOVERY, "ten shots enter recovery")
	elite.stats_component.health = 100
	var volleys: int = attack.get_volleys_fired()
	attack._process(0.8)
	_expect(attack.get_volleys_fired() == volleys, "recovery does not fire")
	attack._process(0.81)
	attack.apply_action_rate_multiplier(10.0)
	for i in 4:
		attack._process(0.5)
	await process_frame
	_expect(get_nodes_in_group("enemy_projectiles").size() == 70, "low-health fan still adds twenty bullets")
	_expect(attack.phase == attack.Phase.AIM, "low-health fan still fires four volleys")
	_expect(is_equal_approx(attack._remaining, 1.0), "action rate preserves full warning")
	attack.set_process(true)
	paused = true
	var remaining: float = attack._remaining
	await process_frame
	await process_frame
	_expect(is_equal_approx(attack._remaining, remaining), "pause freezes pattern")
	paused = false
	attack.set_process(false)
	attack._process(1.01)
	for i in 9:
		attack._process(0.09)
	await process_frame
	_expect(get_nodes_in_group("enemy_projectiles").size() == 100, "low-health burst still adds thirty bullets")
	_expect(attack.phase == attack.Phase.RECOVERY, "low-health burst still fires ten volleys")
	_expect(is_equal_approx(attack._remaining, 1.0), "action rate preserves minimum recovery")
	attack.shot_count += 2
	attack._shoot(locked, 3, 12.0, 195.0)
	await process_frame
	_expect(get_nodes_in_group("enemy_projectiles").size() == 105, "volume augment adds two pellets to the three-lane baseline")
	_expect(attack.shot_count == 3, "pattern preserves augment pellets")
	world.queue_free()
	await process_frame
	if failures.is_empty():
		print("elite attack smoke test: PASS")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
