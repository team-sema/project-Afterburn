extends SceneTree
## Pooled bullet rendering: one EnemyBulletPool per projectile parent groups
## bullets by appearance, keeps instances packed as bullets die, and the laser
## renderer still draws ribbons beside it.

var failures: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func bullet(parent: Node2D, appearance: String) -> FoundationBullet:
	var result := load("res://projectiles/foundation_bullet.tscn").instantiate() as FoundationBullet
	result.appearance = load("res://resources/projectiles/%s.tres" % appearance)
	result.behavior = load("res://resources/projectiles/straight_behavior.tres")
	parent.add_child(result)
	result.launch(Vector2.DOWN, 0)
	result.simulating = false
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
	var pool := world.get_node("EnemyBulletPool") as EnemyBulletPool
	expect(pool != null and pool.get_active_count() == 5, "pool is created once per parent and isolates worlds")
	var groups: Dictionary = pool.get_render_groups()
	var round_key: String = first._render_key
	expect(groups.size() == 3, "bullets group by appearance")
	expect(groups[round_key].members.size() == 3 and groups[round_key].multimesh.visible_instance_count == 3, "same-appearance bullets share one batch")
	var renderer = world.get_node("ProjectileBatchRenderer")
	renderer.refresh()
	expect(renderer.projectiles.size() == 1 and renderer._commands.size() == 1, "the laser renderer only holds lasers now")
	first.global_position = Vector2(60, 80)
	first.global_rotation = 0.7
	first.show_hitbox = true
	laser.show_hitbox = true
	paused = true
	first.step(0.0)
	expect(pool._debug_count == 1, "debug outlines count the flagged bullet")
	# The headless dummy renderer does not store instance transforms.
	if DisplayServer.get_name() != "headless":
		var transform: Transform2D = groups[round_key].multimesh.get_instance_transform_2d(first._slot)
		expect(transform.origin.is_equal_approx(first.global_position), "instance placement follows projectile pose")
	second.free()
	expect(groups[round_key].members.size() == 2 and groups[round_key].multimesh.visible_instance_count == 2, "a freed bullet leaves the batch packed")
	expect(last._slot == 1 or first._slot == 1, "the last member fills the freed slot")
	for p in [first, rice, last, laser, after_laser]:
		p.queue_free()
	await process_frame
	expect(pool.get_active_count() == 0 and groups[round_key].members.is_empty(), "queued deletion clears the pool while paused")
	renderer.refresh()
	expect(renderer._commands.is_empty(), "queued deletion clears the laser renderer while paused")
	expect((other.get_node("EnemyBulletPool") as EnemyBulletPool).get_active_count() == 1, "clearing one world leaves the other intact")
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
