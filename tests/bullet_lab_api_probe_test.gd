extends SceneTree

## Bullet Lab EnemyBullets probe: Q circle cancel and E beam cancel remove the
## right bullets, and the hub counts show up in the lab status line.

var failures: PackedStringArray = []


func _initialize() -> void:
	var music := root.get_node_or_null("MusicPlayer") as AudioStreamPlayer
	if music != null:
		music.stop()
		music.stream = null
	_run.call_deferred()


func _run() -> void:
	var lab := (load("res://labs/bullet/bullet_lab.tscn") as PackedScene).instantiate()
	root.add_child(lab)
	for _i in 3:
		await process_frame
	var world: Node2D = lab.world
	var ship: Node2D = lab.target
	var probe = lab.api_probe
	lab.pattern_player.stop()
	lab.call("_clear_world_bullets")
	probe.reset()
	await physics_frame

	var near := _add_bullet(world, ship.position + Vector2(20, 0))
	var above := _add_bullet(world, Vector2(ship.position.x, 60))
	var aside := _add_bullet(world, Vector2(ship.position.x + 90, 60))
	for _i in 2:
		await physics_frame

	_expect(probe.cancel_circle() == 1, "Q circle cancels only the bullet near the ship")
	_expect(near.is_queued_for_deletion(), "the near bullet is removed")
	_expect(probe.sweep_beam() == 1, "E beam cancels the bullet straight above the ship")
	_expect(above.is_queued_for_deletion(), "the bullet above is removed")
	_expect(not aside.is_queued_for_deletion(), "a bullet off the beam survives")
	_expect(
		int(probe.counts.get(&"lab_circle", 0)) == 1 and int(probe.counts.get(&"lab_beam", 0)) == 1,
		"the hub reports each cancel with its reason",
	)
	lab.call("_update_status")
	_expect(String(lab.status_label.text).contains("lab_beam 1"), "the status line shows API cancel counts")

	lab.queue_free()
	await process_frame
	if failures.is_empty():
		print("bullet_lab_api_probe_test: PASS")
		quit()
		return
	for failure in failures:
		push_error("bullet_lab_api_probe_test: %s" % failure)
	quit(1)


func _add_bullet(world: Node2D, position: Vector2) -> Node2D:
	var bullet := (load("res://projectiles/base_enemy_projectile.tscn") as PackedScene).instantiate() as Node2D
	world.add_child(bullet)
	bullet.position = position
	var move := bullet.get_node_or_null("MoveComponent") as MoveComponent
	if move != null:
		move.velocity = Vector2.ZERO
		move.set_process(false)
	return bullet


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
