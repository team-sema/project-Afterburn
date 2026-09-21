extends SceneTree

var failures: Array[String] = []
var world: Node2D
var target: Node2D

func _initialize() -> void:
	run.call_deferred()

func expect(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func make_counter(trigger: CounterShotComponent.Trigger) -> CounterShotComponent:
	var enemy := preload("res://enemies/normal_enemy.tscn").instantiate() as Enemy
	var registry := EnemyAugmentRegistry.new()
	world.add_child(registry)
	enemy.augment_registry = registry
	world.add_child(enemy)
	enemy.global_position = Vector2(100, 100)
	enemy.get_node("EnemyShootComponent").set_process(false)
	enemy.get_node("EnemyShootComponent").fire_timer.stop()
	enemy.movement_controller.stop()
	enemy.get_node("TargetingComponent").change_target(target)
	var counter := preload("res://components/augment_behaviors/counter_shot_component.tscn").instantiate() as CounterShotComponent
	counter.trigger = trigger
	enemy.add_child(counter)
	return counter

func clear_bullets() -> void:
	for bullet in get_nodes_in_group("enemy_projectiles"): bullet.free()

func run() -> void:
	world = Node2D.new()
	world.position = Vector2(19, 23)
	world.rotation = 0.3
	world.add_to_group("gameplay_world")
	root.add_child(world)
	target = Node2D.new()
	target.add_to_group("player")
	world.add_child(target)
	target.global_position = Vector2(200, 200)
	var counter := make_counter(CounterShotComponent.Trigger.ON_HIT)
	counter.shot_count = 3
	counter.spread_degrees = 20
	var origin := counter.enemy.global_position
	var aimed := origin.direction_to(target.global_position)
	var hit := HitboxComponent.new()
	counter.enemy.get_node("HurtboxComponent").hurt.emit(hit)
	counter.enemy.get_node("HurtboxComponent").hurt.emit(hit)
	hit.free()
	target.global_position = Vector2(40, 200)
	counter.projectile_speed = 900
	await process_frame
	var bullets := get_nodes_in_group("enemy_projectiles")
	expect(bullets.size() == 3, "hit fires fan once during cooldown")
	for index in bullets.size():
		var bullet := bullets[index] as FoundationBullet
		expect(bullet != null, "new body")
		if bullet == null: continue
		bullet.set_physics_process(false)
		expect(bullet._origin.is_equal_approx(origin), "world origin snapshot")
		expect(bullet._direction.is_equal_approx(aimed.rotated(deg_to_rad(-10 + 10 * index))), "aim and spread snapshot")
		expect(bullet._speed == 200, "speed captured before deferral")
		expect(bullet.appearance.make_shape() is CircleShape2D and bullet.appearance.collision_radius == 4, "round hitbox retained")
		expect(bullet.trail_effect != null and bullet.lifetime == 8, "shared trail and bounded lifetime")
		var offset := bullet.behavior_state.position_at(0.25)
		expect(offset.is_equal_approx(bullet._direction * 50 + bullet._direction.orthogonal() * 4), "quarter-period displacement follows firing axis")
	clear_bullets()
	counter.cooldown_timer.stop()
	counter._try_fire()
	await process_frame
	expect(get_nodes_in_group("enemy_projectiles").size() == 3, "cooldown expiry permits another fan")
	clear_bullets()
	counter.cooldown_timer.stop()
	target.global_position = counter.enemy.global_position
	counter._try_fire()
	await process_frame
	expect(get_nodes_in_group("enemy_projectiles").is_empty() and counter.cooldown_timer.is_stopped(), "overlapping target skips fire and cooldown")
	target.remove_from_group("player")
	counter.targeting_component.change_target(null)
	counter._try_fire()
	await process_frame
	expect(get_nodes_in_group("enemy_projectiles").is_empty(), "missing target skips fire")
	target.add_to_group("player")
	target.global_position = Vector2(200, 200)
	counter.enemy.free()
	var death := make_counter(CounterShotComponent.Trigger.ON_DEATH)
	death.enemy.stats_component.health = 0
	death.enemy.free()
	await process_frame
	expect(get_nodes_in_group("enemy_projectiles").size() == 1, "death callback survives immediate emitter deletion")
	clear_bullets()
	var cancelled := make_counter(CounterShotComponent.Trigger.ON_HIT)
	cancelled._try_fire()
	world.free()
	await process_frame
	expect(get_nodes_in_group("enemy_projectiles").is_empty(), "removed world cancels deferred shot")
	for failure in failures: push_error(failure)
	print("counter shot barrage smoke test: ", "PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
