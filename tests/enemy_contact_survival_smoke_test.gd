extends SceneTree

var failures: PackedStringArray = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var ship := load("res://player_ship/ship.tscn").instantiate() as Node2D
	var ship_hurt := ship.get_node("HurtComponent") as HurtComponent
	_expect(
		is_equal_approx(ship_hurt.base_iframe_duration, 0.6),
		"ship config provides 0.6 seconds of base hit invincibility",
	)
	ship.free()
	var registry := PlayerAugmentRegistry.new()
	registry.facilities = [
		load("res://resources/facilities/definitions/hull.tres") as ShipFacilityDefinition,
	]
	root.add_child(registry)
	await process_frame
	var iframe_augment := load(
		"res://resources/player_augments/facilities/facility_hull_iframe.tres"
	) as PlayerAugment
	_expect(registry.install_augment(iframe_augment) == 0, "iframe augment installs in hull")
	var augmented_hurt := HurtComponent.new()
	augmented_hurt.base_iframe_duration = 0.6
	augmented_hurt.facility_registry = registry
	_expect(
		is_equal_approx(float(augmented_hurt.call("_get_iframe_duration", true)), 1.6),
		"iframe augment adds 1.0 second to the 0.6 second base",
	)
	augmented_hurt.free()

	var world := Node2D.new()
	world.add_to_group("gameplay_world")
	root.add_child(world)

	var player := Node2D.new()
	player.add_to_group("player")
	var visual := Node2D.new()
	visual.name = "Anchor"
	var stats := StatsComponent.new()
	stats.health = 3
	var hurtbox := HurtboxComponent.new()
	var collision := CollisionShape2D.new()
	collision.shape = CircleShape2D.new()
	hurtbox.add_child(collision)
	var hurt := HurtComponent.new()
	hurt.stats_component = stats
	hurt.hurtbox_component = hurtbox
	hurt.base_iframe_duration = 0.6
	player.add_child(visual)
	player.add_child(stats)
	player.add_child(hurtbox)
	player.add_child(hurt)
	world.add_child(player)

	var enemy := _make_enemy(world)
	var enemy_hitbox := enemy.get_node("HitboxComponent") as HitboxComponent
	enemy_hitbox.call("_on_hurtbox_entered", hurtbox)
	await process_frame
	_expect(is_instance_valid(enemy), "enemy survives contact with the player")
	_expect(stats.health == 2, "player takes one contact damage")
	_expect(hurtbox.is_invincible, "player gains base hit invincibility")
	_expect(
		(player.get_node("Anchor") as CanvasItem).modulate.a < 0.5,
		"player becomes translucent while invincible",
	)

	enemy_hitbox.call("_on_hurtbox_entered", hurtbox)
	_expect(stats.health == 2, "contact damage is blocked during invincibility")
	await create_timer(0.65).timeout
	_expect(not hurtbox.is_invincible, "base hit invincibility expires")
	_expect(
		is_equal_approx((player.get_node("Anchor") as CanvasItem).modulate.a, 1.0),
		"player opacity returns after invincibility",
	)

	var barrier := load(
		"res://player_ship/weapons/orbital_barrier_weapon_system.tscn"
	).instantiate() as OrbitalBarrierWeaponSystem
	world.add_child(barrier)
	await process_frame
	var barrier_hurtbox := barrier.get_node(
		"OrbitRoot/Segment1/HurtboxComponent"
	) as HurtboxComponent
	enemy_hitbox.call("_on_hurtbox_entered", barrier_hurtbox)
	await process_frame
	_expect(is_instance_valid(enemy), "enemy survives contact with a barrier absorber")

	var enemy_hurtbox := enemy.get_node("HurtboxComponent") as HurtboxComponent
	var lethal_hitbox := HitboxComponent.new()
	lethal_hitbox.damage = enemy.stats_component.health
	enemy_hurtbox.hurt.emit(lethal_hitbox)
	_expect(world.get_node_or_null("ExplosionEffect") != null, "health death spawns explosion")
	lethal_hitbox.free()
	await process_frame
	_expect(not is_instance_valid(enemy), "health death removes enemy")

	world.queue_free()
	registry.queue_free()
	await process_frame
	if failures.is_empty():
		print("enemy_contact_survival_smoke_test: PASS")
		quit()
		return
	for failure in failures:
		push_error("enemy_contact_survival_smoke_test: %s" % failure)
	quit(1)


func _make_enemy(parent: Node) -> Enemy:
	var scene := load("res://enemies/enemy.tscn") as PackedScene
	var enemy := scene.instantiate() as Enemy
	enemy.augment_registry = EnemyAugmentRegistry.new()
	parent.add_child(enemy)
	return enemy


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
