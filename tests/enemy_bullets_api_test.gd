extends SceneTree

## EnemyBullets: world-scoped listing, centre-radius and physics-shape queries,
## and cancel with a reason reported on the world's hub.

var failures: PackedStringArray = []
var _cancelled: Array[Dictionary] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var world := Node2D.new()
	world.add_to_group("gameplay_world")
	root.add_child(world)
	var elsewhere := Node2D.new()
	root.add_child(elsewhere)

	var near := _add_legacy(world, Vector2(100, 100))
	var far := _add_legacy(world, Vector2(200, 100))
	var outsider := _add_legacy(elsewhere, Vector2(100, 100))
	var laser := (load("res://projectiles/curved_laser.tscn") as PackedScene).instantiate() as CurvedLaser
	world.add_child(laser)
	laser.global_position = Vector2(60, 20)
	laser.launch(Vector2.DOWN, 90)
	for _i in 50:
		await physics_frame
	laser.set_physics_process(false)
	await physics_frame
	await physics_frame

	var all := EnemyBullets.get_all(world)
	_expect(all.size() == 3 and all.has(near) and all.has(far) and all.has(laser), "get_all lists bullets under the world only")
	_expect(not all.has(outsider), "bullets under another parent are excluded")

	var circle := EnemyBullets.query_circle(world, Vector2(100, 100), 20)
	_expect(circle.size() == 1 and circle[0] == near, "query_circle finds bullets by centre distance")

	var probe := CircleShape2D.new()
	probe.radius = 3
	_expect(
		_only(EnemyBullets.query_shape(world, probe, Transform2D(0, Vector2(100, 100))), near),
		"query_shape finds a bullet hitbox on the enemy_projectile layer",
	)
	var body := laser.body_at(laser.age)
	var body_mid := body[body.size() / 2]
	_expect(laser.global_position.distance_to(body_mid) > 20.0, "probe point sits on the laser body, away from its head")
	_expect(
		_only(EnemyBullets.query_shape(world, probe, Transform2D(0, body_mid)), laser),
		"query_shape finds a laser by its body segments",
	)
	_expect(
		EnemyBullets.query_circle(world, body_mid, 3).is_empty(),
		"query_circle still measures a laser from its head",
	)
	_expect(
		EnemyBullets.query_shape(world, probe, Transform2D(0, Vector2(150, 250))).is_empty(),
		"query_shape returns nothing over empty space",
	)

	EnemyBullets.get_hub(world).bullet_cancelled.connect(
		func(position: Vector2, reason: StringName, bullet: Node2D) -> void:
			_cancelled.append({"position": position, "reason": reason, "valid": is_instance_valid(bullet)})
	)
	_expect(EnemyBullets.cancel(world, near, &"test"), "cancel removes a live bullet")
	_expect(near.is_queued_for_deletion(), "a cancelled bullet is queued for deletion")
	_expect(
		_cancelled.size() == 1
		and _cancelled[0]["reason"] == &"test"
		and (_cancelled[0]["position"] as Vector2).is_equal_approx(Vector2(100, 100))
		and _cancelled[0]["valid"],
		"the hub reports position and reason while the bullet is still valid",
	)
	_expect(not EnemyBullets.cancel(world, near, &"test"), "cancelling twice is a no-op")
	_expect(not EnemyBullets.cancel(world, outsider, &"test"), "cancel ignores bullets outside the world")
	_expect(
		EnemyBullets.cancel_all(world, EnemyBullets.get_all(world), &"sweep") == 2,
		"cancel_all removes the remaining bullets",
	)
	_expect(_cancelled.size() == 3, "every cancel is reported once")

	world.queue_free()
	elsewhere.queue_free()
	await process_frame
	if failures.is_empty():
		print("enemy_bullets_api_test: PASS")
		quit()
		return
	for failure in failures:
		push_error("enemy_bullets_api_test: %s" % failure)
	quit(1)


func _add_legacy(parent: Node2D, position: Vector2) -> Node2D:
	var bullet := (load("res://projectiles/base_enemy_projectile.tscn") as PackedScene).instantiate() as Node2D
	parent.add_child(bullet)
	bullet.global_position = position
	# Hold still so positions stay known while the laser grows.
	var move := bullet.get_node_or_null("MoveComponent") as MoveComponent
	if move != null:
		move.velocity = Vector2.ZERO
		move.set_process(false)
	return bullet


func _only(hits: Array[Node2D], expected: Node2D) -> bool:
	return hits.size() == 1 and hits[0] == expected


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
