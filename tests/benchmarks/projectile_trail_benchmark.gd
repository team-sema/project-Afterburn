extends SceneTree
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var world := Node2D.new()
	root.add_child(world)
	var manager := ProjectileTrailManager.for_world(world)
	await process_frame
	manager.set_physics_process(false)
	manager.set_process(false)
	var effect := preload("res://resources/projectiles/diamond_trail.tres").duplicate() as BulletTrailEffect
	effect.lifetime = 5
	for count in [256, 1024, 4096]:
		manager.clear()
		for i in count:
			if i % 256 == 0: manager.advance(0)
			manager.emit_particle(effect, Vector2(20 + i % 100 * 6, 20 + i / 100 * 6), Vector2.DOWN)
		var samples: Array[float] = []
		for frame in 90:
			var start := Time.get_ticks_usec()
			manager.advance(1.0 / 120.0)
			manager.refresh()
			if frame >= 30: samples.append((Time.get_ticks_usec() - start) / 1000.0)
			await process_frame
		samples.sort()
		print("TRAIL_BENCHMARK particles=", count, " cpu_median_ms=", samples[30], " cpu_p95_ms=", samples[57], " draw_calls=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	manager.clear()
	effect.lifetime = 0.22
	var streaming: Array[float] = []
	for frame in 150:
		var start := Time.get_ticks_usec()
		manager.advance(1.0 / 60.0)
		for i in 80: manager.emit_particle(effect, Vector2(i * 7, 100 + frame % 100), Vector2.UP)
		manager.refresh()
		if frame >= 50: streaming.append((Time.get_ticks_usec() - start) / 1000.0)
		await process_frame
	streaming.sort()
	print("TRAIL_STREAM particles=", manager.particles.size(), " new_per_tick=80 cpu_median_ms=", streaming[50], " cpu_p95_ms=", streaming[95], " draw_calls=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	world.queue_free()
	await process_frame
	quit()
