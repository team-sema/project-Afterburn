extends SceneTree
## Read-only comparison of the user's mixed pattern and the original wave.

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var lab = load("res://projectiles/bullet_behavior_lab.tscn").instantiate()
	root.add_child(lab)
	lab.pattern_player.stop()
	await process_frame
	lab.set_process(false)
	lab.safety_meter.set_physics_process(false)
	var bullets := get_nodes_in_group("enemy_projectiles")
	for bullet in bullets:
		bullet.set_physics_process(false)
	var renderer = bullets[0].get_parent().get_node("ProjectileBatchRenderer")
	renderer.set_process(false)
	var sequence = load("res://patterns/mixed_sixteen_pattern.gd").new()
	var modified: BulletBehavior = sequence.steps[0].get_volleys()[1].shot.behavior
	for variant in ["wave_only", "modified"]:
		var behavior := BulletBehavior.new().heading_wave(35, 2.4).repeat() if variant == "wave_only" else modified
		for bullet in bullets:
			if bullet is CurvedLaser:
				bullet.behavior_state = BulletBehaviorState.new(behavior, bullet._direction, 45, Color.WHITE, 8)
		var probe := BulletBehaviorState.new(behavior, Vector2.DOWN, 45, Color.WHITE, 8)
		for age in [0.5, 2.0, 3.5, 6.0, 7.5]:
			var pose := 0
			var batch := 0
			var safety := 0
			for frame in 50:
				var start := Time.get_ticks_usec()
				for bullet in bullets:
					bullet.age = age + frame / 120.0
					if bullet is CurvedLaser: bullet._update_body()
					else: bullet._update_pose()
				var updated := Time.get_ticks_usec()
				renderer.refresh()
				var rendered := Time.get_ticks_usec()
				lab.safety_meter.measure()
				var sampled := Time.get_ticks_usec()
				if frame >= 10:
					pose += updated - start
					batch += rendered - updated
					safety += sampled - rendered
			print("MIXED_DIAGNOSTIC ", JSON.stringify({"variant": variant, "age": age, "speed": probe.sample(age).speed, "pose_ms": pose / 40000.0, "batch_ms": batch / 40000.0, "safety_sample_ms": safety / 40000.0, "bullets": bullets.size()}))
	lab.queue_free()
	await process_frame
	quit()
