extends SceneTree

var failures := PackedStringArray()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var world := Node2D.new()
	root.add_child(world)

	var normal_enemy := _make_enemy(world)
	var normal_bar := normal_enemy.get_node("EnemyHealthBar") as Node2D
	_expect(not normal_bar.visible, "normal enemy health bar starts hidden")
	normal_enemy.stats_component.health -= 1
	await process_frame
	_expect(not normal_bar.visible, "normal enemy damage does not reveal a health bar")

	var elite := _make_enemy(world, true)
	var elite_bar := elite.get_node("EnemyHealthBar") as Node2D
	_expect(not elite_bar.visible, "elite health bar starts hidden before the first hit")
	_expect(is_equal_approx(float(elite_bar.get("visible_duration")), 1.5), "elite health bar holds for 1.5 seconds")
	elite.stats_component.health -= 1
	await process_frame
	_expect(elite_bar.visible, "elite health bar appears when the elite takes damage")
	_expect(is_equal_approx(elite_bar.modulate.a, 1.0), "newly revealed elite health bar is opaque")
	_expect(is_equal_approx(float(elite_bar.call("get_health_ratio")), 2.0 / 3.0), "elite health bar reflects remaining health")

	await create_timer(1.4).timeout
	_expect(elite_bar.visible, "elite health bar remains visible before the timeout")
	elite.stats_component.health -= 1
	await process_frame
	_expect(is_equal_approx(elite_bar.modulate.a, 1.0), "another hit resets the fade timer")
	_expect(is_equal_approx(float(elite_bar.call("get_health_ratio")), 1.0 / 3.0), "repeated hits refresh the health ratio")

	await create_timer(1.4).timeout
	_expect(elite_bar.visible, "reset timer keeps the elite health bar visible")
	await create_timer(0.4).timeout
	_expect(not elite_bar.visible, "elite health bar fades out after 1.5 seconds")

	var boss := _make_enemy(world, false, true)
	var boss_bar := boss.get_node("EnemyHealthBar") as Node2D
	boss.stats_component.health -= 1
	await process_frame
	_expect(boss_bar.visible, "boss damage also reveals the elite-or-higher health bar")

	world.queue_free()
	await process_frame
	if failures.is_empty():
		print("enemy health bar smoke test: PASS")
		quit(0)
		return
	for failure in failures:
		push_error("enemy health bar smoke test: %s" % failure)
	quit(1)


func _make_enemy(parent: Node, is_elite := false, is_boss := false) -> Enemy:
	var enemy := (load("res://enemies/enemy.tscn") as PackedScene).instantiate() as Enemy
	enemy.augment_registry = EnemyAugmentRegistry.new()
	enemy.is_elite = is_elite
	enemy.is_boss = is_boss
	parent.add_child(enemy)
	return enemy


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
