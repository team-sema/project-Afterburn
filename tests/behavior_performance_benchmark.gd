extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var lab = load("res://projectiles/bullet_behavior_lab.tscn").instantiate()
	root.add_child(lab)
	if "--live" in OS.get_cmdline_user_args():
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = 0
		for debug in [false, true]:
			lab.hitbox_button.button_pressed = debug
			lab.restart()
			var intervals: Array[float] = []
			var start := Time.get_ticks_usec()
			var previous := start
			while Time.get_ticks_usec() - start < 10000000:
				await process_frame
				var now := Time.get_ticks_usec()
				if now - start > 1000000: intervals.append((now - previous) / 1000.0)
				previous = now
			intervals.sort()
			print("LIVE_FRAME debug=", debug, " median_ms=", intervals[intervals.size() / 2], " p95_ms=", intervals[int(intervals.size() * 0.95)], " max_ms=", intervals[-1])
		lab.queue_free()
		await process_frame
		quit()
		return
	lab.pattern_player.stop()
	await process_frame
	var bullets := get_nodes_in_group("enemy_projectiles")
	for bullet in bullets:
		bullet.set_physics_process(false)
	var renderer = bullets[0].get_parent().get_node("ProjectileBatchRenderer")
	renderer.set_process(false)
	var meters := [lab.safety_meter]
	var result := {}
	for debug in [false, true]:
		lab._toggle_hitboxes(debug)
		var pose := 0
		var batch := 0
		var safety := 0
		for frame in 120:
			var start := Time.get_ticks_usec()
			for bullet in bullets:
				bullet.age = 2.0 + frame / 120.0
				if bullet is CurvedLaser: bullet._update_body()
				else: bullet._update_pose()
			var updated := Time.get_ticks_usec()
			renderer.refresh()
			var rendered := Time.get_ticks_usec()
			for meter in meters: meter.measure()
			var sampled := Time.get_ticks_usec()
			if frame >= 20:
				pose += updated - start
				batch += rendered - updated
				safety += sampled - rendered
		result[str(debug)] = {"pose_ms": pose / 100000.0, "batch_ms": batch / 100000.0, "safety_sample_ms": safety / 100000.0}
	print("BEHAVIOR_BENCHMARK ", JSON.stringify(result), " meters=", meters.size())
	lab.queue_free()
	await process_frame
	quit()
