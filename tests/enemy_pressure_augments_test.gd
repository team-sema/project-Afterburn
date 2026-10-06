extends SceneTree

const PROJECTILE_SPEED := preload("res://resources/enemy_augments/enemy_projectile_speed_boost.tres")
const XP_DROP_CHANCE := preload("res://resources/enemy_augments/enemy_xp_drop_chance_down.tres")
const DEATH_BURST := preload("res://resources/enemy_augments/enemy_death_burst.tres")
const ARMOR_PLATE := preload("res://resources/enemy_augments/enemy_armor_plate.tres")
const ELITE_ESCORT := preload("res://resources/enemy_augments/enemy_elite_escort.tres")
const REROLL_LOCK := preload("res://resources/enemy_augments/enemy_reroll_lock.tres")
const DRONE_SCENE := preload("res://enemies/normal_enemy.tscn")

var failures: PackedStringArray = []
var world: Node2D


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	world = Node2D.new()
	world.add_to_group("gameplay_world")
	root.add_child(world)

	_check_offer_pool()
	await _check_projectile_speed()
	await _check_xp_drop_chance()
	await _check_death_burst()
	await _check_armor_plate()
	_check_elite_escort()
	_check_reroll_lock()

	world.queue_free()
	for _frame in 3:
		await process_frame
	if failures.is_empty():
		print("enemy_pressure_augments_test: PASS")
		quit()
		return
	for failure in failures:
		push_error("enemy_pressure_augments_test: %s" % failure)
	quit(1)


func _check_offer_pool() -> void:
	var pool := AugmentPoolLoader.load_enemy_offer_pool()
	for augment in [PROJECTILE_SPEED, XP_DROP_CHANCE, DEATH_BURST, ARMOR_PLATE, ELITE_ESCORT, REROLL_LOCK]:
		_expect(pool.has(augment), "%s is in the enemy offer pool" % augment.augment_id)
	_expect(PROJECTILE_SPEED.max_stacks == 2 and XP_DROP_CHANCE.max_stacks == 2, "stat cards stack twice")
	_expect(
		DEATH_BURST.max_stacks == 1 and ARMOR_PLATE.max_stacks == 1
		and ELITE_ESCORT.max_stacks == 1 and REROLL_LOCK.max_stacks == 1,
		"behavior, escort and reroll cards are one-time",
	)


func _check_projectile_speed() -> void:
	var registry := _registry([PROJECTILE_SPEED, PROJECTILE_SPEED])
	var baseline := await _spawn_drone(_registry([]))
	var boosted := await _spawn_drone(registry)
	var elite := await _spawn_drone(registry, func(enemy: Enemy) -> void: enemy.is_elite = true)
	var base_speeds := _pattern_speeds(baseline)
	var boosted_speeds := _pattern_speeds(boosted)
	var elite_speeds := _pattern_speeds(elite)
	_expect(not base_speeds.is_empty(), "drone pattern exposes volley speeds")
	var scaled := base_speeds.size() == boosted_speeds.size()
	for index in mini(base_speeds.size(), boosted_speeds.size()):
		scaled = scaled and is_equal_approx(boosted_speeds[index], base_speeds[index] * 1.15 * 1.15)
	_expect(scaled, "two projectile speed stacks scale every drone volley by 1.3225")
	_expect(elite_speeds == base_speeds, "elite patterns keep their authored speeds")
	for enemy in [baseline, boosted, elite]:
		enemy.queue_free()
	await process_frame
	_free_registries()


func _check_xp_drop_chance() -> void:
	var registry := _registry([XP_DROP_CHANCE, XP_DROP_CHANCE])
	var drone := await _spawn_drone(registry)
	var drop := drone.get_node("ExperienceDropComponent") as ExperienceDropComponent
	_expect(is_equal_approx(drop.drop_chance, 0.45 * 0.81), "two stacks lower a 45% drop to 36.45%")
	var guaranteed := await _spawn_drone(registry, func(enemy: Enemy) -> void:
		(enemy.get_node("ExperienceDropComponent") as ExperienceDropComponent).drop_chance = 1.0
	)
	var guaranteed_drop := guaranteed.get_node("ExperienceDropComponent") as ExperienceDropComponent
	_expect(is_equal_approx(guaranteed_drop.drop_chance, 1.0), "guaranteed drops stay guaranteed")
	drone.queue_free()
	guaranteed.queue_free()
	await process_frame
	_free_registries()


func _check_death_burst() -> void:
	var registry := _registry([DEATH_BURST])
	var drone := await _spawn_drone(registry)
	_expect(drone.get_node_or_null("DeathBurstComponent") != null, "death burst attaches to spawned enemies")
	var before := _bullet_count()
	drone.stats_component.health = 0
	await process_frame
	await process_frame
	_expect(_bullet_count() - before == 4, "an ordinary enemy releases four burst shots on death")
	var elite := await _spawn_drone(registry, func(enemy: Enemy) -> void: enemy.is_elite = true)
	before = _bullet_count()
	elite.stats_component.health = 0
	await process_frame
	await process_frame
	_expect(_bullet_count() == before, "elite kills do not burst into the bullet cancel")
	for node in get_nodes_in_group(EnemyBullets.GROUP):
		node.queue_free()
	await process_frame
	_free_registries()


