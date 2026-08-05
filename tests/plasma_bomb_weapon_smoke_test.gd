extends SceneTree

const PROJECTILE_SCENE := preload("res://projectiles/plasma_bomb_projectile.tscn")
const WEAPON_DEFINITION := preload("res://resources/weapons/definitions/plasma_bomb.tres")

var failures: PackedStringArray = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var world := Node2D.new()
	root.add_child(world)

	_expect(WEAPON_DEFINITION.id == &"plasma_bomb", "plasma bomb definition has the expected id")
	_expect(WEAPON_DEFINITION.weapon_scene != null, "plasma bomb definition declares a weapon scene")
	_expect(WEAPON_DEFINITION.icon != null, "plasma bomb definition declares an icon")

	var damage_taken := {
		"near_a": 0,
		"near_b": 0,
		"margin": 0,
		"far": 0,
	}
	_make_target(world, Vector2(92, 100), damage_taken, "near_a")
	_make_target(world, Vector2(122, 100), damage_taken, "near_b")
	_make_target(world, Vector2(138, 100), damage_taken, "margin")
	_make_target(world, Vector2(150, 100), damage_taken, "far")

	var weapon_system := WEAPON_DEFINITION.weapon_scene.instantiate() as PlasmaBombWeaponSystem
	_expect(weapon_system.damage_radius_margin == 0.0, "damage radius margin defaults to zero")
	weapon_system.base_fire_interval = 2.2
	weapon_system.base_damage = 24
	weapon_system.projectile_speed = 38.0
	weapon_system.fuse_time = 0.12
	weapon_system.blast_radius = 34.0
	weapon_system.damage_radius_margin = 6.0
	var projectile := PROJECTILE_SCENE.instantiate() as PlasmaBombProjectile
	projectile.global_position = Vector2(100, 100)
	weapon_system.call("_configure_projectile", projectile)
	_expect(is_equal_approx(projectile.get_damage_radius(), 40.0), "damage radius includes the configured margin")
	var detonation_result := {"count": -1}
	projectile.detonated.connect(func(hit_count: int) -> void:
		detonation_result["count"] = hit_count
	)
	world.add_child(projectile)

	await physics_frame
	var initial_y := projectile.global_position.y
	projectile.call("_process", 0.1)
	_expect(is_instance_valid(projectile), "plasma bomb remains active before its fuse expires")
	_expect(projectile.global_position.y < initial_y, "plasma bomb travels slowly forward")
	_expect(damage_taken["near_a"] == 0, "plasma bomb deals no damage before detonation")

	await create_timer(0.15).timeout
	await physics_frame
	_expect(detonation_result["count"] == 3, "plasma blast includes the target inside its damage margin")
	_expect(damage_taken["near_a"] == 24, "plasma blast damages the first nearby target")
	_expect(damage_taken["near_b"] == 24, "plasma blast damages the second nearby target")
	_expect(damage_taken["margin"] == 24, "plasma blast damages a target inside the configured margin")
	_expect(damage_taken["far"] == 0, "plasma blast leaves targets outside its radius untouched")
	var explosion_effect := world.get_node_or_null("ExplosionEffect") as Node2D
	_expect(explosion_effect != null, "plasma bomb creates its explosion effect")
	if explosion_effect != null:
		_expect(
			is_equal_approx(float(explosion_effect.call("get_effect_radius")), weapon_system.blast_radius),
			"visual explosion radius remains the configured blast radius",
		)

	var configured_projectile := PROJECTILE_SCENE.instantiate() as PlasmaBombProjectile
	weapon_system.set_global_damage_multiplier(1.5)
	weapon_system.call("_configure_projectile", configured_projectile)
	_expect(configured_projectile.blast_damage == 24, "configure stores trait-adjusted base damage")
	_expect(
		weapon_system.resolve_hit_damage(configured_projectile.blast_damage) == 36,
		"weapon damage multiplier scales blast damage",
	)
	configured_projectile.free()
	weapon_system.free()

	world.queue_free()
	await process_frame
	if failures.is_empty():
		print("plasma bomb weapon smoke test: PASS")
		quit()
		return
	for failure in failures:
		push_error("plasma bomb weapon smoke test: %s" % failure)
	quit(1)


func _make_target(
	parent: Node,
	position: Vector2,
	damage_taken: Dictionary,
	key: String,
) -> HurtboxComponent:
	var hurtbox := HurtboxComponent.new()
	hurtbox.name = "Target_%s" % key
	hurtbox.collision_layer = 1 << 1
	hurtbox.collision_mask = 0
	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 3.0
	collision.shape = shape
	hurtbox.add_child(collision)
	hurtbox.hurt.connect(func(hitbox: HitboxComponent) -> void:
		damage_taken[key] = int(damage_taken[key]) + hitbox.damage
	)
	parent.add_child(hurtbox)
	hurtbox.global_position = position
	return hurtbox


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
