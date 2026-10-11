extends SceneTree

var failures: Array[String] = []
func _initialize() -> void:
	run.call_deferred()
func expect(value: bool, message: String) -> void:
	if not value: failures.append(message)
func run() -> void:
	var world := Node2D.new()
	root.add_child(world)
	var shot := BarrageShot.new()
	shot.appearance = preload("res://resources/projectiles/needle.tres")
	shot.behavior = BulletBehavior.new().parallel([BulletAction.turn_by(90, 1), BulletAction.visual_scale_to(2, 1), BulletAction.tint_to(Color(0.2, 0.8, 1), 1)])
	var bullets: Array[FoundationBullet] = []
	for i in 20:
		var bullet := shot.spawn(world, Vector2(30 + i * 28, 130), Vector2.DOWN, 30) as FoundationBullet
		bullet.simulating = false
		bullet.age = 0.5
		bullet._update_pose()
		bullet.show_hitbox = true
		bullets.append(bullet)
	var shape := bullets[0].collision_shape()
	expect(shape is RectangleShape2D and shape.size == Vector2(4, 8), "rectangle shape matches original")
	var pose := bullets[0].collision_transform()
	expect(pose.origin.is_equal_approx(bullets[0].global_position + Vector2(0, 1).rotated(bullets[0].global_rotation)) and pose.get_scale().is_equal_approx(Vector2.ONE), "visual growth preserves hitbox and offset")
	expect(is_equal_approx(bullets[0].visual_scale, 1.5), "visual scale behavior applies")
	await process_frame
	var pool := EnemyBulletPool.for_parent(world)
	var groups: Dictionary = pool.get_render_groups()
	expect(groups.size() == 1 and groups.values()[0].items.size() == 3, "20 textured bullets share one instance batch and 3 layer materials")
	expect(groups.values()[0].members.size() == 20 and pool._debug_count == 20, "rectangle batch and debug outlines populated")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		await process_frame
		print("20 textured bullets with hitboxes: draw calls = ", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	# Second row: original scene without particles/tween, compared at static size.
	for i in 12:
		var old = preload("res://projectiles/base_enemy_projectile.tscn").instantiate()
		world.add_child(old)
		old.position = Vector2(40 + i * 45, 250)
		old.launch(Vector2.DOWN, 0)
		old.get_node("Sprite2D/Trail").emitting = false
		old.get_node("ScaleComponent").scale_tween.kill()
		old.get_node("Sprite2D").scale = Vector2.ONE
	# Third row: the scene-instantiated body with a straight behavior.
	for i in 12:
		var bullet := preload("res://projectiles/foundation_bullet.tscn").instantiate() as FoundationBullet
		bullet.appearance = shot.appearance
		bullet.behavior = BulletBehavior.new()
		world.add_child(bullet)
		bullet.global_position = Vector2(40 + i * 45, 300)
		bullet.launch(Vector2.DOWN, 0)
		bullet.simulating = false
	# Real rectangle collision: visual growth alone must not enlarge the hitbox.
	var hurt := HurtboxComponent.new()
	hurt.position = Vector2(614, 61)
	hurt.collision_layer = 1
	hurt.collision_mask = 0
	var hurt_shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 0.5
	hurt_shape.shape = circle
	hurt.add_child(hurt_shape)
	world.add_child(hurt)
	var hits: Array = []
	hurt.hurt.connect(func(hit): hits.append(hit))
	var collision_shot := BarrageShot.new()
	collision_shot.appearance = shot.appearance
	collision_shot.behavior = BulletBehavior.new().visual_scale_to(3, 1).hitbox_scale_to(3, 1)
	var collision_bullet := collision_shot.spawn(world, Vector2(610, 60), Vector2.DOWN, 0) as FoundationBullet
	collision_bullet.simulating = false
	collision_bullet.age = 1
	collision_bullet._update_pose()
	await physics_frame
	await physics_frame
	await process_frame
	expect(hits.is_empty(), "rectangle ignores visual-only growth")
	collision_bullet.age = 2
	collision_bullet._update_pose()
	await physics_frame
	await physics_frame
	await process_frame
	expect(hits.size() == 1, "rectangle hitbox growth causes real contact")
	hurt.queue_free()
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/textured_bullets.png")
	world.queue_free()
	await process_frame
	for failure in failures: push_error(failure)
	print("textured bullet smoke test: ", "PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
