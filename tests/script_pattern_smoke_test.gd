extends SceneTree

class CountingPattern extends BarrageSequence:
	static var constructions := 0
	func _init() -> void:
		constructions += 1
		fire_ring(preload("res://resources/projectiles/round_straight_shot.tres"), 2)
		wait(1)
		repeat()

class ParamPattern extends BarrageSequence:
	func build(params: Dictionary) -> void:
		fire_ring(preload("res://resources/projectiles/round_straight_shot.tres"), int(params.get("count", 3)))
		wait(1)
		repeat()

var failures: Array[String] = []
var registry: EnemyAugmentRegistry
var world: Node2D

func _initialize() -> void:
	run.call_deferred()

func expect(value: bool, message: String) -> void:
	if not value: failures.append(message)

func drone(entry := false) -> EnemyShootComponent:
	var actor := preload("res://enemies/normal_enemy.tscn").instantiate() as Enemy
	actor.augment_registry = registry
	actor.position = Vector2(100, -30 if entry else 50)
	var shoot := actor.get_node("EnemyShootComponent") as EnemyShootComponent
	shoot.activate_on_visible_entry = entry
	world.add_child(actor)
	shoot.fire_timer.stop()
	shoot.set_process(false)
	return shoot

func run() -> void:
	registry = EnemyAugmentRegistry.new()
	world = Node2D.new()
	world.add_to_group("gameplay_world")
	root.add_child(world)
	var target := Node2D.new()
	world.add_child(target)
	target.position = Vector2(200, 250)
	var a := drone()
	var b := drone()
	a.targeting_component.change_target(target)
	b.targeting_component.change_target(target)
	expect(not a.barrage_player.running and a.get_volleys_fired() == 0, "activation delay prevents immediate shot")
	a._start_pattern()
	b._start_pattern()
	a.barrage_player.set_physics_process(false)
	b.barrage_player.set_physics_process(false)
	expect(a.get_volleys_fired() == 1 and b.get_volleys_fired() == 1, "two enemies start independently")
	expect(a.barrage_player._sequence != b.barrage_player._sequence, "runtime sequence isolation")
	a.barrage_player._sequence.steps[0].volley.speed = 1
	expect(b.barrage_player._sequence.steps[0].volley.speed == 105, "nested volley isolation")
	expect(b.barrage_player._sequence.steps[0].volley.shot.appearance.form == BulletAppearance.Form.TEXTURED, "Drone uses textured appearance")
	var legacy_bullets := get_nodes_in_group("enemy_projectiles")
	expect(legacy_bullets.size() == 2 and legacy_bullets[0] is FoundationBullet, "Drone spawns new body with existing texture")
	a.fire()
	expect(a.get_volleys_fired() == 1, "legacy fire cannot overlap pattern")
	a.enemy.position.y = a.enemy.get_viewport_rect().size.y * 0.9
	a.barrage_player.advance(4.5)
	expect(a.get_volleys_fired() == 1, "threshold skips scheduled fire")
	a.enemy.position.y = 50
	a.barrage_player.advance(4.49)
	expect(a.get_volleys_fired() == 1, "skipped fire is not deferred")
	a.barrage_player.advance(0.01)
	expect(a.get_volleys_fired() == 2, "next scheduled fire resumes")
	target.free()
	a.barrage_player.advance(4.5)
	expect(a.barrage_player.running and a.get_volleys_fired() == 2, "missing dynamic target skips without stopping")
	target = Node2D.new()
	target.add_to_group("player")
	world.add_child(target)
	target.position = Vector2(220, 250)
	a.barrage_player.advance(4.5)
	expect(a.get_volleys_fired() == 3, "target automatically reacquired")
	a.apply_action_rate_multiplier(2)
	expect(is_equal_approx(a.get_threat_projectile_rate(), 2.0 / 4.5), "threat rate derived from pattern and scale")
	a.barrage_player.advance(2.25)
	expect(a.get_volleys_fired() == 4 and b.get_volleys_fired() == 1, "scaled schedule and independent clocks")
	a.barrage_player.pause()
	a.barrage_player.advance(9)
	expect(a.get_volleys_fired() == 4, "runner pause")
	a.barrage_player.resume()
	paused = true
	a.barrage_player.advance(9)
	expect(a.get_volleys_fired() == 4, "tree pause")
	paused = false
	a.active_duration = 0.5
	a._process(0.5)
	expect(not a.barrage_player.running, "active duration stops pattern")
	var entrant := drone(true)
	expect(not entrant.is_fire_window_active(), "offscreen activation waits")
	entrant._process(0.1)
	expect(not entrant.barrage_player.running, "offscreen cannot start")
	entrant.enemy.position.y = 50
	entrant._process(0.1)
	expect(entrant.is_fire_window_active() and not entrant.fire_timer.is_stopped(), "visible entry starts initial delay")
	entrant.fire_timer.stop()
	var count := get_nodes_in_group("enemy_projectiles").size()
	b.enemy.queue_free()
	await process_frame
	expect(get_nodes_in_group("enemy_projectiles").size() == count, "emitter death preserves existing projectiles")
	var pattern := CountingPattern.new()
	var runner := BarragePlayer.new()
	world.add_child(runner)
	expect(runner.play(pattern, a.enemy, world), "derived sequence plays")
	runner.set_physics_process(false)
	expect(CountingPattern.constructions == 1 and runner._sequence.steps.size() == 2, "snapshot never reruns constructor or duplicates steps")
	pattern.steps[0].volley.count = 7
	expect(runner._sequence.steps[0].volley.count == 2, "snapshot ignores original edits")
	# A missing target must suppress only aimed volleys within a mixed FIRE.
	var mixed := preload("res://patterns/mixed_sixteen_pattern.gd").new()
	mixed.steps[0].volleys[0].aimed = true
	var sizes: Array[int] = []
	runner.resolve_target = func(): return null
	runner.volley_fired.connect(func(nodes): sizes.append(nodes.size()))
	runner.play(mixed, a.enemy, world)
	expect(sizes == [8], "missing target preserves non-aimed simultaneous volley")
	# build(params) receives the component's pattern_params after _init(); the Lab passes {}.
	expect(not ParamPattern.new().validation_error().is_empty(), "build-only pattern is empty before build()")
	var defaults := ParamPattern.new()
	defaults.build({})
	expect(defaults.validation_error().is_empty() and defaults.steps[0].volley.count == 3, "build() defaults work without params")
	var parametrized := preload("res://enemies/normal_enemy.tscn").instantiate() as Enemy
	parametrized.augment_registry = registry
	parametrized.position = Vector2(100, 50)
	var param_shoot := parametrized.get_node("EnemyShootComponent") as EnemyShootComponent
	param_shoot.pattern_script = ParamPattern
	param_shoot.pattern_params = {"count": 5}
	param_shoot.activate_on_visible_entry = false
	world.add_child(parametrized)
	param_shoot.fire_timer.stop()
	param_shoot.set_process(false)
	var param_sizes: Array[int] = []
	param_shoot.barrage_player.volley_fired.connect(func(nodes): param_sizes.append(nodes.size()))
	param_shoot._start_pattern()
	param_shoot.barrage_player.set_physics_process(false)
	expect(param_shoot.pattern_error.is_empty() and param_sizes == [5], "pattern_params reach build() through the component")
	expect(is_equal_approx(param_shoot.get_threat_projectile_rate(), 5.0), "threat summary reflects the built pattern")
	# Reject an incompatible script before instantiating it; no legacy fallback.
	var invalid_enemy := preload("res://enemies/normal_enemy.tscn").instantiate() as Enemy
	invalid_enemy.augment_registry = registry
	var invalid_shoot := invalid_enemy.get_node("EnemyShootComponent") as EnemyShootComponent
	invalid_shoot.pattern_script = preload("res://projectiles/bullet_appearance.gd")
	world.add_child(invalid_enemy)
	expect(not invalid_shoot.pattern_error.is_empty() and invalid_shoot.fire_timer == null and invalid_shoot.barrage_player == null, "invalid script fails closed")
	world.queue_free()
	await process_frame
	registry.free()
	for failure in failures: push_error(failure)
	print("script pattern smoke test: ", "PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
