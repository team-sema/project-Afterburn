extends SceneTree

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
	var bullet := copied.spawn(world, origin, Vector2.RIGHT, 900) as SniperBullet
	expect(bullet != null, "adapter spawns specialized body")
	if bullet != null:
		bullet.set_physics_process(false)
		expect(bullet.is_in_group("enemy_projectiles"), "cancel/reward group retained")
		expect(bullet.global_position.is_equal_approx(origin) and is_equal_approx(bullet.global_rotation, -PI / 2), "world position and rotation under transformed parent")
		expect(bullet._shape.size == Vector2(4, 30) and bullet._hitbox.damage == 3, "high-speed hitbox and damage retained")
		var finished_count := [0]
		bullet.finished.connect(func(): finished_count[0] += 1)
		bullet._physics_process(1.0)
		expect(bullet.global_position.is_equal_approx(origin + Vector2(240, 0)), "range clamps long frame travel")
		expect(finished_count[0] == 1 and bullet.is_queued_for_deletion(), "range ends body once")
		bullet._finish()
		expect(finished_count[0] == 1, "finish is idempotent")
	shot.bullet_width = NAN
	expect(not shot.is_valid() and shot.spawn(world, origin, Vector2.DOWN, 900) == null, "invalid settings rejected")
	world.queue_free()
	await process_frame
	for failure in failures: push_error(failure)
	print("sniper barrage shot smoke test: ", "PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
