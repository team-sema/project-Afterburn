extends SceneTree

var failures: PackedStringArray = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_all_enemy_scenes_have_modifier()
	_test_modifier_decay()
	await _test_standard_enemy_motion()
	await _test_sequence_enemy_motion()
	await _test_drone_formation_motion()
	await _test_weapon_impulses()
	await _test_striker_gravity_convergence()

	if failures.is_empty():
		print("enemy_move_modifier_smoke_test: PASS")
		quit()
		return
	for failure in failures:
		push_error("enemy_move_modifier_smoke_test: %s" % failure)
	quit(1)


func _test_all_enemy_scenes_have_modifier() -> void:
	var paths := [
		"res://enemies/enemy.tscn",
		"res://enemies/normal_enemy.tscn",
		"res://enemies/moving_enemy.tscn",
		"res://enemies/kamikaze_enemy.tscn",
		"res://enemies/bomb_enemy.tscn",
		"res://enemies/shooting_enemy/shooting_enemy.tscn",
	]
	for path in paths:
		var scene := load(path) as PackedScene
		var enemy := scene.instantiate() as Enemy
		_expect(
			enemy.get_node_or_null("MoveModifierComponent") is MoveModifierComponent,
			"%s inherits MoveModifierComponent" % path,
		)
		enemy.free()


func _test_modifier_decay() -> void:
	var modifier := MoveModifierComponent.new()
	modifier.apply_impulse(Vector2(140.0, 0.0))
	var first_motion := modifier.advance(0.1)
	_expect(first_motion.x > 5.0, "impulse creates additive motion")
	_expect(modifier.external_velocity.x < 140.0, "external velocity decays")
	for _index in 40:
		modifier.advance(0.1)
	_expect(modifier.get_offset().length() < 0.1, "external offset returns near zero")
	modifier.free()


func _test_standard_enemy_motion() -> void:
	var enemy := _make_enemy("res://enemies/enemy.tscn")
	var move := enemy.get_node("MoveComponent") as MoveComponent
	var modifier := enemy.get_node("MoveModifierComponent") as MoveModifierComponent
	move.velocity = Vector2(10.0, 0.0)
	var start := enemy.global_position
	modifier.apply_impulse(Vector2(0.0, 100.0))
	await create_timer(0.15).timeout
	_expect(move.velocity == Vector2(10.0, 0.0), "impulse does not overwrite AI velocity")
	_expect(enemy.global_position.x > start.x, "standard AI movement continues during impulse")
	_expect(enemy.global_position.y > start.y + 3.0, "standard enemy receives additive impulse")
	enemy.queue_free()
	await process_frame


func _test_sequence_enemy_motion() -> void:
	var enemy := _make_enemy("res://enemies/bomb_enemy.tscn")
	var move := enemy.get_node("MoveComponent") as MoveComponent
	var modifier := enemy.get_node("MoveModifierComponent") as MoveModifierComponent
	var start := enemy.global_position
	modifier.apply_impulse(Vector2(100.0, 0.0))
	await create_timer(0.15).timeout
	_expect(move.velocity == Vector2(0.0, 16.0), "modifier does not overwrite sequence velocity")
	_expect(enemy.global_position.y > start.y + 1.0, "sequence movement continues during impulse")
	_expect(enemy.global_position.x > start.x + 3.0, "sequence enemy receives additive impulse")
	enemy.queue_free()
	await process_frame


