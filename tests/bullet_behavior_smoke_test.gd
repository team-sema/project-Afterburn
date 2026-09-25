extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func expect(value: bool, message: String) -> void:
	if not value: failures.append(message)

func state(behavior: BulletBehavior, direction := Vector2.DOWN, speed := 90.0) -> BulletBehaviorState:
	return BulletBehaviorState.new(behavior, direction, speed, Color.WHITE, 8)

func check_easing_bounds() -> void:
	for transition in range(Tween.TRANS_LINEAR, Tween.TRANS_SPRING + 1):
		for easing in range(Tween.EASE_IN, Tween.EASE_OUT_IN + 1):
			var behavior := BulletBehavior.new().parallel([
				BulletAction.make(BulletAction.Type.SPEED, 0, 1).eased(transition, easing),
				BulletAction.make(BulletAction.Type.OPACITY, 0, 1).eased(transition, easing),
				BulletAction.visual_scale_to(0.01, 1).eased(transition, easing),
				BulletAction.hitbox_scale_to(2, 1).eased(transition, easing),
				BulletAction.turn_by(90, 1).eased(transition, easing),
				BulletAction.tint_to(Color.RED, 1).eased(transition, easing),
			])
			var runtime := state(behavior, Vector2.DOWN, 100)
			var shrinking := state(BulletBehavior.new().hitbox_scale_to(0.01, 1).eased(transition, easing))
			expect(behavior.validation_error().is_empty(), "bounded easing fixture is valid")
			for i in 101:
				var t := i / 100.0
				var sample := runtime.sample(t)
				var label := "easing %d/%d at %s" % [transition, easing, t]
				expect(sample.speed >= 0 and sample.speed <= 100, label + " speed bounds")
				expect(sample.opacity >= 0 and sample.opacity <= 1, label + " opacity bounds")
				expect(sample.visual_scale >= 0.01 - 1e-6 and sample.visual_scale <= 1, label + " visual bounds")
				expect(sample.hitbox_scale >= 1 and sample.hitbox_scale <= runtime.max_hitbox_scale(8), label + " threat envelope")
				expect(shrinking.sample(t).hitbox_scale >= 0.01 - 1e-6 and shrinking.sample(t).hitbox_scale <= 1, label + " shrinking hitbox bounds")
				expect(sample.heading >= 0 and sample.heading <= 90, label + " heading bounds")
				expect(sample.tint.g >= 0 and sample.tint.g <= 1, label + " tint bounds")

func check_wave_cycles() -> void:
	for phase in [0.0, PI / 2, -PI / 3]:
		for duration in [0.0, 0.3, 1.0]:
			for repeats in [0, 1, 2, 3]:
				if duration == 0 and repeats == 0: continue
				var wave := BulletAction.make(BulletAction.Type.HEADING_WAVE, 35, duration)
				wave.period = 1.0
				wave.phase = phase
				var fast := state(BulletBehavior.new().then(wave).repeat(repeats))
				var general := state(BulletBehavior.new().parallel([wave]).repeat(repeats))
				# Future-first queries also check cached history and finite-repeat tails.
				for t in [7.99, 0.0, 0.113, duration, duration + 0.001, 1.25, 2.0, 3.0]:
					var label := "wave phase=%s duration=%s repeats=%s time=%s" % [phase, duration, repeats, t]
					expect(fast.position_at(t).distance_to(general.position_at(t)) < 0.001, label + " position")
					expect(fast._forward_velocity(t).distance_to(fast.velocity_at(t)) < 0.001, label + " sampled velocity")
					expect(fast.velocity_at(t).distance_to(general.velocity_at(t)) < 0.001, label + " generic velocity")

