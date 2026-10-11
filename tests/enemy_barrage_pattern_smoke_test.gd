extends SceneTree

var failures: Array[String] = []
var world: Node2D
var registry: EnemyAugmentRegistry
var target: Node2D

func _initialize() -> void:
	run.call_deferred()

func expect(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

## Spawns at the given barrage pressure through the real registry path:
## P = Threat - 1 with no augments, fixed when the shoot component builds.
func actor(path: String, pressure := 0) -> EnemyShootComponent:
	var enemy := load(path).instantiate() as Enemy
	enemy.augment_registry = registry
	enemy.position = Vector2(100, 50)
	registry.threat_level = pressure + 1
	world.add_child(enemy)
	registry.threat_level = 1
	var shoot := enemy.get_node("EnemyShootComponent") as EnemyShootComponent
	shoot.fire_timer.stop()
	shoot.set_process(false)
	enemy.movement_controller.set_process(false)
	shoot.targeting_component.change_target(target)
	return shoot

func start(shoot: EnemyShootComponent, batches: Array) -> void:
	shoot.barrage_player.volley_fired.connect(func(bullets: Array[Node]): batches.append(bullets))
	shoot._start_pattern()
	shoot.barrage_player.set_physics_process(false)

func run() -> void:
	world = Node2D.new()
	world.add_to_group("gameplay_world")
	root.add_child(world)
	registry = EnemyAugmentRegistry.new()
	root.add_child(registry)
	target = Node2D.new()
	target.position = Vector2(100, 200)
	world.add_child(target)

	var striker := actor("res://enemies/moving_enemy.tscn")
	var batches: Array = []
	start(striker, batches)
	expect(batches.size() == 1 and batches[0].size() == 5, "Striker starts with five bullets")
	expect(batches[0][2] is FoundationBullet, "new projectile body")
	expect(batches[0][2].get_travel_velocity().is_equal_approx(Vector2(0, 80)), "Striker centered aim and speed")
	target.position = Vector2(250, 50)
	striker.barrage_player.advance(0.149)
	expect(batches.size() == 1, "no premature second volley")
	striker.barrage_player.advance(0.001)
	expect(batches.size() == 2 and batches[1][2].get_travel_velocity().is_equal_approx(Vector2(80, 0)), "second volley reacquires aim")
	striker.barrage_player.advance(4.499)
	expect(batches.size() == 2, "rest measured after final volley")
	striker.barrage_player.advance(0.001)
	expect(batches.size() == 3, "next burst at 4.65 seconds")
	striker.barrage_player.stop()
	striker.enemy.position.y = striker.enemy.get_viewport_rect().size.y * 0.9
	striker._start_pattern()
	striker.barrage_player.set_physics_process(false)
	expect(batches.size() == 3, "Striker skips fire below safety line")
	striker.enemy.position.y = 50
	striker.barrage_player.advance(0.15)
	expect(batches.size() == 4, "Striker resumes at next scheduled volley")
	striker.barrage_player.stop()

	var caster := actor("res://enemies/shooting_enemy.tscn")
	var drone := actor("res://enemies/normal_enemy.tscn", 6)
	var pressured := actor("res://enemies/moving_enemy.tscn", 6)
	var pressured_caster := actor("res://enemies/shooting_enemy.tscn", 6)
	await process_frame
	var rings: Array = []
	start(caster, rings)
	expect(rings.size() == 1 and rings[0].size() == 16, "Caster fires sixteen bullets at pressure 0")
	expect(rings[0][0].get_travel_velocity().is_equal_approx(Vector2(95, 0)), "Caster starts at right")
	for i in 4: caster.barrage_player.advance(0.1)
	expect(rings.size() == 5, "five rings per burst")
	var expected := Vector2.RIGHT.rotated(deg_to_rad(28)) * 95
	expect(rings[4][0].get_travel_velocity().is_equal_approx(expected), "seven degrees per ring")
	caster.barrage_player.advance(4.799)
	expect(rings.size() == 5, "no extra ring before rest ends")
	caster.barrage_player.advance(0.001)
	expect(rings.size() == 6 and rings[5][0].get_travel_velocity().is_equal_approx(Vector2(95, 0)), "cycle resets angle at 5.2 seconds")
	caster.apply_action_rate_multiplier(2)
	caster.barrage_player.advance(0.05)
	expect(rings.size() == 7, "Caster action rate scales ring interval")
	caster.barrage_player.stop()

	var pressured_rings: Array = []
	start(pressured_caster, pressured_rings)
	expect(pressured_rings[0].size() == 22, "Caster pressure 6 widens each ring to 22 bullets")
	for i in 4: pressured_caster.barrage_player.advance(0.1)
	expect(pressured_rings.size() == 5, "pressure keeps five rings per burst")
	pressured_caster.barrage_player.stop()

	var drone_rest := BarragePressure.scale(4.5, 2.5, 6)
	var drone_batches: Array = []
	start(drone, drone_batches)
	expect(drone_batches[0].size() == 1, "Drone pressure keeps a single aimed needle")
	drone.barrage_player.advance(drone_rest - 0.01)
	expect(drone_batches.size() == 1, "Drone pressure rest not cut short")
	drone.barrage_player.advance(0.02)
	expect(drone_batches.size() == 2, "Drone pressure 6 rests %.2f seconds" % drone_rest)
	var pressured_batches: Array = []
	start(pressured, pressured_batches)
	pressured.barrage_player.advance(0.15)
	expect(pressured_batches.size() == 2 and pressured_batches[0].size() == 5 and pressured_batches[1].size() == 5, "Striker pressure keeps the five-way fan")
	pressured.barrage_player.advance(BarragePressure.scale(4.5, 2.5, 6) + 0.001)
	expect(pressured_batches.size() == 3, "Striker pressure shortens the rest")
	drone.barrage_player.stop()
	pressured.barrage_player.stop()

	var interceptor := actor("res://enemies/interceptor_enemy.tscn")
	var shots: Array = []
	interceptor.barrage_player.volley_fired.connect(func(bullets: Array[Node]): shots.append(bullets))
	interceptor.enemy.position.x = -30
	interceptor._process(0.1)
	expect(not interceptor.has_visible_pass_started(), "Interceptor waits outside viewport")
	interceptor.enemy.position = Vector2(100, 50)
	interceptor._process(0)
	expect(interceptor.fire_timer.time_left > 0 and shots.is_empty(), "entry keeps initial delay")
	interceptor.fire_timer.stop()
	interceptor._start_pattern()
	interceptor.barrage_player.set_physics_process(false)
	interceptor.barrage_player.advance(0.45)
	expect(shots.size() == 5, "Interceptor emits exactly five volleys")
	expect(is_equal_approx(shots[0][0].get_travel_velocity().length(), 250), "Interceptor speed")
	interceptor._process(0.7)
	interceptor.barrage_player.advance(20)
	expect(shots.size() == 5 and not interceptor.barrage_player.running, "window stops future fire")

	var dense := actor("res://enemies/interceptor_enemy.tscn", 6)
	var dense_shots: Array = []
	dense.barrage_player.volley_fired.connect(func(bullets: Array[Node]): dense_shots.append(bullets))
	dense._process(0)
	dense.fire_timer.stop()
	dense._start_pattern()
	dense.barrage_player.set_physics_process(false)
	dense.barrage_player.advance(0.401)
	expect(dense_shots.size() == 8, "Interceptor pressure 6 packs eight shots into the same 0.4s burst (got %d)" % dense_shots.size())
	dense.barrage_player.stop()

	# A dead emitter cancels future fire but leaves existing world bullets alive.
	drone._start_pattern()
	drone.barrage_player.set_physics_process(false)
	var survivor: Node = drone_batches[0][0]
	var shot_total := drone_batches.size()
	# Detach the runner to verify its emitter lifetime binding independently.
	var runner := drone.barrage_player
	runner.reparent(world)
	drone.enemy.free()
	runner.advance(20)
	expect(not runner.running and drone_batches.size() == shot_total, "emitter deletion cancels future fire")
	expect(is_instance_valid(survivor) and survivor.get_parent() == world, "bullets survive emitter deletion")
	world.queue_free()
	registry.queue_free()
	await process_frame
	for failure in failures: push_error(failure)
	print("enemy barrage pattern smoke test: ", "PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