func _test_drone_formation_motion() -> void:
	var step := LinearMovementStep.new()
	step.speed = 0.0
	var sequence := MovementSequence.new()
	sequence.steps.append(step)
	var controller := (
		load("res://formations/formation_controller.tscn") as PackedScene
	).instantiate() as FormationController
	controller.formation_layout_scene = load(
		"res://formations/layouts/horizontal_formation.tscn"
	) as PackedScene
	controller.formation_movement_sequence = sequence
	controller.set_pending_member_count(1)
	root.add_child(controller)
	controller.global_position = Vector2(160.0, 20.0)
	var pushed := (
		load("res://enemies/normal_enemy.tscn") as PackedScene
	).instantiate() as Enemy
	var registry := EnemyAugmentRegistry.new()
	root.add_child(registry)
	pushed.augment_registry = registry
	controller.add_member(pushed, 2)
	controller.start_formation()
	await process_frame
	var modifier := pushed.get_node("MoveModifierComponent") as MoveModifierComponent
	modifier.apply_impulse(Vector2(140.0, 0.0))
	await create_timer(0.15).timeout
	var slot := controller.get_layout().get_slot(2)
	var target: Vector2 = controller.global_transform * slot.position
	var displaced_x := pushed.global_position.x - target.x
	_expect(displaced_x > 5.0, "formation enemy applies external offset after position rewrite")
	await create_timer(2.0).timeout
	target = controller.global_transform * slot.position
	_expect(
		pushed.global_position.distance_to(target) < 1.0,
		"formation enemy returns to its formation slot",
	)
	controller.queue_free()
	registry.queue_free()
	await process_frame


func _test_weapon_impulses() -> void:
	var enemy := _make_enemy("res://enemies/enemy.tscn")
	enemy.global_position = Vector2(140.0, 100.0)
	var move := enemy.get_node("MoveComponent") as MoveComponent
	var modifier := enemy.get_node("MoveModifierComponent") as MoveModifierComponent

	var projectile := load("res://projectiles/plasma_bomb_projectile.tscn").instantiate() as PlasmaBombProjectile
	projectile.configure_bomb(1.0, 10.0, 80.0, 0.0, 1)
	projectile.configure_plasma_traits(null, 0, 0.0, 0.0, 0.0, 90.0)
	root.add_child(projectile)
	projectile.global_position = Vector2(100.0, 100.0)
	projectile.call("_apply_gravity_pull")
	_expect(modifier.external_velocity.x < 0.0, "plasma gravity applies an inward impulse")
	_expect(move.velocity == Vector2.ZERO, "plasma gravity leaves AI velocity unchanged")

	modifier.reset()
	var player := Node2D.new()
	player.global_position = Vector2(100.0, 100.0)
	root.add_child(player)
	var barrier := load(
		"res://player_ship/weapons/orbital_barrier_weapon_system.tscn"
	).instantiate() as OrbitalBarrierWeaponSystem
	root.add_child(barrier)
	barrier.setup_weapon(player, null, 0)
	barrier.call("_apply_repulse", enemy, enemy.get_node("HurtboxComponent"), 1)
	_expect(modifier.external_velocity.x > 0.0, "barrier repulse applies an outward impulse")
	_expect(move.velocity == Vector2.ZERO, "barrier repulse leaves AI velocity unchanged")

	projectile.queue_free()
	barrier.queue_free()
	player.queue_free()
	enemy.queue_free()
	await process_frame


func _test_striker_gravity_convergence() -> void:
	var left := _make_enemy("res://enemies/moving_enemy.tscn")
	var right := _make_enemy("res://enemies/moving_enemy.tscn")
	left.global_position = Vector2(60.0, 100.0)
	right.global_position = Vector2(140.0, 100.0)
	var projectile := load("res://projectiles/plasma_bomb_projectile.tscn").instantiate() as PlasmaBombProjectile
	projectile.configure_bomb(1.0, 10.0, 34.0, 0.0, 1)
	projectile.configure_plasma_traits(null, 0, 0.0, 0.0, 0.0, 240.0, 1.6)
	root.add_child(projectile)
	projectile.global_position = Vector2(100.0, 100.0)
	var initial_separation := right.global_position.x - left.global_position.x
	projectile.call("_apply_gravity_pull")
	await create_timer(0.2).timeout
	var pulled_separation := right.global_position.x - left.global_position.x
	_expect(left.global_position.x > 65.0, "gravity visibly pulls the left Striker inward")
	_expect(right.global_position.x < 135.0, "gravity visibly pulls the right Striker inward")
	_expect(
		initial_separation - pulled_separation > 12.0,
		"gravity visibly contracts a Striker group",
	)
	projectile.queue_free()
	left.queue_free()
	right.queue_free()
	await process_frame


func _make_enemy(path: String) -> Enemy:
	var scene := load(path) as PackedScene
	var enemy := scene.instantiate() as Enemy
	enemy.augment_registry = EnemyAugmentRegistry.new()
	root.add_child(enemy)
	return enemy


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