func run() -> void:
	check_easing_bounds()
	check_wave_cycles()
	var behavior := BulletBehavior.new().wait(0.5).turn_by(90, 1).wait(0.5).speed_to(0, 1)
	var runtime := state(behavior)
	expect(is_equal_approx(runtime.sample(0.5).heading, 0) and is_equal_approx(runtime.sample(1).heading, 45), "turn starts at its own scheduled time")
	expect(is_equal_approx(runtime.sample(1.5).heading, 90) and is_equal_approx(runtime.sample(2.5).speed, 45), "completed heading persists while speed changes")
	expect(runtime.velocity_at(3).is_zero_approx(), "deceleration can stop a projectile")
	var initial := runtime.position_at(0.3)
	runtime.position_at(4)
	expect(runtime.position_at(0.3).is_equal_approx(initial), "future queries never rewrite prior trajectory")
	var other := state(behavior)
	for i in 300: other.position_at(i / 100.0)
	expect(other.position_at(3).distance_to(runtime.position_at(3)) < 0.001, "trajectory is independent of frame partition")
	behavior.actions[1].value = -90
	expect(is_equal_approx(runtime.sample(1.5).heading, 90), "runtime snapshots the nested behavior")
	var absolute := state(BulletBehavior.new().turn_to(0, 1), Vector2.RIGHT)
	expect(absolute.velocity_at(1).normalized().is_equal_approx(Vector2.DOWN), "absolute heading uses world-down zero regardless of launch direction")
	var circle := state(BulletBehavior.new().turn_at(70, 1.5))
	var omega := deg_to_rad(70)
	var expected := 90.0 / omega * (Vector2.DOWN * sin(omega) + Vector2.LEFT * (1 - cos(omega)))
	expect(circle.position_at(1).distance_to(expected) < 0.001, "legacy crescent trajectory is preserved analytically")
	var s_curve := state(BulletBehavior.new().heading_wave(35, 2.4).repeat())
	for repeats in [0, 1, 3]:
		var fast := state(BulletBehavior.new().heading_wave(35, 2.4).repeat(repeats))
		# Match the explicit wave period in the generic parallel evaluator.
		var wave := BulletAction.make(BulletAction.Type.HEADING_WAVE, 35, 2.4)
		wave.period = 2.4
		var general := state(BulletBehavior.new().parallel([wave]).repeat(repeats))
		for time in [0.0, 0.113, 2.4, 2.401, 7.2, 7.99]:
			expect(fast.position_at(time).distance_to(general.position_at(time)) < 0.001, "wave fast path matches generic timeline")
	expect(is_equal_approx(s_curve.sample(0.6).heading, 35) and is_equal_approx(s_curve.sample(1.8).heading, -35), "S wave turns to both sides of initial heading")
	expect(absf(s_curve.position_at(2.4).x) < 0.01 and s_curve.position_at(2.4).y > 180, "S wave advances without lateral drift each cycle")
	var composed := state(BulletBehavior.new().turn_by(40, 0).heading_wave(20, 1.0))
	expect(is_equal_approx(composed.sample(0.25).heading, 60) and is_equal_approx(composed.sample(0.75).heading, 20) and is_equal_approx(composed.sample(1.0).heading, 40), "heading wave is centered on the heading at action start")
	expect(composed.velocity_at(0.25).normalized().is_equal_approx(Vector2.DOWN.rotated(deg_to_rad(60))), "composed wave moves along the composed heading")
	# Easing changes the interpolation curve but not the endpoints or the integration.
	var eased := state(BulletBehavior.new().speed_to(0, 1).eased(Tween.TRANS_QUAD, Tween.EASE_IN))
	var linear := state(BulletBehavior.new().speed_to(0, 1))
	expect(is_equal_approx(eased.sample(0.5).speed, 67.5) and is_equal_approx(eased.sample(1).speed, 0), "quadratic ease-in speed curve")
	expect(is_equal_approx(linear.sample(0.5).speed, 45), "default easing stays linear")
	expect(absf(eased.position_at(1).y - 60) < 0.05 and absf(linear.position_at(1).y - 45) < 0.05, "eased velocity integrates to the analytic distance")
	var eased_child := state(BulletBehavior.new().parallel([BulletAction.turn_by(90, 1).eased(Tween.TRANS_QUAD, Tween.EASE_OUT), BulletAction.tint_to(Color.RED, 1)]))
	expect(is_equal_approx(eased_child.sample(0.5).heading, 67.5) and eased_child.sample(0.5).tint.is_equal_approx(Color.WHITE.lerp(Color.RED, 0.5)), "parallel children ease independently")
	var eased_rate := state(BulletBehavior.new().turn_at(30, 1).eased(Tween.TRANS_QUAD, Tween.EASE_IN))
	expect(is_equal_approx(eased_rate.sample(0.5).heading, 15), "constant-rate turn ignores easing")
	var repeated := state(BulletBehavior.new().turn_by(30, 0.5).repeat(3))
	expect(is_equal_approx(repeated.sample(2).heading, 90), "finite repeat preserves final state")
	var parallel := BulletBehavior.new().parallel([
		BulletAction.turn_by(90, 1), BulletAction.tint_to(Color.RED, 0.5),
		BulletAction.visual_scale_to(3, 1), BulletAction.hitbox_scale_to(2, 1),
	]).opacity_to(0.2, 0.5)
	var properties := state(parallel)
	expect(properties.sample(0.5).tint == Color.RED and is_equal_approx(properties.sample(0.5).visual_scale, 2), "parallel channels interpolate independently")
	expect(is_equal_approx(properties.sample(0.5).hitbox_scale, 1.5) and is_equal_approx(properties.sample(1.25).opacity, 0.6), "next action waits for longest parallel action")
	var conflicting := BulletBehavior.new().parallel([BulletAction.turn_by(90, 1), BulletAction.make(BulletAction.Type.TURN_AT, 30, 1)])
	expect(not conflicting.validation_error().is_empty(), "parallel heading writers are rejected")
	expect(not BulletBehavior.new().wait(0).repeat().validation_error().is_empty(), "zero-duration infinite behavior rejected")
	expect(not BulletBehavior.new().visual_scale_to(-1, 1).validation_error().is_empty(), "invalid scales rejected")
	# Real physics: visual growth alone must not enlarge the hurt area.
	var world := Node2D.new()
	root.add_child(world)
	var hurtbox := HurtboxComponent.new()
	hurtbox.position = Vector2(106, 100)
	hurtbox.collision_layer = 1
	hurtbox.collision_mask = 0
	var shape := CollisionShape2D.new()
	var circle_shape := CircleShape2D.new()
	circle_shape.radius = 1
	shape.shape = circle_shape
	hurtbox.add_child(shape)
	world.add_child(hurtbox)
	var hits: Array = []
	hurtbox.hurt.connect(func(hit): hits.append(hit))
	var shot := load("res://resources/projectiles/round_straight_shot.tres").duplicate(true) as BarrageShot
	shot.behavior = BulletBehavior.new().visual_scale_to(3, 1).hitbox_scale_to(3, 1)
	var bullet := shot.spawn(world, Vector2(100, 100), Vector2.DOWN, 0) as FoundationBullet
	bullet.set_physics_process(false)
	bullet.age = 1
	bullet._update_pose()
	await physics_frame
	await physics_frame
	await process_frame
	expect(hits.is_empty() and bullet.hitbox_scale == 1 and bullet.visual_scale == 3, "visual growth alone does not hit nearby hurtbox")
	bullet.age = 2
	bullet._update_pose()
	await physics_frame
	await physics_frame
	await process_frame
	expect(hits.size() == 1, "explicit hitbox growth changes real collision")
	world.queue_free()
	await process_frame
	# Saved mixed pattern: two rings in one atomic fire step.
	var lab = load("res://projectiles/bullet_behavior_lab.tscn").instantiate()
	root.add_child(lab)
	lab.pattern_player.stop()
	var balls: Array[FoundationBullet] = []
	var lasers: Array[CurvedLaser] = []
	for node in get_nodes_in_group("enemy_projectiles"):
		node.set_physics_process(false)
		if node is FoundationBullet: balls.append(node)
		elif node is CurvedLaser: lasers.append(node)
	expect(balls.size() == 8 and lasers.size() == 8, "mixed preset emits 8 balls and 8 lasers together")
	for i in 8:
		expect(balls[i]._direction.is_equal_approx(Vector2.DOWN.rotated(deg_to_rad(45.0 * i))), "ball ring axes")
		expect(lasers[i]._direction.is_equal_approx(Vector2.DOWN.rotated(deg_to_rad(45.0 * i + 22.5))), "laser ring interleaves at 22.5 degrees")
	for laser in lasers:
		var future := laser.get_predicted_path(2.8)
		var old_point := laser.position_at(0.4)
		laser.age = 2.8
		laser._update_body()
		expect(future[-1].distance_to(laser.global_position) < 0.001, "laser prediction and actual motion agree")
		expect(laser.position_at(0.4).is_equal_approx(old_point), "S laser preserves historical body positions")
		laser.show_hitbox = true
	for ball in balls:
		ball.age = 1.4
		ball._update_pose()
	if "--capture" in OS.get_cmdline_user_args():
		lab.hitbox_button.button_pressed = true
		lab.toggle_pause()
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/mixed_sixteen_lab.png")
		lab.pattern_choice.select(7)
		lab._selection_changed(7)
		lab.pattern_player.stop()
		for node in get_nodes_in_group("enemy_projectiles"):
			if node is FoundationBullet and not node.is_queued_for_deletion():
				node.set_physics_process(false)
				node.age = 1.5
				node._update_pose()
		lab._toggle_hitboxes(true)
		lab.toggle_pause()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/behavior_visual_lab.png")
	lab.queue_free()
	await process_frame
	if failures.is_empty(): print("bullet behavior smoke test: PASS")
	else:
		for failure in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)
