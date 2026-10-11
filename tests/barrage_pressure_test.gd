extends SceneTree

## Barrage pressure P (docs/design/combat.md 탄막 압력): shared curve, the
## registry sum, and each ordinary enemy's interpretation table.

const FIRE_BOOST := preload("res://resources/enemy_augments/enemy_fire_volume_boost.tres")
const FAST_FUSE := preload("res://resources/enemy_augments/enemy_bomb_fast_fuse.tres")

var failures: PackedStringArray = []
var world: Node2D
var registry: EnemyAugmentRegistry


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	world = Node2D.new()
	world.add_to_group("gameplay_world")
	root.add_child(world)
	registry = EnemyAugmentRegistry.new()
	root.add_child(registry)

	_check_curve()
	_check_registry()
	_check_patterns()
	await _check_components()

	world.queue_free()
	registry.queue_free()
	for _frame in 3:
		await process_frame
	if failures.is_empty():
		print("barrage_pressure_test: PASS")
		quit()
		return
	for failure in failures:
		push_error(failure)
	print("barrage_pressure_test: FAIL")
	quit(1)


func _check_curve() -> void:
	_expect(is_equal_approx(BarragePressure.progress(0), 0.0), "P 0 keeps the base value")
	_expect(is_equal_approx(BarragePressure.progress(4), 0.5), "half-life of four levels")
	_expect(is_equal_approx(BarragePressure.progress(-3), 0.0), "negative pressure clamps to 0")
	_expect(BarragePressure.progress(40) < 1.0, "the curve never reaches the limit")
	_expect(is_equal_approx(BarragePressure.scale(4.5, 2.5, 4), 3.5), "scale lerps by the curve")
	var evens := [0, 3, 6, 10, 20].map(func(p: int) -> int: return BarragePressure.scale_even(16, 26, p))
	_expect(evens == [16, 20, 22, 24, 26], "Caster ring counts follow the table: %s" % [evens])
	var shots := [0, 3, 6, 10, 20].map(func(p: int) -> int: return BarragePressure.scale_int(5, 10, p))
	_expect(shots == [5, 7, 8, 9, 10], "Interceptor shot counts follow the table: %s" % [shots])


func _check_registry() -> void:
	var drone := Node.new()
	var bomb := Node.new()
	bomb.add_to_group(&"bomb")
	_expect(registry.get_barrage_pressure(drone) == 0, "Threat 1 without augments is P 0")
	registry.threat_level = 4
	_expect(registry.get_barrage_pressure(drone) == 3, "each Threat above 1 adds one level")
	registry.add_augment(FIRE_BOOST)
	registry.add_augment(FIRE_BOOST)
	_expect(registry.get_barrage_pressure(drone) == 7, "fire volume boost adds two levels per stack")
	registry.add_augment(FAST_FUSE)
	_expect(registry.get_barrage_pressure(drone) == 7, "fast fuse skips enemies outside the bomb group")
	_expect(registry.get_barrage_pressure(bomb) == 11, "fast fuse adds four levels to the bomb group")
	registry.clear_augments()
	registry.threat_level = 1
	drone.free()
	bomb.free()


func _check_patterns() -> void:
	var drone := _build("res://patterns/drone_pattern.gd", {"pressure": 6})
	_expect(is_equal_approx(_last_wait(drone), BarragePressure.scale(4.5, 2.5, 6)), "Drone rest follows the curve")
	_expect(_fire_counts(drone) == [1], "Drone stays a single needle")
	var halt := _build("res://patterns/drone_halt_pattern.gd", {"pressure": 6})
	_expect(is_equal_approx(_last_wait(halt), BarragePressure.scale(4.5, 2.5, 6)), "halt Drone rest follows the curve")
	var no_limits := _build("res://patterns/aimed_burst_pattern.gd", {"pressure": 6, "shots": 2, "rest": 4.5})
	_expect(is_equal_approx(_last_wait(no_limits), 4.5) and _fire_counts(no_limits).size() == 2,
		"aimed burst ignores pressure without named limits")
	var evolved := _build("res://patterns/aimed_burst_pattern.gd",
		{"pressure": 6, "ways": 1, "spread": 0.0, "shots": 3, "shots_limit": 6, "gap": 0.12, "rest": 4.5})
	_expect(_fire_counts(evolved).size() == 5 and is_equal_approx(_last_wait(evolved), 4.5),
		"evolved Drone adds shots and keeps its rest")
	var caster := _build("res://patterns/caster_evolved_pattern.gd", {"pressure": 6})
	_expect(_fire_counts(caster) == [32, 32, 32, 32, 32], "evolved Caster fires two 16-bullet rings per beat at P 6")


func _check_components() -> void:
	var sniper := await _spawn("res://enemies/sniper_enemy.tscn", 6)
	var attack := sniper.get_node("SniperAttackComponent")
	_expect(is_equal_approx(attack.cooldown_duration, BarragePressure.scale(2.5, 1.0, 6)), "Sniper cooldown follows the curve")
	_expect(is_equal_approx(attack.aim_duration, 2.5) and is_equal_approx(attack.lock_on_duration, 0.75),
		"Sniper aim and lock-on warnings ignore pressure")
	var striker := await _spawn("res://enemies/evolved/striker_evolved.tscn", 6)
	var wake := striker.get_node("WakeShotComponent") as WakeShotComponent
	_expect(is_equal_approx(wake.interval, BarragePressure.scale(0.45, 0.25, 6)), "Striker wake interval follows the curve")
	var bomb := await _spawn("res://enemies/evolved/bomb_evolved.tscn", 6)
	var fuse := bomb.get_node("BombProximityFuseComponent")
	_expect(is_equal_approx(fuse.arm_duration, BarragePressure.scale(3.0, 2.0, 6)), "Bomb fuse follows the curve")
	_expect(fuse.detonation_ring_count == 16, "evolved Bomb ring grows to 16 at P 6")
	for enemy in [sniper, striker, bomb]:
		enemy.queue_free()
	await process_frame


func _spawn(path: String, pressure: int) -> Enemy:
	var enemy := (load(path) as PackedScene).instantiate() as Enemy
	enemy.augment_registry = registry
	enemy.position = Vector2(200, 100)
	registry.threat_level = pressure + 1
	world.add_child(enemy)
	registry.threat_level = 1
	await process_frame
	return enemy


func _build(path: String, params: Dictionary) -> BarrageSequence:
	var sequence := (load(path) as Script).new() as BarrageSequence
	sequence.build(params)
	_expect(sequence.validation_error().is_empty(), "%s builds a valid pattern" % path)
	return sequence


func _last_wait(sequence: BarrageSequence) -> float:
	for index in range(sequence.steps.size() - 1, -1, -1):
		if sequence.steps[index].action == BarrageStep.Action.WAIT:
			return sequence.steps[index].value
	return -1.0


func _fire_counts(sequence: BarrageSequence) -> Array:
	var counts := []
	for step in sequence.steps:
		if step.action != BarrageStep.Action.FIRE:
			continue
		var total := 0
		for volley in step.get_volleys():
			total += 1 if volley.layout == BarrageVolley.Layout.SINGLE else volley.count
		counts.append(total)
	return counts


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
