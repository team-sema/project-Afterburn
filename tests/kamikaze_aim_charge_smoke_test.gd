extends SceneTree

## Smoke: kamikaze phases descend → aim → charge at locked point.


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var failures: PackedStringArray = []
	var scene: PackedScene = load("res://enemies/kamikaze_enemy.tscn")
	var enemy: Node2D = scene.instantiate() as Node2D
	enemy.set("augment_registry", EnemyAugmentRegistry.new())

	var player := Node2D.new()
	player.name = "FakePlayer"
	player.add_to_group("player")
	player.position = Vector2(120, 200)
	root.add_child(player)
	root.add_child(enemy)
	enemy.global_position = Vector2(80, 20)

	var move: MoveComponent = enemy.get_node("MoveComponent") as MoveComponent
	var charge: Node = enemy.get_node("KamikazeAimChargeComponent")
	var shoot: Node = enemy.get_node_or_null("EnemyShootComponent")
	if shoot != null:
		failures.append("kamikaze must remove EnemyShootComponent")

	await process_frame
	if move.velocity.y <= 0.0 or absf(move.velocity.x) > 0.01:
		failures.append("descend phase should move straight down")

	# Fast-forward descend
	charge.set("_phase_elapsed", 2.0)
	charge.call("_process", 0.0)
	await process_frame
	if move.velocity != Vector2.ZERO:
		failures.append("aim phase should be stationary")

	player.global_position = Vector2(160, 220)
	charge.set("_phase_elapsed", 2.0)
	charge.call("_process", 0.0)
	await process_frame

	var expected_dir := (Vector2(160, 220) - enemy.global_position).normalized()
	var actual_dir := move.velocity.normalized()
	if absf(move.velocity.length() - 280.0) > 1.0:
		failures.append("charge speed should be 280")
	if actual_dir.dot(expected_dir) < 0.99:
		failures.append("charge should lock aim point from charge start")

	# Move player after lock — direction must not retarget.
	player.global_position = Vector2(20, 50)
	await process_frame
	if move.velocity.normalized().dot(expected_dir) < 0.99:
		failures.append("charge retargeted after lock")

	enemy.queue_free()
	player.queue_free()
	if failures.is_empty():
		print("kamikaze_aim_charge_smoke_test: OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("kamikaze_aim_charge_smoke_test: FAIL")
		quit(1)
