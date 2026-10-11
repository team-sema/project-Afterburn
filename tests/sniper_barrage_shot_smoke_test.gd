extends SceneTree
## SniperBarrageShot spawns a pooled FoundationBullet: range becomes lifetime,
## width sizes the streak and its collision rectangle, damage rides on the body,
## and the round obeys the enemy bullet contract (group, effects, cancel).

var failures: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func expect(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func run() -> void:
	var world := Node2D.new()
	world.position = Vector2(17, 23)
	world.rotation = 0.3
	root.add_child(world)
	var shot := SniperBarrageShot.new()
	shot.bullet_width = 4
	shot.max_range = 240
	shot.damage = 3
	var sequence := BarrageSequence.new()
	sequence.fire_fan(shot, 1, 0, 900)
	var copy := sequence.snapshot()
	shot.damage = 9
	var copied := copy.steps[0].volley.shot as SniperBarrageShot
	expect(copied != null and copied.damage == 3, "snapshot preserves specialized settings independently")
	var origin := Vector2(80, 60)
	var bullet := copied.spawn(world, origin, Vector2.RIGHT, 900) as FoundationBullet
	expect(bullet != null, "adapter spawns a pooled bullet")
	if bullet != null:
		bullet.simulating = false
		expect(bullet.is_in_group("enemy_projectiles"), "cancel/reward group retained")
		expect(bullet.global_position.is_equal_approx(origin) and is_equal_approx(bullet.global_rotation, PI * 0.5), "world position and travel rotation (sprite up = travel, so right is +90°)")
		expect(bullet.collision_shape() is RectangleShape2D and bullet.collision_shape().size == Vector2(4, 30) and bullet.damage == 3, "high-speed hitbox and damage retained")
		expect(is_equal_approx(bullet.lifetime, 240.0 / 900.0), "range becomes lifetime")
		expect(bullet.appearance.form == BulletAppearance.Form.TEXTURED and is_equal_approx(bullet.appearance.core_size.x, 4.0), "width scales the streak sprite")
		expect(bullet._straight, "sniper round takes the straight fast path")
		var gone := [0]
		bullet.tree_exiting.connect(func(): gone[0] += 1)
		bullet._physics_process(1.0)
		expect(bullet.global_position.is_equal_approx(origin + Vector2(240, 0)), "range clamps long frame travel")
		expect(bullet.is_queued_for_deletion(), "range ends body")
		await process_frame
		expect(gone[0] == 1 and not is_instance_valid(bullet), "body frees itself once at range")
	# Trajectory effects apply like any other enemy bullet (time warp, brink, singularity).
	var slowed := copied.spawn(world, origin, Vector2.RIGHT, 900) as FoundationBullet
	if slowed != null:
		slowed.simulating = false
		expect(EnemyBullets.apply_effect(slowed, &"test", 0.5), "sniper round accepts trajectory effects")
		expect(slowed.get_travel_velocity().is_equal_approx(Vector2.RIGHT * 450), "slow field halves the round's speed")
		expect(EnemyBullets.cancel(world, slowed, &"lab"), "sniper round can be cancelled")
	shot.bullet_width = NAN
	expect(not shot.is_valid() and shot.spawn(world, origin, Vector2.DOWN, 900) == null, "invalid settings rejected")
	world.queue_free()
	await process_frame
	for failure in failures: push_error(failure)
	print("sniper barrage shot smoke test: ", "PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