func _check_armor_plate() -> void:
	var drone := await _spawn_drone(_registry([ARMOR_PLATE]))
	var armor := drone.get_node_or_null("ArmorPlateComponent") as ArmorPlateComponent
	_expect(armor != null and armor.visible, "armor plate attaches with a visible outline")
	var hitbox := HitboxComponent.new()
	hitbox.damage = 1
	var health := drone.stats_component.health
	drone.hurtbox_component.hurt.emit(hitbox)
	_expect(drone.stats_component.health == health, "the first hit is ignored")
	_expect(armor != null and not armor.visible, "the outline disappears once the plate breaks")
	drone.hurtbox_component.hurt.emit(hitbox)
	_expect(drone.stats_component.health == health - 1, "the second hit deals damage")
	var elite := await _spawn_drone(_registry([ARMOR_PLATE]), func(enemy: Enemy) -> void: enemy.is_elite = true)
	var boss := await _spawn_drone(_registry([ARMOR_PLATE]), func(enemy: Enemy) -> void: enemy.is_boss = true)
	await process_frame
	for big in [elite, boss]:
		var big_health: int = big.stats_component.health
		_expect(big.get_node_or_null("ArmorPlateComponent") == null, "elites and bosses get no armor plate")
		big.hurtbox_component.hurt.emit(hitbox)
		_expect(big.stats_component.health == big_health - 1, "an elite or boss takes its first hit")
	hitbox.free()
	for enemy in [drone, elite, boss]:
		enemy.queue_free()
	await process_frame
	_free_registries()


func _check_elite_escort() -> void:
	var registry := _registry([ELITE_ESCORT])
	var presets := registry.get_elite_escort_presets()
	_expect(presets.size() == 1 and presets[0].validate(true), "escort card exposes a valid preset")
	_expect(presets.size() == 1 and presets[0].members.size() == 2, "escort preset holds two drones")
	var generator_script := GDScript.new()
	generator_script.source_code = "extends Node\nvar augment_registry\nvar spawned := []\nfunc spawn_special_encounter(preset, _configure = Callable()):\n\tspawned.append(preset)\n\treturn null\n"
	generator_script.reload()
	var generator := Node.new()
	generator.set_script(generator_script)
	generator.set("augment_registry", registry)
	var controller := ThreatEliteController.new()
	controller.enemy_generator = generator
	controller._spawn_elite_escorts()
	var spawned: Array = generator.get("spawned")
	_expect(spawned.size() == 1 and spawned[0] == ELITE_ESCORT.elite_escort_preset, "elite gate spawns the escort")
	controller.free()
	generator.free()
	_free_registries()


func _check_reroll_lock() -> void:
	var registry := _registry([])
	var offer := AugmentOfferController.new()
	offer.enemy_registry = registry
	offer.remaining_reroll_count = 2
	_expect(offer._is_enemy_augment_available(REROLL_LOCK), "reroll lock is offered while rerolls remain")
	registry.add_augment(REROLL_LOCK)
	offer._apply_enemy_reroll_penalty(REROLL_LOCK)
	_expect(offer.remaining_reroll_count == 1, "choosing reroll lock removes one reroll")
	var fresh_registry := _registry([])
	offer.enemy_registry = fresh_registry
	offer.remaining_reroll_count = 0
	_expect(not offer._is_enemy_augment_available(REROLL_LOCK), "reroll lock is withheld with no rerolls left")
	offer.free()
	_free_registries()


var _registries: Array[EnemyAugmentRegistry] = []


func _registry(augments: Array) -> EnemyAugmentRegistry:
	var registry := EnemyAugmentRegistry.new()
	for augment in augments:
		registry.add_augment(augment)
	_registries.append(registry)
	return registry


func _free_registries() -> void:
	for registry in _registries:
		registry.free()
	_registries.clear()


func _spawn_drone(registry: EnemyAugmentRegistry, configure := Callable()) -> Enemy:
	var drone := DRONE_SCENE.instantiate() as Enemy
	drone.augment_registry = registry
	drone.spawn_id = &"enemy_pressure_test"
	if configure.is_valid():
		configure.call(drone)
	world.add_child(drone)
	await process_frame
	return drone


func _pattern_speeds(enemy: Enemy) -> Array[float]:
	var speeds: Array[float] = []
	var shoot := enemy.get_node("EnemyShootComponent") as EnemyShootComponent
	if shoot._pattern == null:
		return speeds
	for step in shoot._pattern.steps:
		if step.action != BarrageStep.Action.FIRE:
			continue
		for volley in step.get_volleys():
			speeds.append(volley.speed)
	return speeds


func _bullet_count() -> int:
	return get_nodes_in_group(EnemyBullets.GROUP).size()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
