extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var failures: PackedStringArray = []
	var scene: PackedScene = load("res://enemies/shooting_enemy/shooting_enemy.tscn")
	var enemy: Node2D = scene.instantiate() as Node2D
	enemy.set("augment_registry", EnemyAugmentRegistry.new())
	root.add_child(enemy)
	enemy.global_position = Vector2(100, -16)

	if enemy.get_node_or_null("EnemyShootComponent") != null:
		failures.append("caster should remove EnemyShootComponent")
	if enemy.get_node_or_null("StateMachine") != null:
		failures.append("caster should remove StateMachine")
	var stats: StatsComponent = enemy.get_node("StatsComponent") as StatsComponent
	if stats.health < 100:
		failures.append("caster health should be raised")

	var movement := enemy.get_node_or_null("MovementController") as MovementController
	var barrage: Node = enemy.get_node_or_null("RadialBarrageShootComponent")
	if movement == null or barrage == null:
		failures.append("missing movement/barrage components")
	if enemy.get_node_or_null("CasterHoverComponent") != null:
		failures.append("caster should not retain CasterHoverComponent")

	# Reach hover band (72px at 48u/s ≈ 1.5s; allow headless slack).
	for _i in 240:
		await process_frame
		if movement != null and movement.get_current_step_index() == 1:
			break
	if enemy.global_position.y < 50.0:
		failures.append(
			"caster failed to reach hover band (y=%.1f)" % enemy.global_position.y
		)
	if movement != null and movement.get_current_step_index() != 1:
		failures.append("caster should enter its horizontal patrol step")
	var y_at_hover := enemy.global_position.y
	var x_at_hover := enemy.global_position.x
	await create_timer(0.35).timeout
	if absf(enemy.global_position.y - y_at_hover) > 3.0:
		failures.append("caster should stay at hover_y (no further descent)")
	if absf(enemy.global_position.x - x_at_hover) < 2.0:
		failures.append("caster should patrol horizontally after entering")

	enemy.queue_free()
	if failures.is_empty():
		print("caster_top_orb_barrage_smoke_test: OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("caster_top_orb_barrage_smoke_test: FAIL")
		quit(1)
