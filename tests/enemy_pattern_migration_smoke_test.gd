extends SceneTree

var failures: Array[String] = []
var world: Node2D
var registry: EnemyAugmentRegistry
var target: Node2D

func _initialize() -> void:
	run.call_deferred()

func expect(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func actor(path: String, boosted := false) -> EnemyShootComponent:
	var enemy := load(path).instantiate() as Enemy
	enemy.augment_registry = registry
	enemy.position = Vector2(100, 50)
	# Exercise the real deferred spawn modifier path, including stacked boosts.
	if boosted:
		var factory := enemy.get_node("EnemyModifierFactory") as EnemyModifierFactory
		factory.local_behavior_components = [
			preload("res://components/augment_behaviors/enemy_fire_volume_boost_component.tscn"),
			preload("res://components/augment_behaviors/enemy_fire_volume_boost_component.tscn")]
	world.add_child(enemy)
	var shoot := enemy.get_node("EnemyShootComponent") as EnemyShootComponent
	shoot.fire_timer.stop()
	shoot.set_process(false)
	enemy.movement_controller.set_process(false)
	shoot.targeting_component.change_target(target)
	return shoot

func start(shoot: EnemyShootComponent, batches: Array) -> void:
	shoot.barrage_player.volley_fired.connect(func(bullets: Array[Node2D]): batches.append(bullets))
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
	expect(batches[0][2].get_threat_velocity().is_equal_approx(Vector2(0, 80)), "Striker centered aim and speed")
	target.position = Vector2(250, 50)
	striker.barrage_player.advance(0.149)
	expect(batches.size() == 1, "no premature second volley")
	striker.barrage_player.advance(0.001)
	expect(batches.size() == 2 and batches[1][2].get_threat_velocity().is_equal_approx(Vector2(80, 0)), "second volley reacquires aim")
	striker.barrage_player.advance(4.499)
	expect(batches.size() == 2, "rest measured after final volley")
	striker.barrage_player.advance(0.001)
	expect(batches.size() == 3, "next burst at 4.65 seconds")
	expect(is_equal_approx(striker.get_threat_projectile_rate(), 10.0 / 4.65), "Striker threat preserved")
	striker.barrage_player.stop()
	striker.enemy.position.y = striker.enemy.get_viewport_rect().size.y * 0.9
	striker._start_pattern()
	striker.barrage_player.set_physics_process(false)
	expect(batches.size() == 3, "Striker skips fire below safety line")
	striker.enemy.position.y = 50
	striker.barrage_player.advance(0.15)
	expect(batches.size() == 4, "Striker resumes at next scheduled volley")
	striker.barrage_player.stop()

	var caster := actor("res://enemies/shooting_enemy.tscn", true)
	var drone := actor("res://enemies/normal_enemy.tscn", true)
	var boosted := actor("res://enemies/moving_enemy.tscn", true)
	await process_frame
	# Deferred modifier callbacks have run; no initial delays have elapsed.
	expect(not caster.pattern_fire_volume_boost, "Caster excludes volume boost")
	var rings: Array = []
	start(caster, rings)
	expect(rings.size() == 1 and rings[0].size() == 16, "Caster retains sixteen bullets under boost")
	expect(rings[0][0].get_threat_velocity().is_equal_approx(Vector2(95, 0)), "Caster starts at right")
	for i in 4: caster.barrage_player.advance(0.1)
	expect(rings.size() == 5, "five rings per burst")
	var expected := Vector2.RIGHT.rotated(deg_to_rad(28)) * 95
	expect(rings[4][0].get_threat_velocity().is_equal_approx(expected), "seven degrees per ring")
	caster.barrage_player.advance(4.799)
	expect(rings.size() == 5, "no extra ring before rest ends")
	caster.barrage_player.advance(0.001)
	expect(rings.size() == 6 and rings[5][0].get_threat_velocity().is_equal_approx(Vector2(95, 0)), "cycle resets angle at 5.2 seconds")
	caster.apply_action_rate_multiplier(2)
	expect(is_equal_approx(caster.get_threat_projectile_rate(), 160.0 / 5.2), "Caster scaled threat")
	caster.barrage_player.advance(0.05)
	expect(rings.size() == 7, "Caster action rate scales ring interval")
	caster.barrage_player.stop()

	var drone_batches: Array = []
	start(drone, drone_batches)
	expect(drone_batches[0].size() == 5, "Drone stacked volume boosts add four bullets")
	var boosted_batches: Array = []
	start(boosted, boosted_batches)
	boosted.barrage_player.advance(0.15)
	expect(boosted_batches.size() == 2 and boosted_batches[0].size() == 9 and boosted_batches[1].size() == 9, "boost applies once to every reused volley")
	var left: Vector2 = boosted_batches[0][0].get_threat_velocity().normalized()
	var right: Vector2 = boosted_batches[0][-1].get_threat_velocity().normalized()
	expect(is_equal_approx(rad_to_deg(left.angle_to(right)), 18.0), "boost minimum spread")
	expect(is_equal_approx(boosted.get_threat_projectile_rate(), 18.0 / 4.65), "boost updates threat summary")
	drone.barrage_player.stop()
	boosted.barrage_player.stop()

	var interceptor := actor("res://enemies/interceptor_enemy.tscn")
	var shots: Array = []
	interceptor.barrage_player.volley_fired.connect(func(bullets: Array[Node2D]): shots.append(bullets))
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
	expect(is_equal_approx(shots[0][0].get_threat_velocity().length(), 250), "Interceptor speed")
	expect(is_equal_approx(interceptor.get_threat_projectile_rate(), 5.0 / 10.4), "Interceptor retains cycle threat")
	interceptor._process(0.7)
	interceptor.barrage_player.advance(20)
	expect(shots.size() == 5 and not interceptor.barrage_player.running, "window stops future fire")

	# A dead emitter cancels future fire but leaves existing world bullets alive.
	drone._start_pattern()
	drone.barrage_player.set_physics_process(false)
	var survivor: Node2D = drone_batches[0][0]
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
	print("enemy pattern migration smoke test: ", "PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
