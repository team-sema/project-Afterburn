extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func bullet(parent: Node2D, appearance: String) -> FoundationBullet:
	var result := load("res://projectiles/foundation_bullet.tscn").instantiate() as FoundationBullet
	result.appearance = load("res://resources/projectiles/%s.tres" % appearance)
	result.behavior = load("res://resources/projectiles/straight_behavior.tres")
	parent.add_child(result)
	result.launch(Vector2.DOWN, 0)
	result.set_physics_process(false)
	return result

func run() -> void:
	var world := Node2D.new()
	root.add_child(world)
	var first := bullet(world, "round")
	var second := bullet(world, "round")
	var rice := bullet(world, "rice")
	var last := bullet(world, "round")
	var laser := load("res://projectiles/curved_laser.tscn").instantiate() as CurvedLaser
	world.add_child(laser)
	laser.launch(Vector2.DOWN, 90)
	laser.set_physics_process(false)
	laser.age = 1.2
	laser._update_body()
	var after_laser := bullet(world, "orb")
	var other := Node2D.new()
	root.add_child(other)
	bullet(other, "round")
	await process_frame
	var renderer = world.get_node("ProjectileBatchRenderer")
	renderer.refresh()
	expect(renderer.projectiles.size() == 6, "registration coalesces deferred creation and isolates worlds")
	expect(renderer._commands.size() == 5, "mixed appearances and lasers retain insertion order")
	expect(renderer._batches[renderer._commands[0]].visible_instance_count == 2, "adjacent identical bullets share a batch")
	first.position = Vector2(60, 80)
	first.rotation = 0.7
	first.show_hitbox = true
	laser.show_hitbox = true
	paused = true
	renderer.refresh()
	expect(renderer._debug_mesh.visible_instance_count == 37, "debug has one circle and all 36 real capsules")
	# The headless dummy renderer does not store instance transforms.
	if DisplayServer.get_name() != "headless":
		var transform: Transform2D = renderer._batches[renderer._commands[0]].get_instance_transform_2d(0)
		expect(transform.origin.is_equal_approx(first.position), "instance placement follows projectile pose")
	second.hide()
	renderer.refresh()
	expect(renderer._batches[renderer._commands[0]].visible_instance_count == 1, "hidden projectiles leave the visible batch")
	for p in [first, second, rice, last, laser, after_laser]:
		p.queue_free()
	renderer.refresh()
	expect(renderer._commands.is_empty() and renderer._debug_mesh.visible_instance_count == 0, "queued deletion clears all rendering immediately while paused")
	expect(other.get_node("ProjectileBatchRenderer").projectiles.size() == 1, "clearing one world leaves the other intact")
	paused = false
	world.queue_free()
	other.queue_free()
	await process_frame
	if failures.is_empty():
		print("projectile batch smoke test: PASS")
	else:
		for failure in failures:
			push_error(failure)
	quit(0 if failures.is_empty() else 1)

func expect(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
