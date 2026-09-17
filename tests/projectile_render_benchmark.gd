extends SceneTree
## Rendered comparison: run with --rendering-method gl_compatibility.
## Frame intervals include presentation/waits; they are not GPU timings.

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("This benchmark requires a rendered window; omit --headless.")
		quit(1)
		return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var results := []
	for kind in ["laser", "round", "rice"]:
		for batched in [false, true]:
			var world := Node2D.new()
			root.add_child(world)
			var bullets: Array[Node2D] = []
			var count := 12 if kind == "laser" else 1000
			for i in count:
				var bullet: Node2D
				if kind == "laser":
					bullet = load("res://projectiles/curved_laser.tscn").instantiate()
					bullet.position = Vector2(320, 110)
				else:
					bullet = load("res://projectiles/foundation_bullet.tscn").instantiate()
					bullet.appearance = load("res://resources/projectiles/%s.tres" % kind)
					bullet.behavior = load("res://resources/projectiles/straight_behavior.tres")
					bullet.position = Vector2(20 + (i % 50) * 12, 25 + (i / 50) * 15)
				bullet.use_batched_rendering = batched
				world.add_child(bullet)
				bullet.launch(Vector2.DOWN.rotated(TAU * i / count), 90 if kind == "laser" else 0)
				bullet.set_physics_process(false)
				bullets.append(bullet)
			await process_frame
			var renderer := world.get_node_or_null("ProjectileBatchRenderer")
			if renderer != null:
				renderer.set_process(false)
			for debug in [false, true]:
				for bullet in bullets:
					bullet.show_hitbox = debug
				var intervals := []
				var draws := []
				var updates := []
				var rendering := []
				var previous := Time.get_ticks_usec()
				for frame in 90:
					var start := Time.get_ticks_usec()
					for bullet in bullets:
						if kind == "laser":
							bullet.age = 1.1 + float(frame % 60) / 120.0
							bullet._update_body()
						else:
							bullet._update_pose()
					var updated := Time.get_ticks_usec()
					if renderer != null:
						renderer.refresh()
					var rendered := Time.get_ticks_usec()
					await process_frame
					var now := Time.get_ticks_usec()
					if frame >= 30:
						intervals.append((now - previous) / 1000.0)
						draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
						updates.append((updated - start) / 1000.0)
						rendering.append((rendered - updated) / 1000.0)
					previous = now
				intervals.sort()
				draws.sort()
				updates.sort()
				rendering.sort()
				var result := {"kind": kind, "count": count, "batched": batched, "debug": debug, "draw_calls": draws[30], "frame_ms": intervals[30], "frame_p95_ms": intervals[57], "pose_ms": updates[30], "batch_upload_ms": rendering[30]}
				results.append(result)
				print(JSON.stringify(result))
				if "--capture" in OS.get_cmdline_user_args():
					for bullet in bullets:
						if kind == "laser":
							bullet.age = 1.55
							bullet._update_body()
					if renderer != null:
						renderer.refresh()
					await RenderingServer.frame_post_draw
					root.get_texture().get_image().save_png("res://artifacts/render_%s_%s_%s.png" % [kind, batched, debug])
			world.queue_free()
			await process_frame
	FileAccess.open("res://artifacts/projectile_render_benchmark.json", FileAccess.WRITE).store_string(JSON.stringify(results, "\t"))
	print("projectile render benchmark: COMPLETE")
	quit()
