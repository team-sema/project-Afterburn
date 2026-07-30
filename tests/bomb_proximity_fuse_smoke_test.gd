extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var failures: PackedStringArray = []
	var scene: PackedScene = load("res://enemies/bomb_enemy.tscn")
	var enemy: Node2D = scene.instantiate() as Node2D
	enemy.set("augment_registry", EnemyAugmentRegistry.new())

	var player := Node2D.new()
	player.add_to_group("player")
	player.position = Vector2(100, 80)
	root.add_child(player)
	root.add_child(enemy)
	enemy.global_position = Vector2(100, 40)

	var stats: StatsComponent = enemy.get_node("StatsComponent") as StatsComponent
	var move: MoveComponent = enemy.get_node("MoveComponent") as MoveComponent
	var fuse: Node = enemy.get_node("BombProximityFuseComponent")
	if stats.health < 100:
		failures.append("bomb should have high health")
	if move.velocity.y > 25.0:
		failures.append("bomb should move slowly")
	if enemy.get_node_or_null("EnemyShootComponent") != null:
		failures.append("bomb should not shoot")

	# Trigger arming
	fuse.set("_armed", false)
	fuse.call("_start_arming")
	if move.velocity != Vector2.ZERO:
		failures.append("armed bomb should stop moving")

	# Skip waits: call detonate path after forcing armed state
	fuse.call("_detonate")
	await process_frame
	if is_instance_valid(enemy) and stats.health > 0:
		failures.append("detonate should zero health")

	player.queue_free()
	if failures.is_empty():
		print("bomb_proximity_fuse_smoke_test: OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("bomb_proximity_fuse_smoke_test: FAIL")
		quit(1)
