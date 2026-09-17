extends SceneTree
var failures: Array[String] = []
func _initialize() -> void:
	run.call_deferred()
func expect(value: bool, message: String) -> void:
	if not value: failures.append(message)
func run() -> void:
	var world := Node2D.new()
	world.position = Vector2(30, 15)
	root.add_child(world)
	var config := preload("res://resources/projectiles/diamond_trail.tres").duplicate() as BulletTrailEffect
	config.speed_min = 0
	config.speed_max = 0
	config.lifetime = 1
	var a := BulletTrailEmitter.new(world, config, Vector2.ZERO)
	var b := BulletTrailEmitter.new(world, config, Vector2(0, 10))
	expect(a.manager == b.manager, "deferred registration creates one manager")
	var manager := a.manager
	await process_frame
	manager.set_physics_process(false)
	manager.set_process(false)
	a.advance(Vector2(10, 0), 0.1)
	b.advance(Vector2(4, 10), 0.04)
	b.advance(Vector2(10, 10), 0.06)
	expect(manager.particles.size() == 10, "distance sampling independent of update partition")
	for i in 5:
		expect(manager.particles[i].position.x == manager.particles[i + 5].position.x, "sampled positions match")
	a.advance(Vector2(10, 0), 1)
	expect(manager.particles.size() == 10, "stationary emitter creates no particles")
	config.size = 99
	expect(a.effect.size != 99, "effect settings are snapshotted")
	manager.refresh()
	expect(manager._batches.size() == 1, "same texture shares a single batch")
	var saved: Vector2 = manager.particles[0].position
	world.position += Vector2(20, 30)
	manager.refresh()
	expect(manager.particles[0].position == saved, "particles remain in world coordinates")
	paused = true
	manager.advance(2)
	expect(manager.particles.size() == 10, "pause freezes particle lifetime")
	paused = false
	manager.advance(2)
	expect(manager.particles.is_empty(), "particles expire independently")
	manager.clear()
	var long_effect := a.effect.duplicate() as BulletTrailEffect
	long_effect.lifetime = 5
	for tick in 17:
		manager.advance(0)
		for i in 300: manager.emit_particle(long_effect, Vector2.ZERO, Vector2.DOWN)
		if tick == 0: expect(manager.particles.size() == 256, "per-tick emission budget")
	expect(manager.particles.size() == 4096 and manager.dropped > 0, "global particle cap and tick emission budget")
	manager.clear()
	var capped := BulletTrailEmitter.new(world, a.effect, Vector2.ZERO)
	capped.advance(Vector2(512, 0), 0.1)
	expect(manager.particles.size() == 64, "per-emitter update budget")
	manager.advance(0)
	capped.advance(Vector2(514, 0), 0.01)
	expect(manager.particles.size() == 65, "dropped emission is not replayed")
	manager.clear()
	a.advance(Vector2(2000, 0), 0.1)
	expect(manager.particles.is_empty(), "teleport does not connect distant positions")
	# Actual body integration and survival after projectile deletion.
	var shot := BarrageShot.new()
	shot.appearance = preload("res://resources/projectiles/needle.tres")
	shot.behavior = BulletBehavior.new()
	# Explicit fixture: the shared preset's lifetime is a tuning value, not a test contract.
	var short_tail := preload("res://resources/projectiles/diamond_trail.tres").duplicate() as BulletTrailEffect
	short_tail.lifetime = 0.22
	shot.trail_effect = short_tail
	var bullet := shot.spawn(world, Vector2(100, 80), Vector2.DOWN, 100) as FoundationBullet
	bullet.set_physics_process(false)
	bullet._physics_process(0.1)
	expect(manager.particles.size() == 5, "body submits swept positions")
	bullet.queue_free()
	await process_frame
	expect(manager.particles.size() == 5, "tail survives emitter deletion")
	manager.advance(0.3)
	expect(manager.particles.is_empty(), "orphaned tail naturally drains")
	shot.kind = BarrageShot.Kind.TRAIL_LASER
	var laser := shot.spawn(world, Vector2(100, 80), Vector2.DOWN, 100) as CurvedLaser
	laser.set_physics_process(false)
	laser._physics_process(0.1)
	expect(manager.particles.size() == 5, "laser head supports optional effect")
	laser.queue_free()
	var other := Node2D.new()
	root.add_child(other)
	var other_manager := ProjectileTrailManager.for_world(other)
	expect(other_manager != manager, "worlds isolate their particle pools")
	await process_frame
	other.queue_free()
	world.queue_free()
	await process_frame
	expect(not is_instance_valid(manager) and not is_instance_valid(other_manager), "world removal cleans managers")
	if "--capture" in OS.get_cmdline_user_args():
		var lab := preload("res://projectiles/textured_bullet_lab.tscn").instantiate()
		root.add_child(lab)
		await create_timer(1.5).timeout
		lab.toggle_pause()
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/particle_trail_lab.png")
		lab.queue_free()
		paused = false
		await process_frame
	for failure in failures: push_error(failure)
	print("projectile trail smoke test: ", "PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
